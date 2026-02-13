//
//  FirestoreMessagingService.swift
//  gym app
//
//  Handles messaging features: Conversations and messages.
//

import Foundation
import FirebaseFirestore

// MARK: - Messaging Service

/// Handles conversations and messages
@MainActor
class FirestoreMessagingService: ObservableObject {
    static let shared = FirestoreMessagingService()

    private let core = FirestoreCore.shared

    // MARK: - Conversation Operations

    /// Save a conversation to Firestore
    func saveConversation(_ conversation: Conversation) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations).document(conversation.id.uuidString)
        // Merge basic conversation fields without touching unread metadata.
        let data = encodeConversation(conversation)
        try await ref.setData(data, merge: true)
    }

    /// Fetch conversations for a user
    func fetchConversations(for userId: String) async throws -> [Conversation] {
        let snapshot = try await core.db.collection(FirestoreCollections.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            decodeConversation(from: doc.data(), for: userId)
        }
    }

    /// Listen to conversation changes in real-time
    func listenToConversations(for userId: String, onChange: @escaping ([Conversation]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        core.db.collection(FirestoreCollections.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToConversations")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let conversations = documents.compactMap { doc in
                    self?.decodeConversation(from: doc.data(), for: userId)
                }
                onChange(conversations)
            }
    }

    /// Delete a conversation
    func deleteConversation(id: UUID) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations).document(id.uuidString)

        try await deleteSubcollection(path: ref.collection(FirestoreCollections.messages))
        try await deleteSubcollection(path: ref.collection(FirestoreCollections.typing))
        try await ref.delete()
    }

    // MARK: - Message Operations

    /// Save a message to Firestore
    func saveMessage(_ message: Message) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations)
            .document(message.conversationId.uuidString)
            .collection(FirestoreCollections.messages)
            .document(message.id.uuidString)
        let data = encodeMessage(message)
        try await ref.setData(data, merge: true)
    }

    /// Fetch messages for a conversation with pagination
    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [Message] {
        var query = core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.messages)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let beforeDate = before {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
        }

        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { doc in
            self.decodeMessage(from: doc.data(), conversationId: conversationId)
        }
    }

    /// Listen to messages in real-time
    func listenToMessages(conversationId: UUID, limit: Int = 100, onChange: @escaping ([Message]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.messages)
            .order(by: "createdAt", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToMessages")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let messages = documents.compactMap { doc in
                    self?.decodeMessage(from: doc.data(), conversationId: conversationId)
                }
                onChange(messages)
            }
    }

    /// Soft-delete a message (marks as deleted, replaces content)
    func deleteMessage(conversationId: UUID, messageId: UUID) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.messages)
            .document(messageId.uuidString)

        // Encode a placeholder text content
        let placeholderContent = MessageContent.text("This message was deleted")
        var contentDict: [String: Any] = [:]
        if let contentData = try? JSONEncoder().encode(placeholderContent),
           let dict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            contentDict = dict
        }

        try await ref.updateData([
            "isDeleted": true,
            "content": contentDict
        ])
    }

    /// Mark a message as read
    func markMessageRead(conversationId: UUID, messageId: UUID, at date: Date = Date()) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations)
            .document(conversationId.uuidString)
            .collection(FirestoreCollections.messages)
            .document(messageId.uuidString)
        try await ref.updateData(["readAt": Timestamp(date: date)])
    }

    /// Update conversation metadata when a new message is sent
    func updateConversationOnNewMessage(
        conversationId: UUID,
        recipientId: String,
        preview: String
    ) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations).document(conversationId.uuidString)
        try await ref.updateData([
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastMessagePreview": String(preview.prefix(50)),
            "unreadCounts.\(recipientId)": FieldValue.increment(Int64(1))
        ])
    }

    /// Reset unread count for a user when they open a conversation
    func resetUnreadCount(conversationId: UUID, userId: String) async throws {
        let ref = core.db.collection(FirestoreCollections.conversations).document(conversationId.uuidString)
        try await ref.updateData([
            "unreadCounts.\(userId)": 0
        ])
    }

    /// Fetch a single conversation by ID
    func fetchConversation(id: UUID, for userId: String? = nil) async throws -> Conversation? {
        let doc = try await core.db.collection(FirestoreCollections.conversations).document(id.uuidString).getDocument()
        guard let data = doc.data() else { return nil }
        return decodeConversation(from: data, for: userId)
    }

    // MARK: - Conversation Encoding/Decoding

    private func encodeConversation(_ conversation: Conversation) -> [String: Any] {
        var data: [String: Any] = [
            "id": conversation.id.uuidString,
            "participantIds": conversation.participantIds,
            "createdAt": Timestamp(date: conversation.createdAt)
        ]

        if let lastMessageAt = conversation.lastMessageAt {
            data["lastMessageAt"] = Timestamp(date: lastMessageAt)
        }
        if let preview = conversation.lastMessagePreview {
            data["lastMessagePreview"] = preview
        }

        return data
    }

    private func decodeConversation(from data: [String: Any], for userId: String? = nil) -> Conversation? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let participantIds = data["participantIds"] as? [String] else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let lastMessageAt: Date?
        if let timestamp = data["lastMessageAt"] as? Timestamp {
            lastMessageAt = timestamp.dateValue()
        } else {
            lastMessageAt = nil
        }

        let lastMessagePreview = data["lastMessagePreview"] as? String

        // Extract unread count for the current user
        var unreadCount = 0
        if let userId = userId,
           let unreadCounts = data["unreadCounts"] as? [String: Any] {
            if let count = unreadCounts[userId] as? Int {
                unreadCount = count
            } else if let count = unreadCounts[userId] as? Int64 {
                unreadCount = Int(count)
            } else if let count = unreadCounts[userId] as? NSNumber {
                unreadCount = count.intValue
            }
        }

        return Conversation(
            id: id,
            participantIds: participantIds,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
            lastMessagePreview: lastMessagePreview,
            syncStatus: .synced,
            unreadCount: unreadCount
        )
    }

    // MARK: - Message Encoding/Decoding

    private func encodeMessage(_ message: Message) -> [String: Any] {
        var data: [String: Any] = [
            "id": message.id.uuidString,
            "senderId": message.senderId,
            "createdAt": Timestamp(date: message.createdAt)
        ]

        if let contentData = try? JSONEncoder().encode(message.content),
           let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            data["content"] = contentDict
        }

        if let readAt = message.readAt {
            data["readAt"] = Timestamp(date: readAt)
        }

        if message.isDeleted {
            data["isDeleted"] = true
        }

        return data
    }

    private func decodeMessage(from data: [String: Any], conversationId: UUID) -> Message? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let senderId = data["senderId"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let readAt: Date?
        if let timestamp = data["readAt"] as? Timestamp {
            readAt = timestamp.dateValue()
        } else {
            readAt = nil
        }

        let content: MessageContent
        if let contentDict = data["content"] as? [String: Any] {
            do {
                let contentData = try JSONSerialization.data(withJSONObject: contentDict)
                content = try JSONDecoder().decode(MessageContent.self, from: contentData)
            } catch {
                Logger.error(error, context: "decodeMessage.content - dict: \(contentDict)")
                content = .decodeFailed(originalType: contentDict["type"] as? String)
            }
        } else {
            content = .text("")
        }

        let isDeleted = data["isDeleted"] as? Bool ?? false

        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: createdAt,
            readAt: readAt,
            isDeleted: isDeleted,
            syncStatus: .synced
        )
    }

    private func deleteSubcollection(path: CollectionReference, batchSize: Int = 400) async throws {
        while true {
            let snapshot = try await path.limit(to: batchSize).getDocuments()
            if snapshot.documents.isEmpty { return }

            let batch = core.db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }
}
