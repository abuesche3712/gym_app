//
//  SyncHandlers.swift
//  gym app
//
//  Protocol and concrete handlers for entity-specific sync operations.
//  Used by SyncQueueProcessor to eliminate repetitive sync methods.
//

import Foundation

// MARK: - SyncHandler Protocol

/// Protocol for handling sync of a specific entity type
protocol SyncHandler {
    associatedtype Entity: Codable & Identifiable where Entity.ID == UUID

    var entityType: SyncEntityType { get }

    func save(_ entity: Entity) async throws
    func delete(id: UUID) async throws
}

// MARK: - Type-Erased Wrapper

/// Type-erased wrapper for SyncHandler to allow storing in a dictionary
struct AnySyncHandler {
    let entityType: SyncEntityType
    private let _decode: (Data) throws -> Any
    private let _save: (Any) async throws -> Void
    private let _delete: (UUID) async throws -> Void
    private let _getId: (Any) -> UUID

    init<H: SyncHandler>(_ handler: H) {
        self.entityType = handler.entityType
        self._decode = { data in
            try JSONDecoder().decode(H.Entity.self, from: data)
        }
        self._save = { entity in
            guard let typed = entity as? H.Entity else { throw SyncError.decodingFailed }
            try await handler.save(typed)
        }
        self._delete = { id in
            try await handler.delete(id: id)
        }
        self._getId = { entity in
            guard let typed = entity as? H.Entity else { return UUID() }
            return typed.id
        }
    }

    func process(payload: Data, action: SyncAction) async throws {
        switch action {
        case .create, .update:
            let entity = try _decode(payload)
            try await _save(entity)
        case .delete:
            let entity = try _decode(payload)
            let id = _getId(entity)
            try await _delete(id)
        }
    }
}

// MARK: - Concrete Handlers

struct ModuleSyncHandler: SyncHandler {
    typealias Entity = Module

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .module }

    func save(_ entity: Module) async throws {
        try await firestoreService.saveModule(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteModule(id)
    }
}

struct WorkoutSyncHandler: SyncHandler {
    typealias Entity = Workout

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .workout }

    func save(_ entity: Workout) async throws {
        try await firestoreService.saveWorkout(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteWorkout(id)
    }
}

struct SessionSyncHandler: SyncHandler {
    typealias Entity = Session

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .session }

    func save(_ entity: Session) async throws {
        try await firestoreService.saveSession(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteSession(id)
    }
}

struct ProgramSyncHandler: SyncHandler {
    typealias Entity = Program

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .program }

    func save(_ entity: Program) async throws {
        try await firestoreService.saveProgram(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteProgram(id)
    }
}

struct ScheduledWorkoutSyncHandler: SyncHandler {
    typealias Entity = ScheduledWorkout

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .scheduledWorkout }

    func save(_ entity: ScheduledWorkout) async throws {
        try await firestoreService.saveScheduledWorkout(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteScheduledWorkout(id)
    }
}

struct CustomExerciseSyncHandler: SyncHandler {
    typealias Entity = ExerciseTemplate

    let firestoreService: FirestoreService

    var entityType: SyncEntityType { .customExercise }

    func save(_ entity: ExerciseTemplate) async throws {
        try await firestoreService.saveCustomExercise(entity)
    }

    func delete(id: UUID) async throws {
        try await firestoreService.deleteCustomExercise(id)
    }
}
