//
//  FirestoreActivityService.swift
//  gym app
//
//  Handles moderation reports in Firestore.
//

import Foundation
import FirebaseFirestore

// MARK: - Activity Service

/// Handles moderation reports stored in Firestore.
///
/// Historically this service also wrote/read per-user activity notifications, but
/// the activity feed UI was removed and those unreferenced methods were deleted.
@MainActor
class FirestoreActivityService: ObservableObject {
    static let shared = FirestoreActivityService()

    private let core = FirestoreCore.shared

    // MARK: - Reports

    /// Submit a report to the global reports collection
    func submitReport(_ report: Report) async throws {
        guard core.isAuthenticated else { throw FirestoreError.notAuthenticated }
        let ref = core.db.collection(FirestoreCollections.reports).document(report.id.uuidString)
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
}
