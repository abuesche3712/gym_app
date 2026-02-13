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
    @Published var comments: [CommentWithAuthor] = []  // Top-level comments only
    @Published var replies: [UUID: [CommentWithAuthor]] = [:]  // parentCommentId -> replies
    @Published var isLoading = false
    @Published var isSendingComment = false
    @Published var error: Error?

    private let postRepo: PostRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var commentsListener: ListenerRegistration?
    private var likeListener: ListenerRegistration?
    private var postListener: ListenerRegistration?
    private let profileCache = ProfileCacheService.shared
    private let activityService = FirestoreActivityService.shared

    var currentUserId: String? { authService.currentUser?.uid }

    init(post: PostWithAuthor, postRepo: PostRepository = PostRepository()) {
        self.post = post
        self.postRepo = postRepo
    }

    deinit {
        commentsListener?.remove()
        likeListener?.remove()
        postListener?.remove()
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

        // Listen for post updates (counts, caption, content)
        postListener?.remove()
        postListener = firestoreService.listenToPost(postId: post.post.id, onChange: { [weak self] updatedPost in
            guard let self, let updatedPost else { return }
            Task { @MainActor in
                self.post = PostWithAuthor(
                    post: updatedPost,
                    author: self.post.author,
                    isLikedByCurrentUser: self.post.isLikedByCurrentUser
                )
            }
        })

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
        // Prefetch all unique author profiles in parallel
        let uniqueAuthorIds = Array(Set(comments.map { $0.authorId }))
        await profileCache.prefetch(userIds: uniqueAuthorIds)

        var allComments: [CommentWithAuthor] = []
        for comment in comments {
            let profile = await profileCache.profile(for: comment.authorId)
            allComments.append(CommentWithAuthor(comment: comment, author: profile))
        }

        // Separate top-level comments from replies
        var topLevel: [CommentWithAuthor] = []
        var replyMap: [UUID: [CommentWithAuthor]] = [:]

        for comment in allComments {
            if let parentId = comment.comment.parentCommentId {
                replyMap[parentId, default: []].append(comment)
            } else {
                topLevel.append(comment)
            }
        }

        // Sort replies by createdAt ascending
        for key in replyMap.keys {
            replyMap[key]?.sort { $0.comment.createdAt < $1.comment.createdAt }
        }

        self.comments = topLevel
        self.replies = replyMap
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

            // Create activity for post author
            let activity = Activity(
                recipientId: post.post.authorId,
                actorId: userId,
                type: .comment,
                postId: post.post.id,
                preview: String(text.prefix(50))
            )
            try? await activityService.createActivity(activity)

            HapticManager.shared.success()
        } catch {
            self.error = error
        }
    }

    func sendReply(to parentComment: CommentWithAuthor, text: String) async {
        guard let userId = currentUserId, !text.isEmpty else { return }

        isSendingComment = true
        defer { isSendingComment = false }

        let reply = PostComment(
            postId: post.post.id,
            authorId: userId,
            text: text,
            parentCommentId: parentComment.comment.id
        )

        do {
            try await firestoreService.addComment(reply)
            postRepo.saveComment(reply)

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

            // Create activity for comment author (the person being replied to)
            let activity = Activity(
                recipientId: parentComment.comment.authorId,
                actorId: userId,
                type: .comment,
                postId: post.post.id,
                preview: String(text.prefix(50))
            )
            try? await activityService.createActivity(activity)

            HapticManager.shared.success()
        } catch {
            self.error = error
        }
    }

    func updateComment(_ comment: CommentWithAuthor, newText: String) async {
        guard comment.comment.authorId == currentUserId else { return }

        // Optimistic update
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            var updatedComment = comment.comment
            updatedComment.text = newText
            updatedComment.updatedAt = Date()
            comments[index] = CommentWithAuthor(comment: updatedComment, author: comment.author)
        }

        do {
            var updatedComment = comment.comment
            updatedComment.text = newText
            try await firestoreService.updateComment(updatedComment)
            HapticManager.shared.tap()
        } catch {
            // Reload on failure
            loadComments()
            self.error = error
        }
    }

    func deleteComment(_ comment: CommentWithAuthor) async {
        guard let userId = currentUserId,
              comment.comment.authorId == userId || post.post.authorId == userId else { return }

        // Optimistic removal
        comments.removeAll { $0.id == comment.id }
        for key in replies.keys {
            replies[key]?.removeAll { $0.id == comment.id }
        }

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

    func toggleLike(reactionType: ReactionType = .heart) async {
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
                try await firestoreService.likePost(postId: post.post.id, userId: userId, reactionType: reactionType)
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

    func react(with reactionType: ReactionType) async {
        guard let userId = currentUserId else { return }

        // Optimistic update
        var updatedPost = post.post
        if !post.isLikedByCurrentUser {
            updatedPost.likeCount += 1
        }
        post = PostWithAuthor(
            post: updatedPost,
            author: post.author,
            isLikedByCurrentUser: true
        )

        do {
            try await firestoreService.likePost(postId: post.post.id, userId: userId, reactionType: reactionType)
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
}
