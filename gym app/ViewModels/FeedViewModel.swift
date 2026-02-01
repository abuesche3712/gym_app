//
//  FeedViewModel.swift
//  gym app
//
//  ViewModel for the social feed
//

import Foundation
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [PostWithAuthor] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: Error?

    private let postRepo: PostRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var feedListener: ListenerRegistration?
    private var profileCache: [String: UserProfile] = [:]
    private var likedPostIds: Set<UUID> = []

    var currentUserId: String? { authService.currentUser?.uid }

    init(
        postRepo: PostRepository = PostRepository(),
        friendshipRepo: FriendshipRepository = DataRepository.shared.friendshipRepo
    ) {
        self.postRepo = postRepo
        self.friendshipRepo = friendshipRepo
    }

    deinit {
        feedListener?.remove()
    }

    // MARK: - Loading Feed

    func loadFeed() {
        guard let userId = currentUserId else { return }

        isLoading = true

        // Get friend IDs (including self for own posts)
        let friends = friendshipRepo.getAcceptedFriends(for: userId)
        var friendIds = friends.compactMap { $0.otherUserId(from: userId) }
        friendIds.append(userId)  // Include own posts

        // Set up real-time listener
        feedListener?.remove()
        feedListener = firestoreService.listenToFeedPosts(
            friendIds: friendIds,
            limit: 50,
            onChange: { [weak self] posts in
                Task { @MainActor in
                    await self?.processFeedPosts(posts, userId: userId)
                    self?.isLoading = false
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.error = error
                    self?.isLoading = false
                }
            }
        )
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
        // Load liked status for current user
        likedPostIds = postRepo.getLikedPostIds(userId: userId)

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

    func toggleLike(for post: PostWithAuthor) async {
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
                try await firestoreService.likePost(postId: post.post.id, userId: userId)
                likedPostIds.insert(post.post.id)
                let like = PostLike(postId: post.post.id, userId: userId)
                postRepo.saveLike(like)
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
}
