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

/// Search result pairing a user profile with their Firebase UID
struct UserSearchResult: Identifiable {
    let firebaseUserId: String
    let profile: UserProfile

    var id: String { firebaseUserId }
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

    // MARK: - Migration: exerciseLibrary → customExercises

    /// One-time migration from legacy per-user exerciseLibrary to customExercises
    /// Returns the number of exercises migrated
    @discardableResult
    func migrateExerciseLibraryToCustomExercises() async throws -> Int {
        let userReference = try userRef()
        let oldCollection = userReference.collection("exerciseLibrary")
        let newCollection = userReference.collection("customExercises")

        // Fetch from old location
        let oldSnapshot = try await oldCollection.getDocuments()
        guard !oldSnapshot.documents.isEmpty else {
            Logger.debug("No exercises to migrate from exerciseLibrary")
            return 0
        }

        // Fetch existing in new location to avoid duplicates
        let existingSnapshot = try await newCollection.getDocuments()
        let existingIds = Set(existingSnapshot.documents.map { $0.documentID })

        var migratedCount = 0
        for doc in oldSnapshot.documents {
            // Skip if already exists in customExercises
            if existingIds.contains(doc.documentID) {
                Logger.debug("Skipping \(doc.documentID) - already in customExercises")
                continue
            }

            // Copy to new location
            try await newCollection.document(doc.documentID).setData(doc.data())
            migratedCount += 1
        }

        // Delete old collection after successful migration
        for doc in oldSnapshot.documents {
            try await doc.reference.delete()
        }

        Logger.info("Migrated \(migratedCount) exercises from exerciseLibrary to customExercises")
        return migratedCount
    }

    // MARK: - Program Operations

    func saveProgram(_ program: Program) async throws {
        let ref = try userRef().collection("programs").document(program.id.uuidString)
        let data = try encodeProgram(program)
        try await ref.setData(data, merge: true)
    }

