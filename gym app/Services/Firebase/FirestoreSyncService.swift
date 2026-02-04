//
//  FirestoreSyncService.swift
//  gym app
//
//  Handles sync operations for core entities (Module, Workout, Session, Program, etc.)
//  Includes CRUD operations and entity-specific encoding/decoding.
//

import Foundation
import FirebaseFirestore

// MARK: - Sync Service

/// Handles sync operations for core entities
@MainActor
class FirestoreSyncService: ObservableObject {
    static let shared = FirestoreSyncService()

    private let core = FirestoreCore.shared

    @Published var isSyncing = false
    @Published var lastError: Error?
    @Published private(set) var decodeFailures: [DecodeFailure] = []

    /// Returns true if there are unresolved decode failures
    var hasDecodeFailures: Bool { !decodeFailures.isEmpty }

    /// Clears tracked decode failures
    func clearDecodeFailures() {
        decodeFailures.removeAll()
    }

    private func trackDecodeFailure(documentId: String, collection: String, error: Error) {
        let failure = DecodeFailure(
            id: documentId,
            collection: collection,
            error: error,
            timestamp: Date()
        )
        decodeFailures.append(failure)
        Logger.error(error, context: "Failed to decode \(collection)/\(documentId) - data may be lost or corrupted")
    }

    // MARK: - Module Operations

    func saveModule(_ module: Module) async throws {
        let ref = try core.userCollection("modules").document(module.id.uuidString)
        let data = try encodeModule(module)
        try await ref.setData(data, merge: true)
    }

