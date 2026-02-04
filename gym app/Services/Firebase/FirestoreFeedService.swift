//
//  FirestoreFeedService.swift
//  gym app
//
//  Handles social feed features: Posts, likes, and comments.
//

import Foundation
import FirebaseFirestore

// MARK: - Feed Service

/// Handles posts, likes, and comments for the social feed
@MainActor
class FirestoreFeedService: ObservableObject {
    static let shared = FirestoreFeedService()

    private let core = FirestoreCore.shared

    /// Firestore 'in' queries are limited to 30 items
    private let firestoreInQueryLimit = 30

    // MARK: - Post Operations

    /// Save a post to the global posts collection
    func savePost(_ post: Post) async throws {
        let ref = core.db.collection("posts").document(post.id.uuidString)
        let data = encodePost(post)
        try await ref.setData(data, merge: true)
    }

    /// Fetch posts from friends for the feed
    /// Batches friend IDs into chunks of 30 to work around Firestore 'in' query limit
    func fetchFeedPosts(friendIds: [String], limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        guard !friendIds.isEmpty else {
            return []
        }

        // Batch friend IDs into chunks of 30 (Firestore 'in' query limit)
        let chunks = friendIds.chunked(into: firestoreInQueryLimit)
        var allPosts: [Post] = []

        for chunk in chunks {
            var query = core.db.collection("posts")
                .whereField("authorId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)

            if let beforeDate = before {
                query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
            }

            let snapshot = try await query.getDocuments()
            let posts = snapshot.documents.compactMap { doc in
                decodePost(from: doc.data())
            }
            allPosts.append(contentsOf: posts)
        }

        // Sort all results by createdAt descending and apply limit
        return allPosts
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Fetch posts by a specific user
    func fetchPostsByUser(userId: String, limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        var query = core.db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let beforeDate = before {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            decodePost(from: doc.data())
        }
    }

    /// Listen to feed posts in real-time
    /// Batches friend IDs into chunks of 30 to work around Firestore 'in' query limit
    func listenToFeedPosts(friendIds: [String], limit: Int = 50, onChange: @escaping ([Post]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        guard !friendIds.isEmpty else {
            onChange([])
            // Return a no-op listener
            return NoOpListenerRegistration()
        }

        // Batch friend IDs into chunks of 30 (Firestore 'in' query limit)
        let chunks = friendIds.chunked(into: firestoreInQueryLimit)

        // Track posts from each chunk
        var postsByChunk: [[Post]] = Array(repeating: [], count: chunks.count)
        var listeners: [ListenerRegistration] = []

        for (index, chunk) in chunks.enumerated() {
            let listener = core.db.collection("posts")
                .whereField("authorId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error = error {
                        Logger.error(error, context: "listenToFeedPosts chunk \(index)")
                        onError?(error)
                        return
                    }

                    let posts = snapshot?.documents.compactMap { doc in
                        self?.decodePost(from: doc.data())
                    } ?? []

                    postsByChunk[index] = posts

                    // Merge all chunks, sort, and apply limit
                    let allPosts = postsByChunk.flatMap { $0 }
                        .sorted { $0.createdAt > $1.createdAt }
                        .prefix(limit)
                        .map { $0 }
                    onChange(allPosts)
                }
            listeners.append(listener)
        }

        return CompositeListenerRegistration(listeners: listeners)
    }

    /// Listen to a single post for live updates (counts, caption, content)
    func listenToPost(postId: UUID, onChange: @escaping (Post?) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        core.db.collection("posts").document(postId.uuidString)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToPost")
                    onError?(error)
                    return
                }

                guard let data = snapshot?.data(), snapshot?.exists == true else {
                    onChange(nil)
                    return
                }

                let post = self?.decodePost(from: data)
                onChange(post)
            }
    }

    /// Update an existing post
    func updatePost(_ post: Post) async throws {
        let ref = core.db.collection("posts").document(post.id.uuidString)
        var data: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]

        // Update content only (avoid overwriting like/comment counts)
        guard let contentDict = encodePostContent(post.content) else {
            throw FirestoreError.encodingFailed
        }
        data["content"] = contentDict

        if let caption = post.caption {
            data["caption"] = caption
        } else {
            data["caption"] = FieldValue.delete()
        }

