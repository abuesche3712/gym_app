//
//  FeedViewModel.swift
//  gym app
//
//  ViewModel for the social feed
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Feed Filter

enum FeedFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case workouts = "Workouts"
    case prs = "PRs"
    case programs = "Programs"
    case text = "Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.stack"
        case .workouts: return "figure.run"
        case .prs: return "trophy.fill"
        case .programs: return "doc.text.fill"
        case .text: return "text.quote"
        }
    }

    func matches(_ content: PostContent) -> Bool {
        switch self {
        case .all:
            return true
        case .workouts:
            switch content {
            case .session, .exercise, .completedModule, .highlights:
                return true
            default:
                return false
            }
        case .prs:
            if case .set = content {
                return true
            }
            return false
        case .programs:
            switch content {
            case .program, .workout, .module:
                return true
            default:
                return false
            }
        case .text:
            if case .text = content {
                return true
            }
            return false
        }
    }
}

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
    @Published var activeFilter: FeedFilter = .all
    @Published var feedMode: FeedMode = .feed

    private let postRepo: PostRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var feedListener: ListenerRegistration?
    private var profileCache: [String: UserProfile] = [:]
    private var likedPostIds: Set<UUID> = []
    private var newPostObserver: Any?
    private var commentCountObserver: Any?
    private var friendshipCancellable: AnyCancellable?
    private let activityService = FirestoreActivityService.shared

    var currentUserId: String? { authService.currentUser?.uid }

    var filteredPosts: [PostWithAuthor] {
        guard activeFilter != .all else { return posts }
        return posts.filter { activeFilter.matches($0.post.content) }
    }

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
        // Get author profile (current user)
        let profile: UserProfile
        if let cached = profileCache[post.authorId] {
            profile = cached
        } else if let fetched = try? await firestoreService.fetchUserProfile(firebaseUserId: post.authorId) {
            profileCache[post.authorId] = fetched
            profile = fetched
        } else {
            profile = UserProfile(id: UUID(), username: "me", displayName: "Me")
        }

        let newPost = PostWithAuthor(post: post, author: profile, isLikedByCurrentUser: false)

        // Add to top of feed if not already there
        if !posts.contains(where: { $0.post.id == post.id }) {
            posts.insert(newPost, at: 0)
        }
    }

    // MARK: - Loading Feed

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
            posts.append(contentsOf: postsWithAuthors)
        } catch {
            self.error = error
        }
    }

    // MARK: - Processing Posts

    private func processFeedPosts(_ posts: [Post], userId: String) async {
        // Load liked status from Firestore (primary source of truth)
        let postIds = posts.map { $0.id }
        likedPostIds = await firestoreService.fetchLikedPostIds(postIds: postIds, userId: userId)

        // Also sync to local cache for offline access
        for postId in likedPostIds {
            let like = PostLike(postId: postId, userId: userId)
            postRepo.saveLike(like)
        }

        // Load authors and create PostWithAuthor objects
        let postsWithAuthors = await loadAuthorsForPosts(posts, userId: userId)
        self.posts = postsWithAuthors
    }

    private func loadAuthorsForPosts(_ posts: [Post], userId: String) async -> [PostWithAuthor] {
        var result: [PostWithAuthor] = []

        for post in posts {
            let profile: UserProfile

            // Check cache first
            if let cached = profileCache[post.authorId] {
                profile = cached
            } else if let fetched = try? await firestoreService.fetchUserProfile(firebaseUserId: post.authorId) {
                profileCache[post.authorId] = fetched
                profile = fetched
            } else {
                // Fallback for unknown users
                profile = UserProfile(
                    id: UUID(),
                    username: "unknown",
                    displayName: "Unknown User"
                )
            }

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
            posts[index].isLikedByCurrentUser = wasLiked
            var revertedPost = posts[index].post
            revertedPost.likeCount += wasLiked ? 1 : -1
            posts[index] = PostWithAuthor(
                post: revertedPost,
                author: posts[index].author,
                isLikedByCurrentUser: wasLiked
            )
            self.error = error
        }
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