    func fetchPrograms() async throws -> [Program] {
        let snapshot = try await userRef().collection("programs").getDocuments()
        Logger.debug("fetchPrograms: Found \(snapshot.documents.count) program documents in Firebase")

        return snapshot.documents.compactMap { doc in
            do {
                let program = try decodeProgram(from: doc.data())
                Logger.debug("fetchPrograms: Successfully decoded program '\(program.name)' (id: \(program.id))")
                return program
            } catch {
                // Log detailed error info to help diagnose
                Logger.error(error, context: "Failed to decode program \(doc.documentID)")
                Logger.debug("fetchPrograms: Document keys: \(doc.data().keys.sorted().joined(separator: ", "))")

                // Log specific field values to identify mismatches
                let data = doc.data()
                Logger.debug("fetchPrograms: Raw field check - id: \(data["id"] ?? "nil"), name: \(data["name"] ?? "nil")")
                Logger.debug("fetchPrograms: Raw field check - createdAt: \(data["createdAt"] ?? "nil"), created: \(data["created"] ?? "nil")")
                Logger.debug("fetchPrograms: Raw field check - durationWeeks: \(data["durationWeeks"] ?? "nil"), duration: \(data["duration"] ?? "nil")")
                Logger.debug("fetchPrograms: Decode error details: \(String(describing: error))")
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

    /// Fetch another user's profile by their Firebase user ID
    func fetchUserProfile(firebaseUserId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(firebaseUserId).collection("profile").document("settings").getDocument()
        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    /// Check if a username is available globally
    /// Uses a global usernames collection for uniqueness enforcement
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let normalized = UsernameValidator.normalize(username)
        let doc = try await db.collection("usernames").document(normalized).getDocument()
        return !doc.exists
    }

    /// Claim a username for the current user
    /// This creates an entry in the global usernames collection
    func claimUsername(_ username: String) async throws {
        guard let uid = userId else {
            throw FirestoreError.notAuthenticated
        }

        let normalized = UsernameValidator.normalize(username)

        // First check if username is available
        guard try await isUsernameAvailable(normalized) else {
            throw ProfileError.usernameTaken
        }

        // Claim the username atomically
        let usernameRef = db.collection("usernames").document(normalized)
        try await usernameRef.setData([
            "userId": uid,
            "claimedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Release the current user's username (for username changes)
    func releaseUsername(_ username: String) async throws {
        guard let uid = userId else {
            throw FirestoreError.notAuthenticated
        }

        let normalized = UsernameValidator.normalize(username)
        let usernameRef = db.collection("usernames").document(normalized)

        // Only delete if owned by current user
        let doc = try await usernameRef.getDocument()
        if let data = doc.data(), data["userId"] as? String == uid {
            try await usernameRef.delete()
        }
    }

    // MARK: - Friendship Operations

    /// Save a friendship to Firestore (global collection)
    func saveFriendship(_ friendship: Friendship) async throws {
        let ref = db.collection("friendships").document(friendship.id.uuidString)
        let data = encodeFriendship(friendship)
        try await ref.setData(data, merge: true)
    }

    /// Delete a friendship from Firestore
    func deleteFriendship(id: UUID) async throws {
        try await db.collection("friendships").document(id.uuidString).delete()
    }

    /// Fetch all friendships involving the current user
    func fetchFriendships(for userId: String) async throws -> [Friendship] {
        // Query where user is requester
        let requesterSnapshot = try await db.collection("friendships")
            .whereField("requesterId", isEqualTo: userId)
            .getDocuments()

        // Query where user is addressee
        let addresseeSnapshot = try await db.collection("friendships")
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
                // Avoid duplicates
                if !friendships.contains(where: { $0.id == friendship.id }) {
                    friendships.append(friendship)
                }
            }
        }

        return friendships
    }

    /// Listen to friendship changes in real-time
    func listenToFriendships(for userId: String, onChange: @escaping ([Friendship]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        // We need two listeners - one for each direction
        var allFriendships: [UUID: Friendship] = [:]
        let lock = NSLock()

        let requesterListener = db.collection("friendships")
            .whereField("requesterId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToFriendships (requester)")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                lock.lock()
                // Remove old requester friendships
                allFriendships = allFriendships.filter { _, f in f.addresseeId == userId }
                // Add new ones
                for doc in documents {
                    if let friendship = self.decodeFriendship(from: doc.data()) {
                        allFriendships[friendship.id] = friendship
                    }
                }
                let result = Array(allFriendships.values)
                lock.unlock()
                onChange(result)
            }

        let addresseeListener = db.collection("friendships")
            .whereField("addresseeId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToFriendships (addressee)")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                lock.lock()
                // Remove old addressee friendships
                allFriendships = allFriendships.filter { _, f in f.requesterId == userId }
                // Add new ones
                for doc in documents {
                    if let friendship = self.decodeFriendship(from: doc.data()) {
                        allFriendships[friendship.id] = friendship
                    }
                }
                let result = Array(allFriendships.values)
                lock.unlock()
                onChange(result)
            }

        // Return a composite listener that removes both
        return CompositeListenerRegistration(listeners: [requesterListener, addresseeListener])
    }

    /// Search for users by username prefix
    func searchUsersByUsername(prefix: String, limit: Int = 20) async throws -> [UserSearchResult] {
        guard !prefix.isEmpty else { return [] }

        let normalized = prefix.lowercased()
        let endPrefix = normalized + "\u{f8ff}" // Unicode character after all normal chars

        let snapshot = try await db.collection("usernames")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: normalized)
            .whereField(FieldPath.documentID(), isLessThan: endPrefix)
            .limit(to: limit)
            .getDocuments()

        var results: [UserSearchResult] = []

        for doc in snapshot.documents {
            guard let firebaseUserId = doc.data()["userId"] as? String else { continue }

            // Fetch the user's profile
            let profileDoc = try await db.collection("users").document(firebaseUserId)
                .collection("profile").document("settings").getDocument()

            if let data = profileDoc.data(),
               let profile = decodeUserProfile(from: data) {
                results.append(UserSearchResult(firebaseUserId: firebaseUserId, profile: profile))
            }
        }

        return results
    }

    /// Fetch a user's public profile by their Firebase UID
    func fetchPublicProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(userId)
            .collection("profile").document("settings").getDocument()

        guard let data = doc.data() else { return nil }
        return decodeUserProfile(from: data)
    }

    // MARK: - Friendship Encoding/Decoding

    private func encodeFriendship(_ friendship: Friendship) -> [String: Any] {
        [
            "id": friendship.id.uuidString,
            "requesterId": friendship.requesterId,
            "addresseeId": friendship.addresseeId,
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

    // MARK: - Conversation Operations

    /// Save a conversation to Firestore
    func saveConversation(_ conversation: Conversation) async throws {
        let ref = db.collection("conversations").document(conversation.id.uuidString)
        let data = encodeConversation(conversation)
        try await ref.setData(data, merge: true)
    }

    /// Fetch conversations for a user
    func fetchConversations(for userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            decodeConversation(from: doc.data())
        }
    }

    /// Listen to conversation changes in real-time
    func listenToConversations(for userId: String, onChange: @escaping ([Conversation]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToConversations")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let conversations = documents.compactMap { doc in
                    self.decodeConversation(from: doc.data())
                }
                onChange(conversations)
            }
    }

    /// Delete a conversation
    func deleteConversation(id: UUID) async throws {
        try await db.collection("conversations").document(id.uuidString).delete()
    }

    // MARK: - Message Operations

    /// Save a message to Firestore
    func saveMessage(_ message: Message) async throws {
        let ref = db.collection("conversations")
            .document(message.conversationId.uuidString)
            .collection("messages")
            .document(message.id.uuidString)
        let data = encodeMessage(message)
        try await ref.setData(data, merge: true)
    }

    /// Fetch messages for a conversation with pagination
    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [Message] {
        var query = db.collection("conversations")
            .document(conversationId.uuidString)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let beforeDate = before {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
        }

        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { doc in
            self.decodeMessage(from: doc.data(), conversationId: conversationId)
        }
    }

    /// Listen to messages in real-time
    func listenToMessages(conversationId: UUID, limit: Int = 100, onChange: @escaping ([Message]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        db.collection("conversations")
            .document(conversationId.uuidString)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToMessages")
                    onError?(error)
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let messages = documents.compactMap { doc in
                    self.decodeMessage(from: doc.data(), conversationId: conversationId)
                }
                onChange(messages)
            }
    }

    /// Mark a message as read
    func markMessageRead(conversationId: UUID, messageId: UUID, at date: Date = Date()) async throws {
        let ref = db.collection("conversations")
            .document(conversationId.uuidString)
            .collection("messages")
            .document(messageId.uuidString)
        try await ref.updateData(["readAt": Timestamp(date: date)])
    }

    // MARK: - Conversation Encoding/Decoding

    private func encodeConversation(_ conversation: Conversation) -> [String: Any] {
        var data: [String: Any] = [
            "id": conversation.id.uuidString,
            "participantIds": conversation.participantIds,
            "createdAt": Timestamp(date: conversation.createdAt)
        ]

        if let lastMessageAt = conversation.lastMessageAt {
            data["lastMessageAt"] = Timestamp(date: lastMessageAt)
        }
        if let preview = conversation.lastMessagePreview {
            data["lastMessagePreview"] = preview
        }

        return data
    }

    private func decodeConversation(from data: [String: Any]) -> Conversation? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let participantIds = data["participantIds"] as? [String] else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let lastMessageAt: Date?
        if let timestamp = data["lastMessageAt"] as? Timestamp {
            lastMessageAt = timestamp.dateValue()
        } else {
            lastMessageAt = nil
        }

        let lastMessagePreview = data["lastMessagePreview"] as? String

        return Conversation(
            id: id,
            participantIds: participantIds,
            createdAt: createdAt,
            lastMessageAt: lastMessageAt,
            lastMessagePreview: lastMessagePreview,
            syncStatus: .synced
        )
    }

