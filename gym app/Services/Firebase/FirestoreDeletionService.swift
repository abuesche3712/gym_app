//
//  FirestoreDeletionService.swift
//  gym app
//
//  Handles deletion record syncing for tracking remote deletions.
//

import Foundation
import FirebaseFirestore

// MARK: - Deletion Service

/// Handles deletion record syncing
@MainActor
class FirestoreDeletionService {
    static let shared = FirestoreDeletionService()

    private let core = FirestoreCore.shared

    // MARK: - Save Deletion Records

    /// Save a deletion record to Firebase
    func saveDeletionRecord(_ record: DeletionRecord) async throws {
        try await core.userCollection(FirestoreCollections.deletions).document(record.id.uuidString).setData(record.firestoreData)
    }

    /// Save multiple deletion records to Firebase
    func saveDeletionRecords(_ records: [DeletionRecord]) async throws {
        let batch = core.db.batch()
        for record in records {
            let docRef = try core.userCollection(FirestoreCollections.deletions).document(record.id.uuidString)
            batch.setData(record.firestoreData, forDocument: docRef)
        }
        try await batch.commit()
    }

    // MARK: - Fetch Deletion Records

    /// Fetch all deletion records from Firebase
    func fetchDeletionRecords() async throws -> [DeletionRecord] {
        let snapshot = try await core.userCollection(FirestoreCollections.deletions).getDocuments()
        return snapshot.documents.compactMap { doc -> DeletionRecord? in
            DeletionRecord(from: doc.data())
        }
    }

    /// Fetch deletion records newer than a given date
    func fetchDeletionRecords(since date: Date) async throws -> [DeletionRecord] {
        let snapshot = try await core.userCollection(FirestoreCollections.deletions)
            .whereField("deletedAt", isGreaterThan: date)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> DeletionRecord? in
            DeletionRecord(from: doc.data())
        }
    }

    // MARK: - Delete Deletion Records

    /// Delete a deletion record from Firebase (for cleanup)
    func deleteDeletionRecord(_ recordId: UUID) async throws {
        try await core.userCollection(FirestoreCollections.deletions).document(recordId.uuidString).delete()
    }

    /// Delete multiple deletion records from Firebase (for batch cleanup)
    func deleteDeletionRecords(_ recordIds: [UUID]) async throws {
        let batch = core.db.batch()
        for id in recordIds {
            let docRef = try core.userCollection(FirestoreCollections.deletions).document(id.uuidString)
            batch.deleteDocument(docRef)
        }
        try await batch.commit()
    }

    /// Cleanup old deletion records from Firebase (older than retention date)
    func cleanupOldDeletionRecords(olderThan date: Date) async throws -> Int {
        let snapshot = try await core.userCollection(FirestoreCollections.deletions)
            .whereField("deletedAt", isLessThan: date)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return 0 }

        let batch = core.db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        return snapshot.documents.count
    }
}
