//
//  FirestoreActivityService.swift
//  gym app
//
//  Handles activity/notification features in Firestore.
//

import Foundation
import FirebaseFirestore

// MARK: - Activity Service

/// Handles activities (notifications) stored in Firestore
@MainActor
class FirestoreActivityService: ObservableObject {
    static let shared = FirestoreActivityService()

    private let core = FirestoreCore.shared

    // MARK: - Create Activity

    /// Create a new activity notification
    func createActivity(_ activity: Activity) async throws {
        // Don't create activity for self-actions
        guard activity.actorId != activity.recipientId else { return }

        let ref = core.db.collection("users")
            .document(activity.recipientId)
            .collection("activities")
            .document(activity.id.uuidString)

        let data = encodeActivity(activity)
        try await ref.setData(data)
    }

    // MARK: - Listen to Activities

    /// Listen to activities for a user in real-time
    func listenToActivities(
        userId: String,
        limit: Int = 50,
        onChange: @escaping ([Activity]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        core.db.collection("users")
            .document(userId)
            .collection("activities")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToActivities")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let activities = documents.compactMap { doc in
                    self?.decodeActivity(from: doc.data())
                }
                onChange(activities)
            }
    }

    // MARK: - Read Status

    /// Mark a single activity as read
    func markAsRead(userId: String, activityId: UUID) async throws {
        let ref = core.db.collection("users")
            .document(userId)
            .collection("activities")
            .document(activityId.uuidString)
        try await ref.updateData(["isRead": true])
    }

    /// Mark all activities as read for a user
    func markAllAsRead(userId: String) async throws {
        let snapshot = try await core.db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = core.db.batch()
        for doc in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    /// Fetch unread count
    func fetchUnreadCount(userId: String) async throws -> Int {
        let snapshot = try await core.db.collection("users")
            .document(userId)
            .collection("activities")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        return snapshot.documents.count
    }

    // MARK: - Reports

    /// Submit a report to the global reports collection
    func submitReport(_ report: Report) async throws {
        let ref = core.db.collection("reports").document(report.id.uuidString)
        let data: [String: Any] = [
            "id": report.id.uuidString,
            "reporterId": report.reporterId,
            "reportedUserId": report.reportedUserId,
            "contentType": report.contentType.rawValue,
            "contentId": report.contentId as Any,
            "reason": report.reason.rawValue,
            "additionalInfo": report.additionalInfo as Any,
            "createdAt": Timestamp(date: report.createdAt)
        ]
        try await ref.setData(data)
    }

    // MARK: - Encoding/Decoding

    private func encodeActivity(_ activity: Activity) -> [String: Any] {
        var data: [String: Any] = [
            "id": activity.id.uuidString,
            "recipientId": activity.recipientId,
            "actorId": activity.actorId,
            "type": activity.type.rawValue,
            "isRead": activity.isRead,
            "createdAt": Timestamp(date: activity.createdAt)
        ]

        if let postId = activity.postId {
            data["postId"] = postId.uuidString
        }
        if let preview = activity.preview {
            data["preview"] = String(preview.prefix(100))
        }

        return data
    }

    private func decodeActivity(from data: [String: Any]) -> Activity? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let recipientId = data["recipientId"] as? String,
              let actorId = data["actorId"] as? String,
              let typeString = data["type"] as? String,
              let type = ActivityType(rawValue: typeString) else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let postId: UUID?
        if let postIdString = data["postId"] as? String {
            postId = UUID(uuidString: postIdString)
        } else {
            postId = nil
        }

        let preview = data["preview"] as? String
        let isRead = data["isRead"] as? Bool ?? false

        return Activity(
            id: id,
            recipientId: recipientId,
            actorId: actorId,
            type: type,
            postId: postId,
            preview: preview,
            isRead: isRead,
            createdAt: createdAt
        )
    }
}
