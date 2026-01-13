//
//  FirebaseService.swift
//  gym app
//
//  Firebase Firestore service for cloud sync
//  NOTE: Firebase disabled for now - local-only mode
//

import Foundation

// Firebase integration disabled until dependency issues resolved
// When ready to enable:
// 1. Uncomment Firebase imports
// 2. Add Firebase to project dependencies
// 3. Uncomment implementation code

// import FirebaseFirestore
// import FirebaseAuth

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published var isAuthenticated = false
    @Published var isSyncing = false
    @Published var lastError: Error?
    @Published var isEnabled = false  // Firebase disabled

    private var userId: String?

    init() {
        // Firebase disabled - no auth check
    }

    // MARK: - Authentication (Stubbed)

    func signInAnonymously() async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func signIn(email: String, password: String) async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func signUp(email: String, password: String) async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func signOut() throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    // MARK: - Modules (Stubbed)

    func syncModules(_ modules: [Module]) async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func fetchModules() async throws -> [Module] {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        return []
    }

    // MARK: - Workouts (Stubbed)

    func syncWorkouts(_ workouts: [Workout]) async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func fetchWorkouts() async throws -> [Workout] {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        return []
    }

    // MARK: - Sessions (Stubbed)

    func syncSessions(_ sessions: [Session]) async throws {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        // Firebase implementation would go here
    }

    func fetchSessions() async throws -> [Session] {
        guard isEnabled else {
            throw FirebaseError.disabled
        }
        return []
    }
}

// MARK: - Firebase Errors

enum FirebaseError: LocalizedError {
    case disabled
    case notAuthenticated
    case encodingFailed
    case decodingFailed
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Cloud sync is currently disabled. Data is stored locally."
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .encodingFailed:
            return "Failed to encode data for sync."
        case .decodingFailed:
            return "Failed to decode data from cloud."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
