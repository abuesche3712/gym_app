//
//  PostRepository.swift
//  gym app
//
//  Local cache repository for posts, likes, and comments
//  Note: Firestore is the source of truth; this provides local caching
//

import CoreData
import Foundation

class PostRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Post CRUD Operations

    func save(_ post: Post) {
        let entity = findOrCreateEntity(id: post.id)
        entity.update(from: post)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.save")
        }
    }

    func delete(_ post: Post) {
        guard let entity = findEntity(id: post.id) else { return }

        viewContext.delete(entity)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.delete")
        }
    }

    /// Update an existing post, preserving like/comment counts from the existing entity
    func update(_ post: Post) {
        guard let entity = findEntity(id: post.id) else {
            // If entity doesn't exist, just save it
            save(post)
            return
        }

        // Use server-provided counts (allow decreases for unlikes/deletions)
        var updatedPost = post
        updatedPost.likeCount = post.likeCount
        updatedPost.commentCount = post.commentCount

        entity.update(from: updatedPost)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.update")
        }
    }

    // MARK: - Like Operations

    func saveLike(_ like: PostLike) {
        // Deduplicate by (postId, userId) to avoid double-counting
        if let existing = findLikeEntity(postId: like.postId, userId: like.userId) {
            existing.syncStatus = like.syncStatus
        } else {
            let entity = findOrCreateLikeEntity(id: like.id)
            entity.update(from: like)

            // Increment like count on post
            if let postEntity = findEntity(id: like.postId) {
                postEntity.likeCount += 1
            }
        }

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.saveLike")
        }
    }

    func deleteLike(postId: UUID, userId: String) {
        guard let entity = findLikeEntity(postId: postId, userId: userId) else { return }

        // Decrement like count on post
        if let postEntity = findEntity(id: postId) {
            postEntity.likeCount = max(0, postEntity.likeCount - 1)
        }

        viewContext.delete(entity)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.deleteLike")
        }
    }

    func getLikedPostIds(userId: String) -> Set<UUID> {
        let request = NSFetchRequest<PostLikeEntity>(entityName: "PostLikeEntity")
        request.predicate = NSPredicate(format: "userId == %@", userId)

        do {
            let entities = try viewContext.fetch(request)
            return Set(entities.map { $0.postId })
        } catch {
            Logger.error(error, context: "PostRepository.getLikedPostIds")
            return []
        }
    }

    // MARK: - Comment Operations

    func saveComment(_ comment: PostComment) {
        let entity = findOrCreateCommentEntity(id: comment.id)
        entity.update(from: comment)

        // Increment comment count on post
        if let postEntity = findEntity(id: comment.postId) {
            postEntity.commentCount += 1
        }

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.saveComment")
        }
    }

    func deleteComment(_ comment: PostComment) {
        guard let entity = findCommentEntity(id: comment.id) else { return }

        // Decrement comment count on post
        if let postEntity = findEntity(id: comment.postId) {
            postEntity.commentCount = max(0, postEntity.commentCount - 1)
        }

        viewContext.delete(entity)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.deleteComment")
        }
    }

    // MARK: - Private Helpers

    private func findEntity(id: UUID) -> PostEntity? {
        let request = NSFetchRequest<PostEntity>(entityName: "PostEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateEntity(id: UUID) -> PostEntity {
        if let existing = findEntity(id: id) {
            return existing
        }

        let entity = PostEntity(context: viewContext)
        entity.id = id
        entity.syncStatusRaw = SyncStatus.pendingSync.rawValue
        return entity
    }

    private func findLikeEntity(postId: UUID, userId: String) -> PostLikeEntity? {
        let request = NSFetchRequest<PostLikeEntity>(entityName: "PostLikeEntity")
        request.predicate = NSPredicate(format: "postId == %@ AND userId == %@", postId as CVarArg, userId)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateLikeEntity(id: UUID) -> PostLikeEntity {
        let request = NSFetchRequest<PostLikeEntity>(entityName: "PostLikeEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        if let existing = try? viewContext.fetch(request).first {
            return existing
        }

        let entity = PostLikeEntity(context: viewContext)
        entity.id = id
        entity.syncStatusRaw = SyncStatus.pendingSync.rawValue
        return entity
    }

    private func findCommentEntity(id: UUID) -> PostCommentEntity? {
        let request = NSFetchRequest<PostCommentEntity>(entityName: "PostCommentEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateCommentEntity(id: UUID) -> PostCommentEntity {
        if let existing = findCommentEntity(id: id) {
            return existing
        }

        let entity = PostCommentEntity(context: viewContext)
        entity.id = id
        entity.syncStatusRaw = SyncStatus.pendingSync.rawValue
        return entity
    }
}