    func fetchModules() async throws -> [Module] {
        let snapshot = try await core.userCollection("modules").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try decodeModule(from: doc.data())
            } catch {
                trackDecodeFailure(documentId: doc.documentID, collection: "modules", error: error)
                return nil
            }
        }
    }

    func deleteModule(_ moduleId: UUID) async throws {
        try await core.userCollection("modules").document(moduleId.uuidString).delete()
    }

    // MARK: - Workout Operations

    func saveWorkout(_ workout: Workout) async throws {
        let ref = try core.userCollection("workouts").document(workout.id.uuidString)
        let data = try encodeWorkout(workout)
        try await ref.setData(data, merge: true)
    }

    func fetchWorkouts() async throws -> [Workout] {
        let snapshot = try await core.userCollection("workouts").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try decodeWorkout(from: doc.data())
            } catch {
                trackDecodeFailure(documentId: doc.documentID, collection: "workouts", error: error)
                return nil
            }
        }
    }

    func deleteWorkout(_ workoutId: UUID) async throws {
        try await core.userCollection("workouts").document(workoutId.uuidString).delete()
    }

    // MARK: - Session Operations

    func saveSession(_ session: Session) async throws {
        let ref = try core.userCollection("sessions").document(session.id.uuidString)
        let data = try encodeSession(session)
        try await ref.setData(data, merge: true)
    }

    func fetchSessions() async throws -> [Session] {
        let snapshot = try await core.userCollection("sessions").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try decodeSession(from: doc.data())
            } catch {
                trackDecodeFailure(documentId: doc.documentID, collection: "sessions", error: error)
                return nil
            }
        }
    }

    func deleteSession(_ sessionId: UUID) async throws {
        try await core.userCollection("sessions").document(sessionId.uuidString).delete()
    }

    /// Incremental update for a single set during active workout
    func updateSessionSet(sessionId: UUID, exerciseId: UUID, set: SetData) async throws {
        let ref = try core.userCollection("sessions").document(sessionId.uuidString)
            .collection("livesets").document(set.id.uuidString)

        let data: [String: Any] = [
            "id": set.id.uuidString,
            "exerciseId": exerciseId.uuidString,
            "setNumber": set.setNumber,
            "weight": set.weight as Any,
            "reps": set.reps as Any,
            "rpe": set.rpe as Any,
            "completed": set.completed,
            "duration": set.duration as Any,
            "distance": set.distance as Any,
            "pace": set.pace as Any,
            "avgHeartRate": set.avgHeartRate as Any,
            "holdTime": set.holdTime as Any,
            "intensity": set.intensity as Any,
            "height": set.height as Any,
            "quality": set.quality as Any,
            "temperature": set.temperature as Any,
            "restAfter": set.restAfter as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: true)
    }

    // MARK: - Program Operations

    func saveProgram(_ program: Program) async throws {
        let ref = try core.userCollection("programs").document(program.id.uuidString)
        let data = try encodeProgram(program)
        try await ref.setData(data, merge: true)
    }

    func fetchPrograms() async throws -> [Program] {
        let snapshot = try await core.userCollection("programs").getDocuments()
        Logger.debug("fetchPrograms: Found \(snapshot.documents.count) program documents in Firebase")

        return snapshot.documents.compactMap { doc in
            do {
                let program = try decodeProgram(from: doc.data())
                Logger.debug("fetchPrograms: Successfully decoded program '\(program.name)' (id: \(program.id))")
                return program
            } catch {
                Logger.error(error, context: "Failed to decode program \(doc.documentID)")
                Logger.debug("fetchPrograms: Document keys: \(doc.data().keys.sorted().joined(separator: ", "))")
                let data = doc.data()
                Logger.debug("fetchPrograms: Raw field check - id: \(data["id"] ?? "nil"), name: \(data["name"] ?? "nil")")
                return nil
            }
        }
    }

    func deleteProgram(_ programId: UUID) async throws {
        try await core.userCollection("programs").document(programId.uuidString).delete()
    }

    // MARK: - Scheduled Workout Operations

    func saveScheduledWorkout(_ scheduled: ScheduledWorkout) async throws {
        let ref = try core.userCollection("scheduledWorkouts").document(scheduled.id.uuidString)
        let data = try encodeScheduledWorkout(scheduled)
        try await ref.setData(data, merge: true)
    }

    func fetchScheduledWorkouts() async throws -> [ScheduledWorkout] {
        let snapshot = try await core.userCollection("scheduledWorkouts").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try decodeScheduledWorkout(from: doc.data())
            } catch {
                Logger.error(error, context: "Failed to decode scheduledWorkout \(doc.documentID)")
                return nil
            }
        }
    }

    func deleteScheduledWorkout(_ scheduledId: UUID) async throws {
        try await core.userCollection("scheduledWorkouts").document(scheduledId.uuidString).delete()
    }

    func deleteScheduledWorkoutsForProgram(_ programId: UUID) async throws {
        let snapshot = try await core.userCollection("scheduledWorkouts")
            .whereField("programId", isEqualTo: programId.uuidString)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Custom Exercise Operations

    func saveCustomExercise(_ template: ExerciseTemplate) async throws {
        let ref = try core.userCollection("customExercises").document(template.id.uuidString)
        let data = encodeExerciseTemplate(template)
        try await ref.setData(data, merge: true)
    }

    func fetchCustomExercises() async throws -> [ExerciseTemplate] {
        let snapshot = try await core.userCollection("customExercises").getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeExerciseTemplate(from: doc.data())
        }
    }

    func deleteCustomExercise(_ exerciseId: UUID) async throws {
        try await core.userCollection("customExercises").document(exerciseId.uuidString).delete()
    }

    /// One-time migration from legacy per-user exerciseLibrary to customExercises
    @discardableResult
    func migrateExerciseLibraryToCustomExercises() async throws -> Int {
        let userReference = try core.userRef()
        let oldCollection = userReference.collection("exerciseLibrary")
        let newCollection = userReference.collection("customExercises")

        let oldSnapshot = try await oldCollection.getDocuments()
        guard !oldSnapshot.documents.isEmpty else {
            Logger.debug("No exercises to migrate from exerciseLibrary")
            return 0
        }

        let existingSnapshot = try await newCollection.getDocuments()
        let existingIds = Set(existingSnapshot.documents.map { $0.documentID })

        var migratedCount = 0
        for doc in oldSnapshot.documents {
            if existingIds.contains(doc.documentID) {
                Logger.debug("Skipping \(doc.documentID) - already in customExercises")
                continue
            }

            try await newCollection.document(doc.documentID).setData(doc.data())
            migratedCount += 1
        }

        for doc in oldSnapshot.documents {
            try await doc.reference.delete()
        }

        Logger.info("Migrated \(migratedCount) exercises from exerciseLibrary to customExercises")
        return migratedCount
    }

    // MARK: - Fetch All User Data

    func fetchAllUserData() async throws -> (
        modules: [Module],
        workouts: [Workout],
        sessions: [Session],
        exercises: [ExerciseTemplate],
        programs: [Program],
        scheduledWorkouts: [ScheduledWorkout]
    ) {
        isSyncing = true
        defer { isSyncing = false }

        async let modules = fetchModules()
        async let workouts = fetchWorkouts()
        async let sessions = fetchSessions()
        async let exercises = fetchCustomExercises()
        async let programs = fetchPrograms()
        async let scheduledWorkouts = fetchScheduledWorkouts()

        return try await (modules, workouts, sessions, exercises, programs, scheduledWorkouts)
    }

    // MARK: - Module Encoding/Decoding

    private func encodeModule(_ module: Module) throws -> [String: Any] {
        try core.encode(module)
    }

    private func decodeModule(from data: [String: Any]) throws -> Module {
        try core.decode(Module.self, from: data)
    }

    // MARK: - Workout Encoding/Decoding

    private func encodeWorkout(_ workout: Workout) throws -> [String: Any] {
        try core.encode(workout)
    }

    private func decodeWorkout(from data: [String: Any]) throws -> Workout {
        try core.decode(Workout.self, from: data)
    }

    // MARK: - Session Encoding/Decoding

    private func encodeSession(_ session: Session) throws -> [String: Any] {
        try core.encode(session)
    }

    private func decodeSession(from data: [String: Any]) throws -> Session {
        try core.decode(Session.self, from: data)
    }

    // MARK: - Program Encoding/Decoding

    private func encodeProgram(_ program: Program) throws -> [String: Any] {
        try core.encode(program)
    }

    private func decodeProgram(from data: [String: Any]) throws -> Program {
        try core.decode(Program.self, from: data)
    }

    // MARK: - Scheduled Workout Encoding/Decoding

    private func encodeScheduledWorkout(_ scheduled: ScheduledWorkout) throws -> [String: Any] {
        var dict = try core.encode(scheduled)
        // Store programId as string for Firestore querying
        if let programId = scheduled.programId {
            dict["programId"] = programId.uuidString
        }
        return dict
    }

    private func decodeScheduledWorkout(from data: [String: Any]) throws -> ScheduledWorkout {
        try core.decode(ScheduledWorkout.self, from: data)
    }

    // MARK: - Exercise Template Encoding/Decoding

    func encodeExerciseTemplate(_ template: ExerciseTemplate) -> [String: Any] {
        [
            "id": template.id.uuidString,
            "name": template.name,
            "category": template.category.rawValue,
            "exerciseType": template.exerciseType.rawValue,
            "primaryMuscles": template.primaryMuscles.map { $0.rawValue },
            "secondaryMuscles": template.secondaryMuscles.map { $0.rawValue },
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    func decodeExerciseTemplate(from data: [String: Any]) -> ExerciseTemplate? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ExerciseCategory(rawValue: categoryRaw) else {
            return nil
        }

        let exerciseTypeRaw = data["exerciseType"] as? String ?? "strength"
        let exerciseType = ExerciseType(rawValue: exerciseTypeRaw) ?? .strength

        let primaryMuscles = (data["primaryMuscles"] as? [String])?.compactMap { MuscleGroup(rawValue: $0) } ?? []
        let secondaryMuscles = (data["secondaryMuscles"] as? [String])?.compactMap { MuscleGroup(rawValue: $0) } ?? []

        return ExerciseTemplate(
            id: id,
            name: name,
            category: category,
            exerciseType: exerciseType,
            primary: primaryMuscles,
            secondary: secondaryMuscles
        )
    }
}