        try await ref.updateData(data)
    }

    /// Delete a post and associated likes/comments
    func deletePost(_ postId: UUID) async throws {
        try await core.db.collection("posts").document(postId.uuidString).delete()

        let likesSnapshot = try await core.db.collection("posts").document(postId.uuidString).collection("likes").getDocuments()
        let commentsSnapshot = try await core.db.collection("posts").document(postId.uuidString).collection("comments").getDocuments()

        let batch = core.db.batch()
        for doc in likesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        for doc in commentsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Like Operations

    /// Like a post
    func likePost(postId: UUID, userId: String) async throws {
        let ref = core.db.collection("posts").document(postId.uuidString).collection("likes").document(userId)

        // Only increment if not already liked
        let likeDoc = try await ref.getDocument()
        guard !likeDoc.exists else { return }

        let like = PostLike(postId: postId, userId: userId)
        try await ref.setData(encodeLike(like))

        let postRef = core.db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["likeCount": FieldValue.increment(Int64(1))])
    }

    /// Unlike a post
    func unlikePost(postId: UUID, userId: String) async throws {
        let ref = core.db.collection("posts").document(postId.uuidString).collection("likes").document(userId)

        // Only decrement if the like actually exists
        let likeDoc = try await ref.getDocument()
        guard likeDoc.exists else { return }

        try await ref.delete()

        let postRef = core.db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["likeCount": FieldValue.increment(Int64(-1))])
    }

    /// Check if user has liked a post
    func isPostLiked(postId: UUID, userId: String) async throws -> Bool {
        let doc = try await core.db.collection("posts").document(postId.uuidString).collection("likes").document(userId).getDocument()
        return doc.exists
    }

    /// Listen to like status for a post
    func listenToPostLikeStatus(postId: UUID, userId: String, onChange: @escaping (Bool) -> Void) -> ListenerRegistration {
        core.db.collection("posts").document(postId.uuidString).collection("likes").document(userId)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.exists ?? false)
            }
    }

    /// Fetch like status for multiple posts at once
    func fetchLikedPostIds(postIds: [UUID], userId: String) async -> Set<UUID> {
        var likedIds = Set<UUID>()

        // Check each post's like status (batched for efficiency)
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for postId in postIds {
                group.addTask {
                    let isLiked = (try? await self.isPostLiked(postId: postId, userId: userId)) ?? false
                    return (postId, isLiked)
                }
            }

            for await (postId, isLiked) in group {
                if isLiked {
                    likedIds.insert(postId)
                }
            }
        }

        return likedIds
    }

    // MARK: - Comment Operations

    /// Add a comment to a post
    func addComment(_ comment: PostComment) async throws {
        let ref = core.db.collection("posts").document(comment.postId.uuidString).collection("comments").document(comment.id.uuidString)
        try await ref.setData(encodeComment(comment))

        let postRef = core.db.collection("posts").document(comment.postId.uuidString)
        try await postRef.updateData(["commentCount": FieldValue.increment(Int64(1))])
    }

    /// Delete a comment
    func deleteComment(postId: UUID, commentId: UUID) async throws {
        let ref = core.db.collection("posts").document(postId.uuidString).collection("comments").document(commentId.uuidString)
        try await ref.delete()

        let postRef = core.db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["commentCount": FieldValue.increment(Int64(-1))])
    }

    /// Fetch comments for a post
    func fetchComments(postId: UUID, limit: Int = 100) async throws -> [PostComment] {
        let snapshot = try await core.db.collection("posts").document(postId.uuidString)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            decodeComment(from: doc.data(), postId: postId)
        }
    }

    /// Listen to comments for a post
    func listenToComments(postId: UUID, limit: Int = 100, onChange: @escaping ([PostComment]) -> Void) -> ListenerRegistration {
        core.db.collection("posts").document(postId.uuidString)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToComments")
                    return
                }

                let comments = snapshot?.documents.compactMap { doc in
                    self?.decodeComment(from: doc.data(), postId: postId)
                } ?? []
                onChange(comments)
            }
    }

    // MARK: - Post Encoding/Decoding

    private func encodePost(_ post: Post) -> [String: Any] {
        var data: [String: Any] = [
            "id": post.id.uuidString,
            "authorId": post.authorId,
            "likeCount": post.likeCount,
            "commentCount": post.commentCount,
            "createdAt": Timestamp(date: post.createdAt)
        ]

        if let contentDict = encodePostContent(post.content) {
            data["content"] = contentDict
        }

        if let caption = post.caption {
            data["caption"] = caption
        }

        if let updatedAt = post.updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }

        return data
    }

    private func encodePostContent(_ content: PostContent) -> [String: Any]? {
        guard let contentData = try? JSONEncoder().encode(content),
              let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            return nil
        }
        return contentDict
    }

    private func decodePost(from data: [String: Any]) -> Post? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let authorId = data["authorId"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date?
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = nil
        }

        let content: PostContent
        if let contentDict = data["content"] as? [String: Any],
           let contentData = try? JSONSerialization.data(withJSONObject: contentDict),
           let decoded = try? JSONDecoder().decode(PostContent.self, from: contentData) {
            content = decoded
        } else {
            content = .text("")
        }

        let caption = data["caption"] as? String

        // Handle multiple number types from Firestore (Int, Int64, NSNumber)
        let likeCount: Int
        if let count = data["likeCount"] as? Int {
            likeCount = count
        } else if let count = data["likeCount"] as? Int64 {
            likeCount = Int(count)
        } else if let count = data["likeCount"] as? NSNumber {
            likeCount = count.intValue
        } else {
            likeCount = 0
        }

        let commentCount: Int
        if let count = data["commentCount"] as? Int {
            commentCount = count
        } else if let count = data["commentCount"] as? Int64 {
            commentCount = Int(count)
        } else if let count = data["commentCount"] as? NSNumber {
            commentCount = count.intValue
        } else {
            commentCount = 0
        }

        return Post(
            id: id,
            authorId: authorId,
            content: content,
            caption: caption,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: likeCount,
            commentCount: commentCount,
            syncStatus: .synced
        )
    }

    private func encodeLike(_ like: PostLike) -> [String: Any] {
        [
            "id": like.id.uuidString,
            "postId": like.postId.uuidString,
            "userId": like.userId,
            "createdAt": Timestamp(date: like.createdAt)
        ]
    }

    private func encodeComment(_ comment: PostComment) -> [String: Any] {
        var data: [String: Any] = [
            "id": comment.id.uuidString,
            "postId": comment.postId.uuidString,
            "authorId": comment.authorId,
            "text": comment.text,
            "createdAt": Timestamp(date: comment.createdAt)
        ]

        if let updatedAt = comment.updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }

        return data
    }

    private func decodeComment(from data: [String: Any], postId: UUID) -> PostComment? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let authorId = data["authorId"] as? String,
              let text = data["text"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date?
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = nil
        }

        return PostComment(
            id: id,
            postId: postId,
            authorId: authorId,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
    }
}

// MARK: - No-Op Listener Registration

/// A listener registration that does nothing (used when no actual listener is needed)
private class NoOpListenerRegistration: NSObject, ListenerRegistration {
    func remove() {
        // No-op
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
