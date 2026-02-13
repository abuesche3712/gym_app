//
//  FeedViewModel.swift
//  gym app
//
//  ViewModel for the social feed
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Feed Mode

enum FeedMode: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case discover = "Discover"

    var id: String { rawValue }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [PostWithAuthor] = []
    @Published var trendingPosts: [PostWithAuthor] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isLoadingTrending = false
    @Published var error: Error?
    @Published var feedMode: FeedMode = .feed

    private let postRepo: PostRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var feedListener: ListenerRegistration?
    private let profileCache = ProfileCacheService.shared
    private var likedPostIds: Set<UUID> = []
    private var pendingLikePostIds: Set<UUID> = []
    private var newPostObserver: Any?
    private var commentCountObserver: Any?
    private var friendshipCancellable: AnyCancellable?
    private let activityService = FirestoreActivityService.shared

    var currentUserId: String? { authService.currentUser?.uid }

    init(
        postRepo: PostRepository = PostRepository(),
        friendshipRepo: FriendshipRepository = DataRepository.shared.friendshipRepo
    ) {
        self.postRepo = postRepo
        self.friendshipRepo = friendshipRepo
        setupNotificationObserver()
        setupFriendshipObserver()
    }

    deinit {
        feedListener?.remove()
        friendshipCancellable?.cancel()
        if let observer = newPostObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = commentCountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        newPostObserver = NotificationCenter.default.addObserver(
            forName: .didCreatePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let post = notification.object as? Post,
                  let userId = self.currentUserId else { return }

            Task { @MainActor in
                // Optimistically add the new post to the top of the feed
                await self.addNewPostToFeed(post, userId: userId)
            }
        }

        commentCountObserver = NotificationCenter.default.addObserver(
            forName: .didUpdatePostCommentCount,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let info = notification.object as? [String: Any],
                  let postId = info["postId"] as? UUID,
                  let commentCount = info["commentCount"] as? Int else { return }

            Task { @MainActor in
                self.updatePostCommentCount(postId: postId, count: commentCount)
            }
        }
    }

    private func updatePostCommentCount(postId: UUID, count: Int) {
        guard let index = posts.firstIndex(where: { $0.post.id == postId }) else { return }

        var updatedPost = posts[index].post
        updatedPost.commentCount = count
        posts[index] = PostWithAuthor(
            post: updatedPost,
            author: posts[index].author,
            isLikedByCurrentUser: posts[index].isLikedByCurrentUser
        )
    }

    private func setupFriendshipObserver() {
        friendshipCancellable = friendshipRepo.$friendships
            .dropFirst() // Skip initial value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // Friendships changed — restart feed listener with fresh friend IDs
                self?.restartFeedListener()
            }
    }

    private func restartFeedListener() {
        guard let userId = currentUserId else { return }

        // Remove old listener
        feedListener?.remove()

        // Get fresh friend IDs
        let friends = friendshipRepo.getAcceptedFriends(for: userId)
        var friendIds = friends.compactMap { $0.otherUserId(from: userId) }
        friendIds.append(userId) // Include own posts

        guard !friendIds.isEmpty else {
            posts = []
            return
        }

        // Start new listener with current friends
        feedListener = firestoreService.listenToFeedPosts(
            friendIds: friendIds,
            limit: 50,
            onChange: { [weak self] posts in
                Task { @MainActor in
                    await self?.processFeedPosts(posts, userId: userId)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.error = error
                }
            }
        )
    }

    private func addNewPostToFeed(_ post: Post, userId: String) async {
        let profile = await profileCache.profile(for: post.authorId)
        let newPost = PostWithAuthor(post: post, author: profile, isLikedByCurrentUser: false)

        // Add to top of feed if not already there
        if !posts.contains(where: { $0.post.id == post.id }) {
            posts.insert(newPost, at: 0)
        }
    }

    // MARK: - Loading Feed

    func stopListening(clearData: Bool = false) {
        feedListener?.remove()
        feedListener = nil
        if clearData {
            posts = []
            trendingPosts = []
            isLoading = false
            isLoadingMore = false
            isLoadingTrending = false
        }
    }

    func loadFeed() {
        guard currentUserId != nil else { return }

        isLoading = true
        restartFeedListener()
        isLoading = false
    }

    func refreshFeed() async {
        guard let userId = currentUserId else { return }

        let friends = friendshipRepo.getAcceptedFriends(for: userId)
        var friendIds = friends.compactMap { $0.otherUserId(from: userId) }
        friendIds.append(userId)

        do {
            let posts = try await firestoreService.fetchFeedPosts(friendIds: friendIds, limit: 50)
            await processFeedPosts(posts, userId: userId)
        } catch {
            self.error = error
        }
    }

    func loadMorePosts() async {
        guard let userId = currentUserId,
              let oldestPost = posts.last,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let friends = friendshipRepo.getAcceptedFriends(for: userId)
        var friendIds = friends.compactMap { $0.otherUserId(from: userId) }
        friendIds.append(userId)

        do {
            let morePosts = try await firestoreService.fetchFeedPosts(
                friendIds: friendIds,
                limit: 20,
                before: oldestPost.post.createdAt
            )

            let postsWithAuthors = await loadAuthorsForPosts(morePosts, userId: userId)
            var existingIds = Set(posts.map { $0.post.id })
            let uniquePosts = postsWithAuthors.filter { existingIds.insert($0.post.id).inserted }
            posts.append(contentsOf: uniquePosts)
        } catch {
            self.error = error
        }
    }

    // MARK: - Processing Posts

    private func processFeedPosts(_ posts: [Post], userId: String) async {
        // Snapshot current optimistic state for posts with pending like operations
        var pendingState: [UUID: (isLiked: Bool, likeCount: Int)] = [:]
        for postId in pendingLikePostIds {
            if let existing = self.posts.first(where: { $0.post.id == postId }) {
                pendingState[postId] = (existing.isLikedByCurrentUser, existing.post.likeCount)
            }
        }

        // Load liked status from Firestore (primary source of truth)
        let postIds = posts.map { $0.id }
        likedPostIds = await firestoreService.fetchLikedPostIds(postIds: postIds, userId: userId)

        // Also sync to local cache for offline access
        for postId in likedPostIds {
            let like = PostLike(postId: postId, userId: userId)
            postRepo.saveLike(like)
        }

        // Load authors and create PostWithAuthor objects
        var postsWithAuthors = await loadAuthorsForPosts(posts, userId: userId)

        // Restore optimistic state for posts with pending like operations
        for (index, postWithAuthor) in postsWithAuthors.enumerated() {
            if let state = pendingState[postWithAuthor.post.id] {
                var post = postWithAuthor.post
                post.likeCount = state.likeCount
                postsWithAuthors[index] = PostWithAuthor(
                    post: post,
                    author: postWithAuthor.author,
                    isLikedByCurrentUser: state.isLiked
                )
            }
        }

        self.posts = postsWithAuthors
    }

    private func loadAuthorsForPosts(_ posts: [Post], userId: String) async -> [PostWithAuthor] {
        // Prefetch all unique author profiles in parallel
        let uniqueAuthorIds = Array(Set(posts.map { $0.authorId }))
        await profileCache.prefetch(userIds: uniqueAuthorIds)

        var result: [PostWithAuthor] = []
        for post in posts {
            let profile = await profileCache.profile(for: post.authorId)
            let isLiked = likedPostIds.contains(post.id)
            result.append(PostWithAuthor(post: post, author: profile, isLikedByCurrentUser: isLiked))
        }

        return result
    }

    // MARK: - Like Actions

    func toggleLike(for post: PostWithAuthor, reactionType: ReactionType = .heart) async {
        guard let userId = currentUserId else { return }

        // Find index and get current state
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let wasLiked = posts[index].isLikedByCurrentUser

        // Optimistic update
        posts[index].isLikedByCurrentUser = !wasLiked
        var updatedPost = posts[index].post
        updatedPost.likeCount += wasLiked ? -1 : 1
        posts[index] = PostWithAuthor(
            post: updatedPost,
            author: posts[index].author,
            isLikedByCurrentUser: !wasLiked
        )

        pendingLikePostIds.insert(post.post.id)
        do {
            if wasLiked {
                try await firestoreService.unlikePost(postId: post.post.id, userId: userId)
                likedPostIds.remove(post.post.id)
                postRepo.deleteLike(postId: post.post.id, userId: userId)
            } else {
                try await firestoreService.likePost(postId: post.post.id, userId: userId, reactionType: reactionType)
                likedPostIds.insert(post.post.id)
                let like = PostLike(postId: post.post.id, userId: userId, reactionType: reactionType)
                postRepo.saveLike(like)

                // Create activity for post author
                let activity = Activity(
                    recipientId: post.post.authorId,
                    actorId: userId,
                    type: .like,
                    postId: post.post.id
                )
                try? await activityService.createActivity(activity)
            }
            HapticManager.shared.tap()
        } catch {
            // Revert on failure
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                var revertedPost = posts[index].post
                revertedPost.likeCount += wasLiked ? 1 : -1
                posts[index] = PostWithAuthor(
                    post: revertedPost,
                    author: posts[index].author,
                    isLikedByCurrentUser: wasLiked
                )
            }
            self.error = error
        }
        pendingLikePostIds.remove(post.post.id)
    }

    func react(to post: PostWithAuthor, with reactionType: ReactionType) async {
        guard let userId = currentUserId else { return }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        // Optimistic update
        var updatedPost = posts[index].post
        if !posts[index].isLikedByCurrentUser {
            updatedPost.likeCount += 1
        }
        posts[index] = PostWithAuthor(
            post: updatedPost,
            author: posts[index].author,
            isLikedByCurrentUser: true
        )

        pendingLikePostIds.insert(post.post.id)
        do {
            try await firestoreService.likePost(postId: post.post.id, userId: userId, reactionType: reactionType)
            likedPostIds.insert(post.post.id)
            let like = PostLike(postId: post.post.id, userId: userId, reactionType: reactionType)
            postRepo.saveLike(like)

            // Create activity for post author
            let activity = Activity(
                recipientId: post.post.authorId,
                actorId: userId,
                type: .like,
                postId: post.post.id
            )
            try? await activityService.createActivity(activity)
            HapticManager.shared.tap()
        } catch {
            self.error = error
        }
        pendingLikePostIds.remove(post.post.id)
    }

    // MARK: - Delete Post

    func deletePost(_ post: PostWithAuthor) async {
        guard post.post.authorId == currentUserId else { return }

        // Optimistic removal
        posts.removeAll { $0.id == post.id }

        do {
            try await firestoreService.deletePost(post.post.id)
            postRepo.delete(post.post)
            HapticManager.shared.success()
        } catch {
            // Reload feed on failure
            loadFeed()
            self.error = error
        }
    }

    // MARK: - Update Post

    func updatePost(_ updatedPost: Post) async {
        guard updatedPost.authorId == currentUserId else { return }

        // Find the post in the feed and update it optimistically
        guard let index = posts.firstIndex(where: { $0.post.id == updatedPost.id }) else { return }
        let originalPost = posts[index]

        // Optimistic update - preserve author and like status
        posts[index] = PostWithAuthor(
            post: updatedPost,
            author: originalPost.author,
            isLikedByCurrentUser: originalPost.isLikedByCurrentUser
        )

        do {
            try await firestoreService.updatePost(updatedPost)
            postRepo.update(updatedPost)
            HapticManager.shared.success()
        } catch {
            // Revert on failure
            posts[index] = originalPost
            self.error = error
        }
    }

    // MARK: - User Posts

    func loadUserPosts(userId: String) async -> [PostWithAuthor] {
        do {
            let posts = try await firestoreService.fetchPostsByUser(userId: userId, limit: 50)
            return await loadAuthorsForPosts(posts, userId: currentUserId ?? "")
        } catch {
            self.error = error
            return []
        }
    }

    // MARK: - Trending Posts

    func loadTrendingPosts() async {
        guard let userId = currentUserId else { return }
        guard !isLoadingTrending else { return }

        isLoadingTrending = true
        defer { isLoadingTrending = false }

        do {
            let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let posts = try await firestoreService.fetchTrendingPosts(since: since, limit: 20)
            trendingPosts = await loadAuthorsForPosts(posts, userId: userId)
        } catch {
            self.error = error
        }
    }
}