    // MARK: - Message Encoding/Decoding

    private func encodeMessage(_ message: Message) -> [String: Any] {
        var data: [String: Any] = [
            "id": message.id.uuidString,
            "senderId": message.senderId,
            "createdAt": Timestamp(date: message.createdAt)
        ]

        // Encode content as JSON data
        if let contentData = try? JSONEncoder().encode(message.content),
           let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            data["content"] = contentDict
        }

        if let readAt = message.readAt {
            data["readAt"] = Timestamp(date: readAt)
        }

        return data
    }

    private func decodeMessage(from data: [String: Any], conversationId: UUID) -> Message? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let senderId = data["senderId"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let readAt: Date?
        if let timestamp = data["readAt"] as? Timestamp {
            readAt = timestamp.dateValue()
        } else {
            readAt = nil
        }

        // Decode content
        let content: MessageContent
        if let contentDict = data["content"] as? [String: Any],
           let contentData = try? JSONSerialization.data(withJSONObject: contentDict),
           let decoded = try? JSONDecoder().decode(MessageContent.self, from: contentData) {
            content = decoded
        } else {
            content = .text("")
        }

        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: createdAt,
            readAt: readAt,
            syncStatus: .synced
        )
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

        return data
    }

    private func decodeUserProfile(from data: [String: Any]) -> UserProfile? {
        // Username is required for new profiles, but optional for legacy migration
        let username = data["username"] as? String ?? ""

        // Weight and distance units with defaults
        let weightUnit = (data["weightUnit"] as? String).flatMap { WeightUnit(rawValue: $0) } ?? .lbs
        let distanceUnit = (data["distanceUnit"] as? String).flatMap { DistanceUnit(rawValue: $0) } ?? .miles
        let defaultRestTime = data["defaultRestTime"] as? Int ?? 90

        // Social fields
        let displayName = data["displayName"] as? String
        let bio = data["bio"] as? String
        let isPublic = data["isPublic"] as? Bool ?? false

        // Timestamps
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

        // ID with fallback to new UUID for migration
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
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            defaultRestTime: defaultRestTime,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
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

    // MARK: - Post Operations

    /// Save a post to the global posts collection (public feed)
    func savePost(_ post: Post) async throws {
        let ref = db.collection("posts").document(post.id.uuidString)
        let data = encodePost(post)
        try await ref.setData(data, merge: true)
    }

    /// Fetch posts from friends for the feed
    func fetchFeedPosts(friendIds: [String], limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        var query = db.collection("posts")
            .whereField("authorId", in: friendIds.isEmpty ? ["__none__"] : friendIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let beforeDate = before {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            decodePost(from: doc.data())
        }
    }

    /// Fetch posts by a specific user
    func fetchPostsByUser(userId: String, limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        var query = db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let beforeDate = before {
            query = query.whereField("createdAt", isLessThan: Timestamp(date: beforeDate))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            decodePost(from: doc.data())
        }
    }

    /// Listen to feed posts in real-time
    func listenToFeedPosts(friendIds: [String], limit: Int = 50, onChange: @escaping ([Post]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        let effectiveIds = friendIds.isEmpty ? ["__none__"] : friendIds
        return db.collection("posts")
            .whereField("authorId", in: effectiveIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToFeedPosts")
                    onError?(error)
                    // Still call onChange with empty array so UI updates
                    onChange([])
                    return
                }

                let posts = snapshot?.documents.compactMap { doc in
                    self.decodePost(from: doc.data())
                } ?? []
                onChange(posts)
            }
    }

    /// Delete a post
    func deletePost(_ postId: UUID) async throws {
        // Delete the post document
        try await db.collection("posts").document(postId.uuidString).delete()

        // Also delete associated likes and comments (cleanup)
        let likesSnapshot = try await db.collection("posts").document(postId.uuidString).collection("likes").getDocuments()
        let commentsSnapshot = try await db.collection("posts").document(postId.uuidString).collection("comments").getDocuments()

        let batch = db.batch()
        for doc in likesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        for doc in commentsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Post Like Operations

    /// Like a post
    func likePost(postId: UUID, userId: String) async throws {
        let like = PostLike(postId: postId, userId: userId)
        let ref = db.collection("posts").document(postId.uuidString).collection("likes").document(userId)
        try await ref.setData(encodeLike(like))

        // Increment like count atomically
        let postRef = db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["likeCount": FieldValue.increment(Int64(1))])
    }

    /// Unlike a post
    func unlikePost(postId: UUID, userId: String) async throws {
        let ref = db.collection("posts").document(postId.uuidString).collection("likes").document(userId)
        try await ref.delete()

        // Decrement like count atomically
        let postRef = db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["likeCount": FieldValue.increment(Int64(-1))])
    }

    /// Check if user has liked a post
    func isPostLiked(postId: UUID, userId: String) async throws -> Bool {
        let doc = try await db.collection("posts").document(postId.uuidString).collection("likes").document(userId).getDocument()
        return doc.exists
    }

    /// Listen to like status for a post
    func listenToPostLikeStatus(postId: UUID, userId: String, onChange: @escaping (Bool) -> Void) -> ListenerRegistration {
        db.collection("posts").document(postId.uuidString).collection("likes").document(userId)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.exists ?? false)
            }
    }

    // MARK: - Post Comment Operations

    /// Add a comment to a post
    func addComment(_ comment: PostComment) async throws {
        let ref = db.collection("posts").document(comment.postId.uuidString).collection("comments").document(comment.id.uuidString)
        try await ref.setData(encodeComment(comment))

        // Increment comment count atomically
        let postRef = db.collection("posts").document(comment.postId.uuidString)
        try await postRef.updateData(["commentCount": FieldValue.increment(Int64(1))])
    }

    /// Delete a comment
    func deleteComment(postId: UUID, commentId: UUID) async throws {
        let ref = db.collection("posts").document(postId.uuidString).collection("comments").document(commentId.uuidString)
        try await ref.delete()

        // Decrement comment count atomically
        let postRef = db.collection("posts").document(postId.uuidString)
        try await postRef.updateData(["commentCount": FieldValue.increment(Int64(-1))])
    }

    /// Fetch comments for a post
    func fetchComments(postId: UUID, limit: Int = 100) async throws -> [PostComment] {
        let snapshot = try await db.collection("posts").document(postId.uuidString)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            decodeComment(from: doc.data(), postId: postId)
        }
    }

    /// Listen to comments for a post
    func listenToComments(postId: UUID, limit: Int = 100, onChange: @escaping ([PostComment]) -> Void) -> ListenerRegistration {
        db.collection("posts").document(postId.uuidString)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.error(error, context: "listenToComments")
                    return
                }

                let comments = snapshot?.documents.compactMap { doc in
                    self.decodeComment(from: doc.data(), postId: postId)
                } ?? []
                onChange(comments)
            }
    }

    // MARK: - Post Encoding/Decoding

    private func encodePost(_ post: Post) -> [String: Any] {
        var data: [String: Any] = [
            "id": post.id.uuidString,
            "authorId": post.authorId,
            "likeCount": post.likeCount,
            "commentCount": post.commentCount,
            "createdAt": Timestamp(date: post.createdAt)
        ]

        // Encode content as JSON
        if let contentData = try? JSONEncoder().encode(post.content),
           let contentDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            data["content"] = contentDict
        }

        if let caption = post.caption {
            data["caption"] = caption
        }

        if let updatedAt = post.updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }

        return data
    }

    private func decodePost(from data: [String: Any]) -> Post? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let authorId = data["authorId"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date?
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = nil
        }

        // Decode content
        let content: PostContent
        if let contentDict = data["content"] as? [String: Any],
           let contentData = try? JSONSerialization.data(withJSONObject: contentDict),
           let decoded = try? JSONDecoder().decode(PostContent.self, from: contentData) {
            content = decoded
        } else {
            content = .text("")
        }

        let caption = data["caption"] as? String
        let likeCount = data["likeCount"] as? Int ?? 0
        let commentCount = data["commentCount"] as? Int ?? 0

        return Post(
            id: id,
            authorId: authorId,
            content: content,
            caption: caption,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: likeCount,
            commentCount: commentCount,
            syncStatus: .synced
        )
    }

    private func encodeLike(_ like: PostLike) -> [String: Any] {
        [
            "id": like.id.uuidString,
            "postId": like.postId.uuidString,
            "userId": like.userId,
            "createdAt": Timestamp(date: like.createdAt)
        ]
    }

    private func encodeComment(_ comment: PostComment) -> [String: Any] {
        var data: [String: Any] = [
            "id": comment.id.uuidString,
            "postId": comment.postId.uuidString,
            "authorId": comment.authorId,
            "text": comment.text,
            "createdAt": Timestamp(date: comment.createdAt)
        ]

        if let updatedAt = comment.updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }

        return data
    }

    private func decodeComment(from data: [String: Any], postId: UUID) -> PostComment? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let authorId = data["authorId"] as? String,
              let text = data["text"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date?
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = nil
        }

        return PostComment(
            id: id,
            postId: postId,
            authorId: authorId,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
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

// MARK: - Profile Errors

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
