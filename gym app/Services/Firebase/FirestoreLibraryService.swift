//
//  FirestoreLibraryService.swift
//  gym app
//
//  Handles read-only library fetches (exercises, equipment, progression schemes).
//

import Foundation
import FirebaseFirestore

// MARK: - Library Service

/// Handles read-only library fetches from global collections
@MainActor
class FirestoreLibraryService {
    static let shared = FirestoreLibraryService()

    private let core = FirestoreCore.shared
    private let syncService = FirestoreSyncService.shared

    // MARK: - Exercise Library

    /// Fetch exercise library templates from cloud (root-level, read-only)
    func fetchExerciseLibrary() async throws -> [ExerciseTemplate] {
        let snapshot = try await core.db.collection("libraries")
            .document("exerciseLibrary")
            .collection("exercises")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            syncService.decodeExerciseTemplate(from: doc.data())
        }
    }

    // MARK: - Equipment Library

    /// Fetch equipment library from cloud (root-level, read-only)
    func fetchEquipmentLibrary() async throws -> [[String: Any]] {
        let snapshot = try await core.db.collection("libraries")
            .document("equipmentLibrary")
            .collection("equipment")
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Progression Schemes

    /// Fetch progression schemes from cloud (root-level, read-only)
    func fetchProgressionSchemes() async throws -> [[String: Any]] {
        let snapshot = try await core.db.collection("libraries")
            .document("progressionSchemes")
            .collection("schemes")
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }
}
