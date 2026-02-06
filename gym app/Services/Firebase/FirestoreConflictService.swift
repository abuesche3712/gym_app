//
//  FirestoreConflictService.swift
//  gym app
//
//  Handles conflict resolution for bidirectional sync.
//

import Foundation
import FirebaseFirestore

// MARK: - Conflict Service

/// Handles conflict resolution and bidirectional sync
@MainActor
class FirestoreConflictService {
    static let shared = FirestoreConflictService()

    private let core = FirestoreCore.shared
    private let syncService = FirestoreSyncService.shared

    // MARK: - Resolution Types

    /// Resolution decision for sync conflicts
    enum ConflictResolution {
        case useCloud       // Cloud data is newer, use it
        case useLocal       // Local data is newer, push it
        case noConflict     // Data doesn't exist on one side
    }

    /// Determine conflict resolution by comparing timestamps
    func resolveConflict(localUpdatedAt: Date, cloudUpdatedAt: Date?) -> ConflictResolution {
        guard let cloudDate = cloudUpdatedAt else {
            return .useLocal
        }

        if cloudDate > localUpdatedAt {
            return .useCloud
        } else {
            return .useLocal
        }
    }

    // MARK: - Timestamp Fetching

    /// Fetch cloud timestamp for a specific module
    func fetchModuleTimestamp(_ moduleId: UUID) async throws -> Date? {
        let doc = try await core.userCollection(FirestoreCollections.modules).document(moduleId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific workout
    func fetchWorkoutTimestamp(_ workoutId: UUID) async throws -> Date? {
        let doc = try await core.userCollection(FirestoreCollections.workouts).document(workoutId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific session
    func fetchSessionTimestamp(_ sessionId: UUID) async throws -> Date? {
        let doc = try await core.userCollection(FirestoreCollections.sessions).document(sessionId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific program
    func fetchProgramTimestamp(_ programId: UUID) async throws -> Date? {
        let doc = try await core.userCollection(FirestoreCollections.programs).document(programId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a custom exercise
    func fetchCustomExerciseTimestamp(_ exerciseId: UUID) async throws -> Date? {
        let doc = try await core.userCollection(FirestoreCollections.customExercises).document(exerciseId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    // MARK: - Conflict-Aware Save Methods

    /// Save module with conflict resolution
    func saveModuleWithConflictCheck(_ module: Module, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchModuleTimestamp(module.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await syncService.saveModule(module)
            return true
        case .useCloud:
            return false
        }
    }

    /// Save workout with conflict resolution
    func saveWorkoutWithConflictCheck(_ workout: Workout, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchWorkoutTimestamp(workout.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await syncService.saveWorkout(workout)
            return true
        case .useCloud:
            return false
        }
    }

    /// Save session with conflict resolution
    func saveSessionWithConflictCheck(_ session: Session, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchSessionTimestamp(session.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await syncService.saveSession(session)
            return true
        case .useCloud:
            return false
        }
    }

    /// Save program with conflict resolution
    func saveProgramWithConflictCheck(_ program: Program, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchProgramTimestamp(program.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await syncService.saveProgram(program)
            return true
        case .useCloud:
            return false
        }
    }

    // MARK: - Fetch with Timestamps

    /// Represents a cloud entity with its timestamp for conflict checking
    struct CloudEntity<T> {
        let entity: T
        let updatedAt: Date?
    }

    /// Fetch modules with their cloud timestamps
    func fetchModulesWithTimestamps() async throws -> [CloudEntity<Module>] {
        let snapshot = try await core.userCollection(FirestoreCollections.modules).getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Module>? in
            guard let module = try? core.decode(Module.self, from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: module, updatedAt: timestamp)
        }
    }

    /// Fetch workouts with their cloud timestamps
    func fetchWorkoutsWithTimestamps() async throws -> [CloudEntity<Workout>] {
        let snapshot = try await core.userCollection(FirestoreCollections.workouts).getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Workout>? in
            guard let workout = try? core.decode(Workout.self, from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: workout, updatedAt: timestamp)
        }
    }

    /// Fetch sessions with their cloud timestamps
    func fetchSessionsWithTimestamps() async throws -> [CloudEntity<Session>] {
        let snapshot = try await core.userCollection(FirestoreCollections.sessions).getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Session>? in
            guard let session = try? core.decode(Session.self, from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: session, updatedAt: timestamp)
        }
    }

    /// Fetch programs with their cloud timestamps
    func fetchProgramsWithTimestamps() async throws -> [CloudEntity<Program>] {
        let snapshot = try await core.userCollection(FirestoreCollections.programs).getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Program>? in
            guard let program = try? core.decode(Program.self, from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: program, updatedAt: timestamp)
        }
    }

    // MARK: - Bidirectional Sync Helper

    /// Sync result containing items that need local updates and items successfully pushed
    struct SyncResult<T> {
        let pushedCount: Int
        let cloudNewerItems: [T]  // Items where cloud is newer, need local update
        let errors: [Error]
    }

    /// Perform bidirectional sync for modules
    func syncModulesBidirectional(
        localModules: [(module: Module, localUpdatedAt: Date, syncedAt: Date?)]
    ) async throws -> SyncResult<Module> {
        var pushedCount = 0
        var cloudNewerItems: [Module] = []
        var errors: [Error] = []

        let cloudModules = try await fetchModulesWithTimestamps()
        let cloudModuleMap = Dictionary(uniqueKeysWithValues: cloudModules.map { ($0.entity.id, $0) })

        for local in localModules {
            do {
                let cloudEntity = cloudModuleMap[local.module.id]

                if let cloud = cloudEntity {
                    let resolution = resolveConflict(
                        localUpdatedAt: local.localUpdatedAt,
                        cloudUpdatedAt: cloud.updatedAt
                    )

                    switch resolution {
                    case .useLocal:
                        try await syncService.saveModule(local.module)
                        pushedCount += 1
                    case .useCloud:
                        cloudNewerItems.append(cloud.entity)
                    case .noConflict:
                        try await syncService.saveModule(local.module)
                        pushedCount += 1
                    }
                } else {
                    try await syncService.saveModule(local.module)
                    pushedCount += 1
                }
            } catch {
                errors.append(error)
            }
        }

        let localIds = Set(localModules.map { $0.module.id })
        for cloud in cloudModules where !localIds.contains(cloud.entity.id) {
            cloudNewerItems.append(cloud.entity)
        }

        return SyncResult(pushedCount: pushedCount, cloudNewerItems: cloudNewerItems, errors: errors)
    }
}
