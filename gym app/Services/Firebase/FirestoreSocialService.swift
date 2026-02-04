//
//  FirestoreSocialService.swift
//  gym app
//
//  Handles social features: User profiles, friendships, username management, and user search.
//

import Foundation
import FirebaseFirestore

// MARK: - Social Service

/// Handles social features: profiles, friendships, usernames
@MainActor
class FirestoreSocialService: ObservableObject {
    static let shared = FirestoreSocialService()

    private let core = FirestoreCore.shared

    // MARK: - User Profile Operations

    func saveUserProfile(_ profile: UserProfile) async throws {
        let ref = try core.userCollection("profile").document("settings")
        let data = encodeUserProfile(profile)
        try await ref.setData(data, merge: true)
    }

    func fetchUserProfile() async throws -> UserProfile? {
        let doc = try await core.userCollection("profile").document("settings").getDocument()
        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    /// Fetch another user's profile by their Firebase user ID
    func fetchUserProfile(firebaseUserId: String) async throws -> UserProfile? {
        let doc = try await core.db.collection("users").document(firebaseUserId)
            .collection("profile").document("settings").getDocument()
        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    /// Fetch a user's public profile by their Firebase UID
    func fetchPublicProfile(userId: String) async throws -> UserProfile? {
        let doc = try await core.db.collection("users").document(userId)
            .collection("profile").document("settings").getDocument()
        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    // MARK: - Username Management

    /// Check if a username is available globally
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let normalized = UsernameValidator.normalize(username)
        let doc = try await core.db.collection("usernames").document(normalized).getDocument()
        return !doc.exists
    }

    /// Claim a username for the current user
    func claimUsername(_ username: String) async throws {
        guard let uid = core.userId else {
            throw FirestoreError.notAuthenticated
        }

        let normalized = UsernameValidator.normalize(username)

        guard try await isUsernameAvailable(normalized) else {
            throw ProfileError.usernameTaken
        }

        let usernameRef = core.db.collection("usernames").document(normalized)
        try await usernameRef.setData([
            "userId": uid,
            "claimedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Release the current user's username (for username changes)
    func releaseUsername(_ username: String) async throws {
        guard let uid = core.userId else {
            throw FirestoreError.notAuthenticated
        }

        let normalized = UsernameValidator.normalize(username)
        let usernameRef = core.db.collection("usernames").document(normalized)

        let doc = try await usernameRef.getDocument()
        if let data = doc.data(), data["userId"] as? String == uid {
            try await usernameRef.delete()
        }
    }

    /// Search for users by username prefix
    func searchUsersByUsername(prefix: String, limit: Int = 20) async throws -> [UserSearchResult] {
        guard !prefix.isEmpty else { return [] }

        let normalized = prefix.lowercased()
        let endPrefix = normalized + "\u{f8ff}"

        let snapshot = try await core.db.collection("usernames")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: normalized)
            .whereField(FieldPath.documentID(), isLessThan: endPrefix)
            .limit(to: limit)
            .getDocuments()

        var results: [UserSearchResult] = []

        for doc in snapshot.documents {
            guard let firebaseUserId = doc.data()["userId"] as? String else { continue }

            let profileDoc = try await core.db.collection("users").document(firebaseUserId)
                .collection("profile").document("settings").getDocument()

            if let data = profileDoc.data(),
               let profile = decodeUserProfile(from: data) {
                results.append(UserSearchResult(firebaseUserId: firebaseUserId, profile: profile))
            }
        }

        return results
    }

    // MARK: - Friendship Operations

    /// Save a friendship to Firestore (global collection)
    func saveFriendship(_ friendship: Friendship) async throws {
        let ref = core.db.collection("friendships").document(friendship.id.uuidString)
        let data = encodeFriendship(friendship)
        try await ref.setData(data, merge: true)
    }

    /// Delete a friendship from Firestore
    func deleteFriendship(id: UUID) async throws {
        try await core.db.collection("friendships").document(id.uuidString).delete()
    }

    /// Fetch all friendships involving a user
    func fetchFriendships(for userId: String) async throws -> [Friendship] {
        let requesterSnapshot = try await core.db.collection("friendships")
            .whereField("requesterId", isEqualTo: userId)
            .getDocuments()

        let addresseeSnapshot = try await core.db.collection("friendships")
            .whereField("addresseeId", isEqualTo: userId)
            .getDocuments()

        var friendships: [Friendship] = []

        for doc in requesterSnapshot.documents {
            if let friendship = decodeFriendship(from: doc.data()) {
                friendships.append(friendship)
            }
        }

        for doc in addresseeSnapshot.documents {
            if let friendship = decodeFriendship(from: doc.data()) {
                if !friendships.contains(where: { $0.id == friendship.id }) {
                    friendships.append(friendship)
                }
            }
        }

        return friendships
    }

    /// Listen to friendship changes in real-time
    func listenToFriendships(for userId: String, onChange: @escaping ([Friendship]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        var allFriendships: [UUID: Friendship] = [:]
        let lock = NSLock()

        let requesterListener = core.db.collection("friendships")
            .whereField("requesterId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToFriendships (requester)")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                lock.lock()
                allFriendships = allFriendships.filter { _, f in f.addresseeId == userId }
                for doc in documents {
                    if let friendship = self?.decodeFriendship(from: doc.data()) {
                        allFriendships[friendship.id] = friendship
                    }
                }
                let result = Array(allFriendships.values)
                lock.unlock()
                onChange(result)
            }

        let addresseeListener = core.db.collection("friendships")
            .whereField("addresseeId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToFriendships (addressee)")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                lock.lock()
                allFriendships = allFriendships.filter { _, f in f.requesterId == userId }
                for doc in documents {
                    if let friendship = self?.decodeFriendship(from: doc.data()) {
                        allFriendships[friendship.id] = friendship
                    }
                }
                let result = Array(allFriendships.values)
                lock.unlock()
                onChange(result)
            }

        return CompositeListenerRegistration(listeners: [requesterListener, addresseeListener])
    }

    // MARK: - User Profile Encoding/Decoding

    private func encodeUserProfile(_ profile: UserProfile) -> [String: Any] {
        var data: [String: Any] = [
            "id": profile.id.uuidString,
            "username": profile.username,
            "isPublic": profile.isPublic,
            "weightUnit": profile.weightUnit.rawValue,
            "distanceUnit": profile.distanceUnit.rawValue,
            "defaultRestTime": profile.defaultRestTime,
            "createdAt": profile.createdAt,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let displayName = profile.displayName {
            data["displayName"] = displayName
        }
        if let bio = profile.bio {
            data["bio"] = bio
        }
        if let profilePhotoURL = profile.profilePhotoURL {
            data["profilePhotoURL"] = profilePhotoURL
        }

        return data
    }

    func decodeUserProfile(from data: [String: Any]) -> UserProfile? {
        let username = data["username"] as? String ?? ""
        let weightUnit = (data["weightUnit"] as? String).flatMap { WeightUnit(rawValue: $0) } ?? .lbs
        let distanceUnit = (data["distanceUnit"] as? String).flatMap { DistanceUnit(rawValue: $0) } ?? .miles
        let defaultRestTime = data["defaultRestTime"] as? Int ?? 90

        let displayName = data["displayName"] as? String
        let bio = data["bio"] as? String
        let isPublic = data["isPublic"] as? Bool ?? false
        let profilePhotoURL = data["profilePhotoURL"] as? String

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else {
            createdAt = Date()
        }

        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else if let date = data["updatedAt"] as? Date {
            updatedAt = date
        } else {
            updatedAt = Date()
        }

        let id: UUID
        if let idString = data["id"] as? String, let parsedId = UUID(uuidString: idString) {
            id = parsedId
        } else {
            id = UUID()
        }

        return UserProfile(
            id: id,
            username: username,
            displayName: displayName,
            bio: bio,
            isPublic: isPublic,
            profilePhotoURL: profilePhotoURL,
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            defaultRestTime: defaultRestTime,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
    }

    // MARK: - Friendship Encoding/Decoding

    private func encodeFriendship(_ friendship: Friendship) -> [String: Any] {
        [
            "id": friendship.id.uuidString,
            "requesterId": friendship.requesterId,
            "addresseeId": friendship.addresseeId,
            "participantIds": [friendship.requesterId, friendship.addresseeId],
            "status": friendship.status.rawValue,
            "createdAt": Timestamp(date: friendship.createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func decodeFriendship(from data: [String: Any]) -> Friendship? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let requesterId = data["requesterId"] as? String,
              let addresseeId = data["addresseeId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = FriendshipStatus(rawValue: statusRaw) else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = Date()
        }

        return Friendship(
            id: id,
            requesterId: requesterId,
            addresseeId: addresseeId,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
    }
}
