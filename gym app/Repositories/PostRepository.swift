//
//  PostRepository.swift
//  gym app
//
//  Repository for managing posts, likes, and comments in the social feed
//

import CoreData
import Foundation

class PostRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published private(set) var posts: [Post] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Post CRUD Operations

    func loadAll() {
        let request = NSFetchRequest<PostEntity>(entityName: "PostEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            posts = entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "PostRepository.loadAll")
        }
    }

    func save(_ post: Post) {
        let entity = findOrCreateEntity(id: post.id)
        entity.update(from: post)

        do {
            try viewContext.save()
            loadAll()
        } catch {
            Logger.error(error, context: "PostRepository.save")
        }
    }

    func delete(_ post: Post) {
        guard let entity = findEntity(id: post.id) else { return }

        viewContext.delete(entity)

        do {
            try viewContext.save()
            loadAll()
        } catch {
            Logger.error(error, context: "PostRepository.delete")
        }
    }

    func getPost(id: UUID) -> Post? {
        findEntity(id: id)?.toModel()
    }

    // MARK: - Feed Queries

    /// Get posts from friends for the feed
    func getFeedPosts(friendIds: [String], limit: Int = 50, before: Date? = nil) -> [Post] {
        let request = NSFetchRequest<PostEntity>(entityName: "PostEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit

        var predicates: [NSPredicate] = [
            NSPredicate(format: "authorId IN %@", friendIds)
        ]

        if let beforeDate = before {
            predicates.append(NSPredicate(format: "createdAt < %@", beforeDate as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "PostRepository.getFeedPosts")
            return []
        }
    }

    /// Get posts by a specific user
    func getPostsByUser(userId: String, limit: Int = 50, before: Date? = nil) -> [Post] {
        let request = NSFetchRequest<PostEntity>(entityName: "PostEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit

        var predicates: [NSPredicate] = [
            NSPredicate(format: "authorId == %@", userId)
        ]

        if let beforeDate = before {
            predicates.append(NSPredicate(format: "createdAt < %@", beforeDate as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "PostRepository.getPostsByUser")
            return []
        }
    }

    // MARK: - Like Operations

    func saveLike(_ like: PostLike) {
        let entity = findOrCreateLikeEntity(id: like.id)
        entity.update(from: like)

        // Increment like count on post
        if let postEntity = findEntity(id: like.postId) {
            postEntity.likeCount += 1
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

    func isLiked(postId: UUID, userId: String) -> Bool {
        findLikeEntity(postId: postId, userId: userId) != nil
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

    func getComments(postId: UUID, limit: Int = 100) -> [PostComment] {
        let request = NSFetchRequest<PostCommentEntity>(entityName: "PostCommentEntity")
        request.predicate = NSPredicate(format: "postId == %@", postId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = limit

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "PostRepository.getComments")
            return []
        }
    }

    func getComment(id: UUID) -> PostComment? {
        findCommentEntity(id: id)?.toModel()
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> PostEntity? {
        let request = NSFetchRequest<PostEntity>(entityName: "PostEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func updateFromCloud(_ cloudPost: Post) {
        let entity = findOrCreateEntity(id: cloudPost.id)
        entity.update(from: cloudPost)
        entity.syncStatus = .synced
        entity.syncedAt = Date()

        do {
            try viewContext.save()
            loadAll()
        } catch {
            Logger.error(error, context: "PostRepository.updateFromCloud")
        }
    }

    func deleteFromCloud(id: UUID) {
        guard let entity = findEntity(id: id) else { return }

        viewContext.delete(entity)

        do {
            try viewContext.save()
            loadAll()
        } catch {
            Logger.error(error, context: "PostRepository.deleteFromCloud")
        }
    }

    func updateLikeFromCloud(_ cloudLike: PostLike) {
        let entity = findOrCreateLikeEntity(id: cloudLike.id)
        entity.update(from: cloudLike)
        entity.syncStatus = .synced
        entity.syncedAt = Date()

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.updateLikeFromCloud")
        }
    }

    func deleteLikeFromCloud(id: UUID) {
        let request = NSFetchRequest<PostLikeEntity>(entityName: "PostLikeEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? viewContext.fetch(request).first else { return }

        viewContext.delete(entity)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.deleteLikeFromCloud")
        }
    }

    func updateCommentFromCloud(_ cloudComment: PostComment) {
        let entity = findOrCreateCommentEntity(id: cloudComment.id)
        entity.update(from: cloudComment)
        entity.syncStatus = .synced
        entity.syncedAt = Date()

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.updateCommentFromCloud")
        }
    }

    func deleteCommentFromCloud(id: UUID) {
        guard let entity = findCommentEntity(id: id) else { return }

        viewContext.delete(entity)

        do {
            try viewContext.save()
        } catch {
            Logger.error(error, context: "PostRepository.deleteCommentFromCloud")
        }
    }

    // MARK: - Private Helpers

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
