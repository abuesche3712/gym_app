//
//  ConversationRepository.swift
//  gym app
//
//  Handles Conversation CRUD operations and CoreData conversion
//

import CoreData
import Combine

@MainActor
class ConversationRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published private(set) var conversations: [Conversation] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadAll()
    }

    // MARK: - CRUD Operations

    /// Load all conversations from CoreData
    func loadAll() {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastMessageAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            let entities = try viewContext.fetch(request)
            conversations = entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "ConversationRepository.loadAll")
        }
    }

    /// Save or update a conversation
    func save(_ conversation: Conversation) {
        var conversationToSave = conversation
        conversationToSave.syncStatus = .pendingSync

        let entity = findOrCreateEntity(id: conversation.id)
        entity.update(from: conversationToSave)
        persistence.save()

        loadAll()
    }

    /// Delete a conversation
    func delete(_ conversation: Conversation) {
        if let entity = findEntity(id: conversation.id) {
            viewContext.delete(entity)
            persistence.save()
        }
        loadAll()
    }

    /// Get a conversation by ID
    func getConversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    // MARK: - Query Operations

    /// Get conversation between two specific users
    func getConversation(between userA: String, and userB: String) -> Conversation? {
        conversations.first { conversation in
            conversation.participantIds.contains(userA) &&
            conversation.participantIds.contains(userB)
        }
    }

    /// Get all conversations for a user, sorted by most recent
    func getAllConversations(for userId: String) -> [Conversation] {
        conversations.filter { $0.hasParticipant(userId) }
            .sorted { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
    }

    /// Get or create a conversation between two users
    func getOrCreateConversation(between userA: String, and userB: String) -> Conversation {
        // Check if conversation already exists by participant match
        if let existing = getConversation(between: userA, and: userB) {
            return existing
        }

        // Generate canonical ID from sorted participants
        let participants = [userA, userB].sorted()
        let canonicalId = Conversation.canonicalId(for: participants)

        // Check if conversation with canonical ID exists locally
        if let existingById = getConversation(id: canonicalId) {
            return existingById
        }

        // Create new conversation with canonical ID
        let conversation = Conversation(
            id: canonicalId,
            participantIds: participants,
            createdAt: Date()
        )

        save(conversation)
        return conversation
    }

    // MARK: - Unread Management

    /// Mark all messages in a conversation as read for a user
    func markConversationRead(_ conversationId: UUID, for userId: String) {
        guard var conversation = getConversation(id: conversationId) else { return }
        conversation.unreadCount = 0
        save(conversation)
    }

    /// Get total unread count across all conversations
    func getTotalUnreadCount(for userId: String) -> Int {
        getAllConversations(for: userId).reduce(0) { $0 + $1.unreadCount }
    }

    /// Update conversation with latest message info
    func updateLastMessage(_ conversationId: UUID, preview: String, at date: Date) {
        guard var conversation = getConversation(id: conversationId) else { return }
        conversation.lastMessageAt = date
        conversation.lastMessagePreview = String(preview.prefix(50))
        save(conversation)
    }

    /// Increment unread count for a conversation
    func incrementUnreadCount(_ conversationId: UUID) {
        guard var conversation = getConversation(id: conversationId) else { return }
        conversation.unreadCount += 1
        save(conversation)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> ConversationEntity? {
        let request = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    /// Update from cloud data
    func updateFromCloud(_ cloudConversation: Conversation) {
        if let local = getConversation(id: cloudConversation.id) {
            // Merge: take newer lastMessageAt, preserve local unreadCount
            let entity = findOrCreateEntity(id: cloudConversation.id)
            var merged = cloudConversation
            merged.syncStatus = .synced

            // Preserve local unread count (not synced)
            merged.unreadCount = local.unreadCount

            // Take the more recent lastMessageAt
            if let cloudDate = cloudConversation.lastMessageAt,
               let localDate = local.lastMessageAt {
                merged.lastMessageAt = max(cloudDate, localDate)
            }

            entity.update(from: merged)
            persistence.save()
            loadAll()
        } else {
            // No local version, save cloud version
            let entity = findOrCreateEntity(id: cloudConversation.id)
            var merged = cloudConversation
            merged.syncStatus = .synced
            entity.update(from: merged)
            persistence.save()
            loadAll()
        }
    }

    /// Delete from cloud sync
    func deleteFromCloud(id: UUID) {
        if let entity = findEntity(id: id) {
            viewContext.delete(entity)
            persistence.save()
            loadAll()
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateEntity(id: UUID) -> ConversationEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = ConversationEntity(context: viewContext)
        entity.id = id
        return entity
    }
}
