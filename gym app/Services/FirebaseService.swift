//
//  FirebaseService.swift
//  gym app
//
//  Firebase Firestore service for cloud sync
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Represents a document that failed to decode during fetch
struct DecodeFailure: Identifiable {
    let id: String  // Document ID
    let collection: String
    let error: Error
    let timestamp: Date

    var description: String {
        "\(collection)/\(id): \(error.localizedDescription)"
    }
}

@preconcurrency @MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

    @Published var isSyncing = false
    @Published var lastError: Error?
    @Published private(set) var decodeFailures: [DecodeFailure] = []

    /// Returns true if there are unresolved decode failures
    var hasDecodeFailures: Bool { !decodeFailures.isEmpty }

    /// Clears tracked decode failures (e.g., after user acknowledges them)
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

    private var userId: String? {
        authService.uid
    }

    // MARK: - Timestamp Conversion Helper

    /// Recursively converts all Firestore Timestamps to ISO8601 strings throughout a data structure
    private func convertTimestamps(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return ISO8601DateFormatter().string(from: timestamp.dateValue())
        } else if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = convertTimestamps(val)
            }
            return result
        } else if let array = value as? [Any] {
            return array.map { convertTimestamps($0) }
        } else {
            return value
        }
    }

    // MARK: - User Document Reference

    private func userRef() throws -> DocumentReference {
        guard let uid = userId else {
            throw FirestoreError.notAuthenticated
        }
        return db.collection("users").document(uid)
    }

    // MARK: - Module Operations

    func saveModule(_ module: Module) async throws {
        let ref = try userRef().collection("modules").document(module.id.uuidString)
        let data = try encodeModule(module)
        try await ref.setData(data, merge: true)
    }

    func fetchModules() async throws -> [Module] {
        let snapshot = try await userRef().collection("modules").getDocuments()
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
        try await userRef().collection("modules").document(moduleId.uuidString).delete()
    }

    // MARK: - Workout Operations

    func saveWorkout(_ workout: Workout) async throws {
        let ref = try userRef().collection("workouts").document(workout.id.uuidString)
        let data = try encodeWorkout(workout)
        try await ref.setData(data, merge: true)
    }

    func fetchWorkouts() async throws -> [Workout] {
        let snapshot = try await userRef().collection("workouts").getDocuments()
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
        try await userRef().collection("workouts").document(workoutId.uuidString).delete()
    }

    // MARK: - Session Operations

    func saveSession(_ session: Session) async throws {
        let ref = try userRef().collection("sessions").document(session.id.uuidString)
        let data = try encodeSession(session)
        try await ref.setData(data, merge: true)
    }

    func fetchSessions() async throws -> [Session] {
        let snapshot = try await userRef().collection("sessions").getDocuments()
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
        try await userRef().collection("sessions").document(sessionId.uuidString).delete()
    }

    /// Incremental update for a single set during active workout
    /// This allows syncing individual sets without re-uploading the entire session
    func updateSessionSet(sessionId: UUID, exerciseId: UUID, set: SetData) async throws {
        let ref = try userRef().collection("sessions").document(sessionId.uuidString)
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

    // MARK: - Custom Exercise Library Operations

    func saveCustomExercise(_ template: ExerciseTemplate) async throws {
        let ref = try userRef().collection("customExercises").document(template.id.uuidString)
        let data = encodeExerciseTemplate(template)
        try await ref.setData(data, merge: true)
    }

    func fetchCustomExercises() async throws -> [ExerciseTemplate] {
        let snapshot = try await userRef().collection("customExercises").getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeExerciseTemplate(from: doc.data())
        }
    }

    func deleteCustomExercise(_ exerciseId: UUID) async throws {
        try await userRef().collection("customExercises").document(exerciseId.uuidString).delete()
    }

    // MARK: - Program Operations

    func saveProgram(_ program: Program) async throws {
        let ref = try userRef().collection("programs").document(program.id.uuidString)
        let data = try encodeProgram(program)
        try await ref.setData(data, merge: true)
    }

    func fetchPrograms() async throws -> [Program] {
        let snapshot = try await userRef().collection("programs").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try decodeProgram(from: doc.data())
            } catch {
                Logger.error(error, context: "Failed to decode program \(doc.documentID)")
                return nil
            }
        }
    }

    func deleteProgram(_ programId: UUID) async throws {
        try await userRef().collection("programs").document(programId.uuidString).delete()
    }

    // MARK: - Scheduled Workouts Operations

    func saveScheduledWorkout(_ scheduled: ScheduledWorkout) async throws {
        let ref = try userRef().collection("scheduledWorkouts").document(scheduled.id.uuidString)
        let data = try encodeScheduledWorkout(scheduled)
        try await ref.setData(data, merge: true)
    }

    func fetchScheduledWorkouts() async throws -> [ScheduledWorkout] {
        let snapshot = try await userRef().collection("scheduledWorkouts").getDocuments()
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
        try await userRef().collection("scheduledWorkouts").document(scheduledId.uuidString).delete()
    }

    func deleteScheduledWorkoutsForProgram(_ programId: UUID) async throws {
        let snapshot = try await userRef().collection("scheduledWorkouts")
            .whereField("programId", isEqualTo: programId.uuidString)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - User Profile Operations

    func saveUserProfile(_ profile: UserProfile) async throws {
        let ref = try userRef().collection("profile").document("settings")
        let data = encodeUserProfile(profile)
        try await ref.setData(data, merge: true)
    }

    func fetchUserProfile() async throws -> UserProfile? {
        let doc = try await userRef().collection("profile").document("settings").getDocument()
        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    // MARK: - Fetch All User Data

    func fetchAllUserData() async throws -> (
        modules: [Module],
        workouts: [Workout],
        sessions: [Session],
        exercises: [ExerciseTemplate],
        programs: [Program],
        scheduledWorkouts: [ScheduledWorkout],
        profile: UserProfile?
    ) {
        isSyncing = true
        defer { isSyncing = false }

        async let modules = fetchModules()
        async let workouts = fetchWorkouts()
        async let sessions = fetchSessions()
        async let exercises = fetchCustomExercises()
        async let programs = fetchPrograms()
        async let scheduledWorkouts = fetchScheduledWorkouts()
        async let profile = fetchUserProfile()

        return try await (modules, workouts, sessions, exercises, programs, scheduledWorkouts, profile)
    }

    // MARK: - Module Encoding/Decoding

    private func encodeModule(_ module: Module) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(module)
        guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        var data = dict
        data["updatedAt"] = FieldValue.serverTimestamp()
        return data
    }

    private func decodeModule(from data: [String: Any]) throws -> Module {
        // Recursively convert all Firestore Timestamps to ISO8601 strings
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Module.self, from: jsonData)
    }

    // MARK: - Workout Encoding/Decoding

    private func encodeWorkout(_ workout: Workout) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(workout)
        guard var dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        dict["updatedAt"] = FieldValue.serverTimestamp()
        return dict
    }

    private func decodeWorkout(from data: [String: Any]) throws -> Workout {
        // Recursively convert all Firestore Timestamps to ISO8601 strings
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Workout.self, from: jsonData)
    }

    // MARK: - Session Encoding/Decoding

    private func encodeSession(_ session: Session) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(session)
        guard var dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        dict["updatedAt"] = FieldValue.serverTimestamp()
        return dict
    }

    private func decodeSession(from data: [String: Any]) throws -> Session {
        // Recursively convert all Firestore Timestamps to ISO8601 strings
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Session.self, from: jsonData)
    }

    // MARK: - Exercise Template Encoding/Decoding

    private func encodeExerciseTemplate(_ template: ExerciseTemplate) -> [String: Any] {
        return [
            "id": template.id.uuidString,
            "name": template.name,
            "category": template.category.rawValue,
            "exerciseType": template.exerciseType.rawValue,
            "primaryMuscles": template.primaryMuscles.map { $0.rawValue },
            "secondaryMuscles": template.secondaryMuscles.map { $0.rawValue },
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func decodeExerciseTemplate(from data: [String: Any]) -> ExerciseTemplate? {
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

    // MARK: - Program Encoding/Decoding

    private func encodeProgram(_ program: Program) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(program)
        guard var dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        dict["updatedAt"] = FieldValue.serverTimestamp()
        return dict
    }

    private func decodeProgram(from data: [String: Any]) throws -> Program {
        // Recursively convert all Firestore Timestamps to ISO8601 strings
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Program.self, from: jsonData)
    }

    // MARK: - Scheduled Workout Encoding/Decoding

    private func encodeScheduledWorkout(_ scheduled: ScheduledWorkout) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(scheduled)
        guard var dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        // Store programId as string for Firestore querying
        if let programId = scheduled.programId {
            dict["programId"] = programId.uuidString
        }

        return dict
    }

    private func decodeScheduledWorkout(from data: [String: Any]) throws -> ScheduledWorkout {
        // Recursively convert all Firestore Timestamps to ISO8601 strings
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScheduledWorkout.self, from: jsonData)
    }

    // MARK: - User Profile Encoding/Decoding

    private func encodeUserProfile(_ profile: UserProfile) -> [String: Any] {
        return [
            "weightUnit": profile.weightUnit.rawValue,
            "distanceUnit": profile.distanceUnit.rawValue,
            "defaultRestTime": profile.defaultRestTime,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func decodeUserProfile(from data: [String: Any]) -> UserProfile? {
        guard let weightUnitRaw = data["weightUnit"] as? String,
              let weightUnit = WeightUnit(rawValue: weightUnitRaw),
              let distanceUnitRaw = data["distanceUnit"] as? String,
              let distanceUnit = DistanceUnit(rawValue: distanceUnitRaw) else {
            return nil
        }

        let defaultRestTime = data["defaultRestTime"] as? Int ?? 90

        return UserProfile(
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            defaultRestTime: defaultRestTime
        )
    }

    // MARK: - Library Operations (Read-Only from Cloud)

    /// Fetch exercise library templates from cloud (root-level, read-only)
    func fetchExerciseLibrary() async throws -> [ExerciseTemplate] {
        let snapshot = try await db.collection("libraries").document("exerciseLibrary").collection("exercises").getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeExerciseTemplate(from: doc.data())
        }
    }

    /// Fetch equipment library from cloud (root-level, read-only)
    func fetchEquipmentLibrary() async throws -> [[String: Any]] {
        let snapshot = try await db.collection("libraries").document("equipmentLibrary").collection("equipment").getDocuments()
        return snapshot.documents.map { $0.data() }
    }

    /// Fetch progression schemes from cloud (root-level, read-only)
    func fetchProgressionSchemes() async throws -> [[String: Any]] {
        let snapshot = try await db.collection("libraries").document("progressionSchemes").collection("schemes").getDocuments()
        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Conflict Resolution

    /// Resolution decision for sync conflicts
    enum ConflictResolution {
        case useCloud       // Cloud data is newer, use it
        case useLocal       // Local data is newer, push it
        case noConflict     // Data doesn't exist on one side
    }

    /// Determine conflict resolution by comparing timestamps
    /// Rule: cloud wins if cloudUpdatedAt > localUpdatedAt, local wins otherwise
    func resolveConflict(localUpdatedAt: Date, cloudUpdatedAt: Date?) -> ConflictResolution {
        guard let cloudDate = cloudUpdatedAt else {
            // No cloud data, push local
            return .useLocal
        }

        if cloudDate > localUpdatedAt {
            return .useCloud
        } else {
            return .useLocal
        }
    }

    /// Fetch cloud timestamp for a specific module
    func fetchModuleTimestamp(_ moduleId: UUID) async throws -> Date? {
        let doc = try await userRef().collection("modules").document(moduleId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific workout
    func fetchWorkoutTimestamp(_ workoutId: UUID) async throws -> Date? {
        let doc = try await userRef().collection("workouts").document(workoutId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific session
    func fetchSessionTimestamp(_ sessionId: UUID) async throws -> Date? {
        let doc = try await userRef().collection("sessions").document(sessionId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a specific program
    func fetchProgramTimestamp(_ programId: UUID) async throws -> Date? {
        let doc = try await userRef().collection("programs").document(programId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    /// Fetch cloud timestamp for a custom exercise
    func fetchCustomExerciseTimestamp(_ exerciseId: UUID) async throws -> Date? {
        let doc = try await userRef().collection("customExercises").document(exerciseId.uuidString).getDocument()
        guard let data = doc.data(),
              let timestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    // MARK: - Conflict-Aware Save Methods

    /// Save module with conflict resolution
    /// Returns true if saved to cloud, false if cloud version is newer (caller should update local)
    func saveModuleWithConflictCheck(_ module: Module, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchModuleTimestamp(module.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await saveModule(module)
            return true
        case .useCloud:
            // Caller should fetch and use cloud data
            return false
        }
    }

    /// Save workout with conflict resolution
    func saveWorkoutWithConflictCheck(_ workout: Workout, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchWorkoutTimestamp(workout.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await saveWorkout(workout)
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
            try await saveSession(session)
            return true
        case .useCloud:
            return false
        }
    }

    /// Save program with conflict resolution
    func saveProgram(_ program: Program, localUpdatedAt: Date) async throws -> Bool {
        let cloudTimestamp = try await fetchProgramTimestamp(program.id)
        let resolution = resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudTimestamp)

        switch resolution {
        case .useLocal, .noConflict:
            try await saveProgram(program)
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
        let snapshot = try await userRef().collection("modules").getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Module>? in
            guard let module = try? decodeModule(from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: module, updatedAt: timestamp)
        }
    }

    /// Fetch workouts with their cloud timestamps
    func fetchWorkoutsWithTimestamps() async throws -> [CloudEntity<Workout>] {
        let snapshot = try await userRef().collection("workouts").getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Workout>? in
            guard let workout = try? decodeWorkout(from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: workout, updatedAt: timestamp)
        }
    }

    /// Fetch sessions with their cloud timestamps
    func fetchSessionsWithTimestamps() async throws -> [CloudEntity<Session>] {
        let snapshot = try await userRef().collection("sessions").getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Session>? in
            guard let session = try? decodeSession(from: doc.data()) else { return nil }
            let timestamp = (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
            return CloudEntity(entity: session, updatedAt: timestamp)
        }
    }

    /// Fetch programs with their cloud timestamps
    func fetchProgramsWithTimestamps() async throws -> [CloudEntity<Program>] {
        let snapshot = try await userRef().collection("programs").getDocuments()
        return snapshot.documents.compactMap { doc -> CloudEntity<Program>? in
            guard let program = try? decodeProgram(from: doc.data()) else { return nil }
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
    /// Returns items where cloud is newer (caller should update local storage)
    func syncModulesBidirectional(
        localModules: [(module: Module, localUpdatedAt: Date, syncedAt: Date?)]
    ) async throws -> SyncResult<Module> {
        var pushedCount = 0
        var cloudNewerItems: [Module] = []
        var errors: [Error] = []

        // Fetch all cloud modules with timestamps
        let cloudModules = try await fetchModulesWithTimestamps()
        let cloudModuleMap = Dictionary(uniqueKeysWithValues: cloudModules.map { ($0.entity.id, $0) })

        // Process each local module
        for local in localModules {
            do {
                let cloudEntity = cloudModuleMap[local.module.id]

                if let cloud = cloudEntity {
                    // Both exist - check conflict
                    let resolution = resolveConflict(
                        localUpdatedAt: local.localUpdatedAt,
                        cloudUpdatedAt: cloud.updatedAt
                    )

                    switch resolution {
                    case .useLocal:
                        try await saveModule(local.module)
                        pushedCount += 1
                    case .useCloud:
                        cloudNewerItems.append(cloud.entity)
                    case .noConflict:
                        try await saveModule(local.module)
                        pushedCount += 1
                    }
                } else {
                    // Only local exists - push to cloud
                    try await saveModule(local.module)
                    pushedCount += 1
                }
            } catch {
                errors.append(error)
            }
        }

        // Find cloud-only modules (new from cloud)
        let localIds = Set(localModules.map { $0.module.id })
        for cloud in cloudModules where !localIds.contains(cloud.entity.id) {
            cloudNewerItems.append(cloud.entity)
        }

        return SyncResult(pushedCount: pushedCount, cloudNewerItems: cloudNewerItems, errors: errors)
    }

    // MARK: - Deletion Records Sync

    /// Save a deletion record to Firebase
    func saveDeletionRecord(_ record: DeletionRecord) async throws {
        try await userRef().collection("deletions").document(record.id.uuidString).setData(record.firestoreData)
    }

    /// Save multiple deletion records to Firebase
    func saveDeletionRecords(_ records: [DeletionRecord]) async throws {
        let batch = db.batch()
        for record in records {
            let docRef = try userRef().collection("deletions").document(record.id.uuidString)
            batch.setData(record.firestoreData, forDocument: docRef)
        }
        try await batch.commit()
    }

    /// Fetch all deletion records from Firebase
    func fetchDeletionRecords() async throws -> [DeletionRecord] {
        let snapshot = try await userRef().collection("deletions").getDocuments()
        return snapshot.documents.compactMap { doc -> DeletionRecord? in
            DeletionRecord(from: doc.data())
        }
    }

    /// Fetch deletion records newer than a given date
    func fetchDeletionRecords(since date: Date) async throws -> [DeletionRecord] {
        let snapshot = try await userRef()
            .collection("deletions")
            .whereField("deletedAt", isGreaterThan: date)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> DeletionRecord? in
            DeletionRecord(from: doc.data())
        }
    }

    /// Delete a deletion record from Firebase (for cleanup)
    func deleteDeletionRecord(_ recordId: UUID) async throws {
        try await userRef().collection("deletions").document(recordId.uuidString).delete()
    }

    /// Delete multiple deletion records from Firebase (for batch cleanup)
    func deleteDeletionRecords(_ recordIds: [UUID]) async throws {
        let batch = db.batch()
        for id in recordIds {
            let docRef = try userRef().collection("deletions").document(id.uuidString)
            batch.deleteDocument(docRef)
        }
        try await batch.commit()
    }

    /// Cleanup old deletion records from Firebase (older than retention days)
    func cleanupOldDeletionRecords(olderThan date: Date) async throws -> Int {
        let snapshot = try await userRef()
            .collection("deletions")
            .whereField("deletedAt", isLessThan: date)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return 0 }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        return snapshot.documents.count
    }
}

// MARK: - Firestore Errors

enum FirestoreError: LocalizedError {
    case notAuthenticated
    case encodingFailed
    case decodingFailed
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in to sync data."
        case .encodingFailed:
            return "Failed to encode data for sync."
        case .decodingFailed:
            return "Failed to decode data from cloud."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
