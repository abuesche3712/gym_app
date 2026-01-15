//
//  FirebaseService.swift
//  gym app
//
//  Firebase Firestore service for cloud sync
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

    @Published var isSyncing = false
    @Published var lastError: Error?

    private var userId: String? {
        authService.uid
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
            try? decodeModule(from: doc.data())
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
            try? decodeWorkout(from: doc.data())
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
            try? decodeSession(from: doc.data())
        }
    }

    func deleteSession(_ sessionId: UUID) async throws {
        try await userRef().collection("sessions").document(sessionId.uuidString).delete()
    }

    // MARK: - Custom Exercise Library Operations

    func saveCustomExercise(_ template: ExerciseTemplate) async throws {
        let ref = try userRef().collection("exerciseLibrary").document(template.id.uuidString)
        let data = encodeExerciseTemplate(template)
        try await ref.setData(data, merge: true)
    }

    func fetchCustomExercises() async throws -> [ExerciseTemplate] {
        let snapshot = try await userRef().collection("exerciseLibrary").getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeExerciseTemplate(from: doc.data())
        }
    }

    func deleteCustomExercise(_ exerciseId: UUID) async throws {
        try await userRef().collection("exerciseLibrary").document(exerciseId.uuidString).delete()
    }

    // MARK: - Fetch All User Data

    func fetchAllUserData() async throws -> (modules: [Module], workouts: [Workout], sessions: [Session], exercises: [ExerciseTemplate]) {
        isSyncing = true
        defer { isSyncing = false }

        async let modules = fetchModules()
        async let workouts = fetchWorkouts()
        async let sessions = fetchSessions()
        async let exercises = fetchCustomExercises()

        return try await (modules, workouts, sessions, exercises)
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
        var mutableData = data

        // Handle Firestore Timestamp
        if let timestamp = mutableData["updatedAt"] as? Timestamp {
            mutableData["updatedAt"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }
        if let timestamp = mutableData["createdAt"] as? Timestamp {
            mutableData["createdAt"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }

        let jsonData = try JSONSerialization.data(withJSONObject: mutableData)
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
        var mutableData = data

        if let timestamp = mutableData["updatedAt"] as? Timestamp {
            mutableData["updatedAt"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }
        if let timestamp = mutableData["createdAt"] as? Timestamp {
            mutableData["createdAt"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }

        let jsonData = try JSONSerialization.data(withJSONObject: mutableData)
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
        var mutableData = data

        if let timestamp = mutableData["date"] as? Timestamp {
            mutableData["date"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }
        if let timestamp = mutableData["createdAt"] as? Timestamp {
            mutableData["createdAt"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
        }

        let jsonData = try JSONSerialization.data(withJSONObject: mutableData)
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
            "muscleGroupIds": Array(template.muscleGroupIds).map { $0.uuidString },
            "implementIds": Array(template.implementIds).map { $0.uuidString },
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

        let muscleGroupIds = Set((data["muscleGroupIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? [])
        let implementIds = Set((data["implementIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? [])

        return ExerciseTemplate(
            id: id,
            name: name,
            category: category,
            exerciseType: exerciseType,
            primary: primaryMuscles,
            secondary: secondaryMuscles,
            muscleGroupIds: muscleGroupIds,
            implementIds: implementIds
        )
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
