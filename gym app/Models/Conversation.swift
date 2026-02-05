//
//  Conversation.swift
//  gym app
//
//  Conversation model for direct messaging (Phase 3)
//

import Foundation

/// Represents a conversation between two users
struct Conversation: Identifiable, Codable, Hashable {
    var schemaVersion: Int = SchemaVersions.conversation
    var id: UUID
    var participantIds: [String]  // Firebase UIDs - exactly 2 for DMs
    var createdAt: Date
    var lastMessageAt: Date?
    var lastMessagePreview: String?  // first ~50 chars of last message
    var syncStatus: SyncStatus

    // Local-only (not synced to cloud)
    var unreadCount: Int = 0

    init(
        id: UUID = UUID(),
        participantIds: [String],
        createdAt: Date = Date(),
        lastMessageAt: Date? = nil,
        lastMessagePreview: String? = nil,
        syncStatus: SyncStatus = .pendingSync,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.participantIds = participantIds
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.lastMessagePreview = lastMessagePreview
        self.syncStatus = syncStatus
        self.unreadCount = unreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.conversation
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        participantIds = try container.decode([String].self, forKey: .participantIds)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pendingSync
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, participantIds, createdAt, lastMessageAt, lastMessagePreview, syncStatus, unreadCount
    }
}

// MARK: - Conversation Helpers

extension Conversation {
    /// Get the other participant's ID from this conversation
    func otherParticipantId(from myId: String) -> String? {
        participantIds.first { $0 != myId }
    }

    /// Check if conversation has unread messages
    var isUnread: Bool {
        unreadCount > 0
    }

    /// Check if a user is a participant
    func hasParticipant(_ userId: String) -> Bool {
        participantIds.contains(userId)
    }

    /// Generates a deterministic UUID for a conversation between two users.
    /// This ensures the same conversation ID is created regardless of which device initiates.
    static func canonicalId(for participantIds: [String]) -> UUID {
        let sorted = participantIds.sorted()
        let combined = sorted.joined(separator: "_")

        // Create deterministic UUID using djb2 hash
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Convert hash to UUID bytes
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((hash >> (i * 8)) & 0xFF)
        }
        // Fill second half with shifted hash
        let hash2 = hash &* 31
        for i in 0..<8 {
            bytes[8 + i] = UInt8((hash2 >> (i * 8)) & 0xFF)
        }

        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                          bytes[4], bytes[5], bytes[6], bytes[7],
                          bytes[8], bytes[9], bytes[10], bytes[11],
                          bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
