//
//  PostDetailViewModel.swift
//  gym app
//
//  ViewModel for viewing a single post with comments
//

import Foundation
import FirebaseFirestore

@MainActor
class PostDetailViewModel: ObservableObject {
    @Published var post: PostWithAuthor
    @Published var comments: [CommentWithAuthor] = []
    @Published var isLoading = false
    @Published var isSendingComment = false
    @Published var error: Error?

    private let postRepo: PostRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var commentsListener: ListenerRegistration?
    private var likeListener: ListenerRegistration?
    private var profileCache: [String: UserProfile] = [:]

    var currentUserId: String? { authService.currentUser?.uid }

    init(post: PostWithAuthor, postRepo: PostRepository = PostRepository()) {
        self.post = post
        self.postRepo = postRepo
    }

    deinit {
        commentsListener?.remove()
        likeListener?.remove()
    }

    // MARK: - Loading

    func loadComments() {
        isLoading = true

        // Set up real-time listener for comments
        commentsListener?.remove()
        commentsListener = firestoreService.listenToComments(postId: post.post.id, limit: 100) { [weak self] comments in
            Task { @MainActor in
                await self?.processComments(comments)
                self?.isLoading = false
            }
        }

        // Set up like status listener
        if let userId = currentUserId {
            likeListener?.remove()
            likeListener = firestoreService.listenToPostLikeStatus(postId: post.post.id, userId: userId) { [weak self] isLiked in
                Task { @MainActor in
                    self?.post = PostWithAuthor(
                        post: self?.post.post ?? Post(authorId: "", content: .text("")),
                        author: self?.post.author ?? UserProfile(id: UUID(), username: "unknown"),
                        isLikedByCurrentUser: isLiked
                    )
                }
            }
        }
    }

    private func processComments(_ comments: [PostComment]) async {
        var result: [CommentWithAuthor] = []

        for comment in comments {
            let profile: UserProfile

            if let cached = profileCache[comment.authorId] {
                profile = cached
            } else if let fetched = try? await firestoreService.fetchUserProfile(firebaseUserId: comment.authorId) {
                profileCache[comment.authorId] = fetched
                profile = fetched
            } else {
                profile = UserProfile(id: UUID(), username: "unknown", displayName: "Unknown User")
            }

            result.append(CommentWithAuthor(comment: comment, author: profile))
        }

        self.comments = result
    }

    // MARK: - Actions

    func sendComment(text: String) async {
        guard let userId = currentUserId, !text.isEmpty else { return }

        isSendingComment = true
        defer { isSendingComment = false }

        let comment = PostComment(
            postId: post.post.id,
            authorId: userId,
            text: text
        )

        do {
            try await firestoreService.addComment(comment)
            postRepo.saveComment(comment)

            // Update local post comment count
            var updatedPost = post.post
            updatedPost.commentCount += 1
            post = PostWithAuthor(
                post: updatedPost,
                author: post.author,
                isLikedByCurrentUser: post.isLikedByCurrentUser
            )

            // Notify feed to update comment count
            NotificationCenter.default.post(
                name: .didUpdatePostCommentCount,
                object: ["postId": post.post.id, "commentCount": post.post.commentCount]
            )

            HapticManager.shared.success()
        } catch {
            self.error = error
        }
    }

    func deleteComment(_ comment: CommentWithAuthor) async {
        guard comment.comment.authorId == currentUserId else { return }

        // Optimistic removal
        comments.removeAll { $0.id == comment.id }

        do {
            try await firestoreService.deleteComment(postId: post.post.id, commentId: comment.comment.id)
            postRepo.deleteComment(comment.comment)

            // Update local post comment count
            var updatedPost = post.post
            updatedPost.commentCount = max(0, updatedPost.commentCount - 1)
            post = PostWithAuthor(
                post: updatedPost,
                author: post.author,
                isLikedByCurrentUser: post.isLikedByCurrentUser
            )

            // Notify feed to update comment count
            NotificationCenter.default.post(
                name: .didUpdatePostCommentCount,
                object: ["postId": post.post.id, "commentCount": post.post.commentCount]
            )

            HapticManager.shared.impact()
        } catch {
            // Reload on failure
            loadComments()
            self.error = error
        }
    }

    func toggleLike() async {
        guard let userId = currentUserId else { return }

        let wasLiked = post.isLikedByCurrentUser

        // Optimistic update
        var updatedPost = post.post
        updatedPost.likeCount += wasLiked ? -1 : 1
        post = PostWithAuthor(
            post: updatedPost,
            author: post.author,
            isLikedByCurrentUser: !wasLiked
        )

        do {
            if wasLiked {
                try await firestoreService.unlikePost(postId: post.post.id, userId: userId)
                postRepo.deleteLike(postId: post.post.id, userId: userId)
            } else {
                try await firestoreService.likePost(postId: post.post.id, userId: userId)
                let like = PostLike(postId: post.post.id, userId: userId)
                postRepo.saveLike(like)
            }
            HapticManager.shared.tap()
        } catch {
            // Revert on failure
            var revertedPost = post.post
            revertedPost.likeCount += wasLiked ? 1 : -1
            post = PostWithAuthor(
                post: revertedPost,
                author: post.author,
                isLikedByCurrentUser: wasLiked
            )
            self.error = error
        }
    }
}
