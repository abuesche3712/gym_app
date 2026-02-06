//
//  FirestoreCore.swift
//  gym app
//
//  Shared Firestore utilities, references, and error types.
//  Used by all Firebase service modules.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Core Utilities

/// Shared Firestore utilities and references
@MainActor
class FirestoreCore {
    static let shared = FirestoreCore()

    let db = Firestore.firestore()

    private var authService: AuthService { AuthService.shared }

    var userId: String? {
        authService.uid
    }

    var isAuthenticated: Bool {
        userId != nil
    }

    // MARK: - User Document References

    /// Get reference to current user's document
    func userRef() throws -> DocumentReference {
        guard let uid = userId else {
            throw FirestoreError.notAuthenticated
        }
        return db.collection(FirestoreCollections.users).document(uid)
    }

    /// Get reference to a subcollection under current user
    func userCollection(_ name: String) throws -> CollectionReference {
        try userRef().collection(name)
    }

    // MARK: - Timestamp Conversion

    /// Recursively converts all Firestore Timestamps to ISO8601 strings throughout a data structure
    func convertTimestamps(_ value: Any) -> Any {
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

    // MARK: - Generic Encoding/Decoding

    /// Encode a Codable value to Firestore-compatible dictionary
    func encode<T: Encodable>(_ value: T, addServerTimestamp: Bool = true) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(value)
        guard var dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FirestoreError.encodingFailed
        }

        if addServerTimestamp {
            dict["updatedAt"] = FieldValue.serverTimestamp()
        }
        return dict
    }

    /// Decode a Firestore document to a Codable type
    func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]) throws -> T {
        guard let convertedData = convertTimestamps(data) as? [String: Any] else {
            throw FirestoreError.decodingFailed
        }

        let jsonData = try JSONSerialization.data(withJSONObject: convertedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: jsonData)
    }
}

// MARK: - Collection Constants

/// Centralized Firestore collection name constants
enum FirestoreCollections {
    // Top-level collections
    static let users = "users"
    static let usernames = "usernames"
    static let friendships = "friendships"
    static let posts = "posts"
    static let conversations = "conversations"
    static let reports = "reports"
    static let libraries = "libraries"
    static let presence = "presence"

    // User-scoped subcollections (under users/{uid}/)
    static let profile = "profile"
    static let modules = "modules"
    static let workouts = "workouts"
    static let sessions = "sessions"
    static let programs = "programs"
    static let scheduledWorkouts = "scheduledWorkouts"
    static let customExercises = "customExercises"
    static let exerciseLibrary = "exerciseLibrary"
    static let deletions = "deletions"
    static let activities = "activities"

    // Nested subcollections
    static let liveSets = "livesets"
    static let likes = "likes"
    static let comments = "comments"
    static let messages = "messages"
    static let typing = "typing"

    // Library subcollections
    static let exercises = "exercises"
    static let equipment = "equipment"
    static let schemes = "schemes"

    // Library document IDs
    static let exerciseLibraryDoc = "exerciseLibrary"
    static let equipmentLibraryDoc = "equipmentLibrary"
    static let progressionSchemesDoc = "progressionSchemes"

    // Profile document ID
    static let profileSettings = "settings"
}

// MARK: - Supporting Types

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

/// Search result pairing a user profile with their Firebase UID
struct UserSearchResult: Identifiable {
    let firebaseUserId: String
    let profile: UserProfile

    var id: String { firebaseUserId }
}

// MARK: - Error Types

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

enum ProfileError: LocalizedError {
    case usernameTaken
    case invalidUsername(UsernameError)
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "This username is already taken"
        case .invalidUsername(let error):
            return error.localizedDescription
        case .profileNotFound:
            return "Profile not found"
        }
    }
}

// MARK: - Composite Listener Registration

/// Allows managing multiple Firestore listeners as one
class CompositeListenerRegistration: NSObject, ListenerRegistration {
    private var listeners: [ListenerRegistration]

    init(listeners: [ListenerRegistration]) {
        self.listeners = listeners
        super.init()
    }

    func remove() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
}
