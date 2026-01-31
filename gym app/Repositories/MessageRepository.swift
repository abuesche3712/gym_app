//
//  MessageRepository.swift
//  gym app
//
//  Handles Message CRUD operations and CoreData conversion
//

import CoreData
import Combine

@MainActor
class MessageRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - CRUD Operations

    /// Save or update a message
    func save(_ message: Message) {
        var messageToSave = message
        messageToSave.syncStatus = .pendingSync

        let entity = findOrCreateEntity(id: message.id)
        entity.update(from: messageToSave)
        persistence.save()
    }

    /// Delete a message
    func delete(_ message: Message) {
        if let entity = findEntity(id: message.id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    /// Get a message by ID
    func getMessage(id: UUID) -> Message? {
        if let entity = findEntity(id: id) {
            return entity.toModel()
        }
        return nil
    }

    // MARK: - Query Operations

    /// Get messages for a conversation with optional pagination
    func getMessages(for conversationId: UUID, limit: Int? = nil, before: Date? = nil) -> [Message] {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")

        var predicates: [NSPredicate] = [
            NSPredicate(format: "conversationId == %@", conversationId as CVarArg)
        ]

        if let beforeDate = before {
            predicates.append(NSPredicate(format: "createdAt < %@", beforeDate as CVarArg))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "MessageRepository.getMessages")
            return []
        }
    }

    /// Get the latest message for a conversation
    func getLatestMessage(for conversationId: UUID) -> Message? {
        getMessages(for: conversationId, limit: 1).first
    }

    /// Get all messages for a conversation (for display, sorted oldest first)
    func getAllMessages(for conversationId: UUID) -> [Message] {
        let messages = getMessages(for: conversationId)
        return messages.reversed() // Return in chronological order
    }

    // MARK: - Actions

    /// Create and save a new message
    func sendMessage(conversationId: UUID, senderId: String, content: MessageContent) -> Message {
        let message = Message(
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: Date()
        )

        save(message)
        return message
    }

    /// Mark a message as read
    func markAsRead(_ message: Message, at date: Date = Date()) {
        var updatedMessage = message
        updatedMessage.readAt = date
        save(updatedMessage)
    }

    /// Mark all messages in a conversation as read for a specific user
    func markAllAsRead(in conversationId: UUID, for userId: String) {
        let messages = getMessages(for: conversationId)
        let now = Date()

        for message in messages {
            // Only mark messages from OTHER users as read
            if message.senderId != userId && message.readAt == nil {
                var updatedMessage = message
                updatedMessage.readAt = now
                save(updatedMessage)
            }
        }
    }

    /// Get count of unread messages in a conversation for a user
    func getUnreadCount(in conversationId: UUID, for userId: String) -> Int {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "conversationId == %@", conversationId as CVarArg),
            NSPredicate(format: "senderId != %@", userId),
            NSPredicate(format: "readAt == nil")
        ])

        do {
            return try viewContext.count(for: request)
        } catch {
            Logger.error(error, context: "MessageRepository.getUnreadCount")
            return 0
        }
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> MessageEntity? {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    /// Update from cloud data
    func updateFromCloud(_ cloudMessage: Message) {
        let entity = findOrCreateEntity(id: cloudMessage.id)
        var merged = cloudMessage
        merged.syncStatus = .synced
        entity.update(from: merged)
        persistence.save()
    }

    /// Delete from cloud sync
    func deleteFromCloud(id: UUID) {
        if let entity = findEntity(id: id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    /// Delete all messages for a conversation
    func deleteAllMessages(for conversationId: UUID) {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "conversationId == %@", conversationId as CVarArg)

        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                viewContext.delete(entity)
            }
            persistence.save()
        } catch {
            Logger.error(error, context: "MessageRepository.deleteAllMessages")
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateEntity(id: UUID) -> MessageEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = MessageEntity(context: viewContext)
        entity.id = id
        return entity
    }
}
