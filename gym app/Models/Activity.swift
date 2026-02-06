//
//  Activity.swift
//  gym app
//
//  Activity/notification model for the social feed
//

import Foundation

// MARK: - Activity Type

enum ActivityType: String, Codable {
    case like
    case comment
    case friendRequest
    case friendAccepted
}

// MARK: - Activity Model

struct Activity: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientId: String   // Firebase UID of the user receiving the notification
    var actorId: String       // Firebase UID of the user who performed the action
    var type: ActivityType
    var postId: UUID?         // Related post (for likes/comments)
    var preview: String?      // Preview text
    var isRead: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recipientId: String,
        actorId: String,
        type: ActivityType,
        postId: UUID? = nil,
        preview: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recipientId = recipientId
        self.actorId = actorId
        self.type = type
        self.postId = postId
        self.preview = preview
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - Activity With Actor Profile

struct ActivityWithActor: Identifiable, Hashable {
    let activity: Activity
    let actor: UserProfile

    var id: UUID { activity.id }
}

// MARK: - Activity Helpers

extension Activity {
    func descriptionText(actorName: String) -> String {
        switch type {
        case .like:
            return "\(actorName) liked your post"
        case .comment:
            if let preview = preview {
                return "\(actorName) commented: \"\(preview)\""
            }
            return "\(actorName) commented on your post"
        case .friendRequest:
            return "\(actorName) sent you a friend request"
        case .friendAccepted:
            return "\(actorName) accepted your friend request"
        }
    }

    var icon: String {
        switch type {
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "person.2.fill"
        }
    }
}
