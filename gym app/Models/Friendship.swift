//
//  Friendship.swift
//  gym app
//
//  Friendship model for social feature Phase 2
//

import Foundation

/// Represents a friendship or friend request between two users
struct Friendship: Identifiable, Codable, Hashable {
    var schemaVersion: Int = SchemaVersions.friendship
    var id: UUID
    var requesterId: String      // Firebase UID of who sent the request
    var addresseeId: String      // Firebase UID of who received the request
    var status: FriendshipStatus
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        requesterId: String,
        addresseeId: String,
        status: FriendshipStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.requesterId = requesterId
        self.addresseeId = addresseeId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.friendship
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        requesterId = try container.decode(String.self, forKey: .requesterId)
        addresseeId = try container.decode(String.self, forKey: .addresseeId)
        status = try container.decodeIfPresent(FriendshipStatus.self, forKey: .status) ?? .pending
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pendingSync
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, requesterId, addresseeId, status, createdAt, updatedAt, syncStatus
    }
}

/// Status of a friendship
enum FriendshipStatus: String, Codable, CaseIterable {
    case pending    // request sent, awaiting response
    case accepted   // friends
    case blocked    // requesterId blocked addresseeId
}

// MARK: - Friendship Helpers

extension Friendship {
    /// Check if this friendship involves a specific user
    func involves(userId: String) -> Bool {
        requesterId == userId || addresseeId == userId
    }

    /// Get the other user's ID from this friendship
    func otherUserId(from myId: String) -> String? {
        if requesterId == myId {
            return addresseeId
        } else if addresseeId == myId {
            return requesterId
        }
        return nil
    }

    var isAccepted: Bool {
        status == .accepted
    }

    var isPending: Bool {
        status == .pending
    }

    var isBlocked: Bool {
        status == .blocked
    }

    /// Check if this is an incoming request for the given user
    func isIncomingRequest(for userId: String) -> Bool {
        isPending && addresseeId == userId
    }

    /// Check if this is an outgoing request from the given user
    func isOutgoingRequest(from userId: String) -> Bool {
        isPending && requesterId == userId
    }
}
