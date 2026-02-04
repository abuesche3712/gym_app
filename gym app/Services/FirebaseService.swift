//
//  FirebaseService.swift
//  gym app
//
//  Facade that delegates to specialized Firebase services.
//  Maintains backward compatibility while using modular service structure.
//

import Foundation
import FirebaseFirestore

// MARK: - Firebase Service Facade

/// Facade that delegates to specialized Firebase services
/// Maintains backward compatibility with existing code
@preconcurrency @MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    // MARK: - Specialized Services

    private let core = FirestoreCore.shared
    private let sync = FirestoreSyncService.shared
    private let social = FirestoreSocialService.shared
    private let messaging = FirestoreMessagingService.shared
    private let feed = FirestoreFeedService.shared
    private let library = FirestoreLibraryService.shared
    private let conflict = FirestoreConflictService.shared
    private let deletion = FirestoreDeletionService.shared

    // MARK: - Published State (forwarded from sync service)

    var isSyncing: Bool { sync.isSyncing }
    var lastError: Error? { sync.lastError }
    var decodeFailures: [DecodeFailure] { sync.decodeFailures }
    var hasDecodeFailures: Bool { sync.hasDecodeFailures }

    func clearDecodeFailures() {
        sync.clearDecodeFailures()
    }

    // MARK: - Module Operations

    func saveModule(_ module: Module) async throws {
        try await sync.saveModule(module)
    }

    func fetchModules() async throws -> [Module] {
        try await sync.fetchModules()
    }

    func deleteModule(_ moduleId: UUID) async throws {
        try await sync.deleteModule(moduleId)
    }

    // MARK: - Workout Operations

    func saveWorkout(_ workout: Workout) async throws {
        try await sync.saveWorkout(workout)
    }

    func fetchWorkouts() async throws -> [Workout] {
        try await sync.fetchWorkouts()
    }

    func deleteWorkout(_ workoutId: UUID) async throws {
        try await sync.deleteWorkout(workoutId)
    }

    // MARK: - Session Operations

    func saveSession(_ session: Session) async throws {
        try await sync.saveSession(session)
    }

    func fetchSessions() async throws -> [Session] {
        try await sync.fetchSessions()
    }

    func deleteSession(_ sessionId: UUID) async throws {
        try await sync.deleteSession(sessionId)
    }

    func updateSessionSet(sessionId: UUID, exerciseId: UUID, set: SetData) async throws {
        try await sync.updateSessionSet(sessionId: sessionId, exerciseId: exerciseId, set: set)
    }

    // MARK: - Program Operations

    func saveProgram(_ program: Program) async throws {
        try await sync.saveProgram(program)
    }

    func fetchPrograms() async throws -> [Program] {
        try await sync.fetchPrograms()
    }

    func deleteProgram(_ programId: UUID) async throws {
        try await sync.deleteProgram(programId)
    }

    // MARK: - Scheduled Workout Operations

    func saveScheduledWorkout(_ scheduled: ScheduledWorkout) async throws {
        try await sync.saveScheduledWorkout(scheduled)
    }

    func fetchScheduledWorkouts() async throws -> [ScheduledWorkout] {
        try await sync.fetchScheduledWorkouts()
    }

    func deleteScheduledWorkout(_ scheduledId: UUID) async throws {
        try await sync.deleteScheduledWorkout(scheduledId)
    }

    func deleteScheduledWorkoutsForProgram(_ programId: UUID) async throws {
        try await sync.deleteScheduledWorkoutsForProgram(programId)
    }

    // MARK: - Custom Exercise Operations

    func saveCustomExercise(_ template: ExerciseTemplate) async throws {
        try await sync.saveCustomExercise(template)
    }

    func fetchCustomExercises() async throws -> [ExerciseTemplate] {
        try await sync.fetchCustomExercises()
    }

    func deleteCustomExercise(_ exerciseId: UUID) async throws {
        try await sync.deleteCustomExercise(exerciseId)
    }

    @discardableResult
    func migrateExerciseLibraryToCustomExercises() async throws -> Int {
        try await sync.migrateExerciseLibraryToCustomExercises()
    }

    // MARK: - User Profile Operations

    func saveUserProfile(_ profile: UserProfile) async throws {
        try await social.saveUserProfile(profile)
    }

    func fetchUserProfile() async throws -> UserProfile? {
        try await social.fetchUserProfile()
    }

    func fetchUserProfile(firebaseUserId: String) async throws -> UserProfile? {
        try await social.fetchUserProfile(firebaseUserId: firebaseUserId)
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try await social.isUsernameAvailable(username)
    }

    func claimUsername(_ username: String) async throws {
        try await social.claimUsername(username)
    }

    func releaseUsername(_ username: String) async throws {
        try await social.releaseUsername(username)
    }

    func searchUsersByUsername(prefix: String, limit: Int = 20) async throws -> [UserSearchResult] {
        try await social.searchUsersByUsername(prefix: prefix, limit: limit)
    }

    func fetchPublicProfile(userId: String) async throws -> UserProfile? {
        try await social.fetchPublicProfile(userId: userId)
    }

    // MARK: - Friendship Operations

    func saveFriendship(_ friendship: Friendship) async throws {
        try await social.saveFriendship(friendship)
    }

    func deleteFriendship(id: UUID) async throws {
        try await social.deleteFriendship(id: id)
    }

    func fetchFriendships(for userId: String) async throws -> [Friendship] {
        try await social.fetchFriendships(for: userId)
    }

    func listenToFriendships(for userId: String, onChange: @escaping ([Friendship]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        social.listenToFriendships(for: userId, onChange: onChange, onError: onError)
    }

    // MARK: - Conversation Operations

    func saveConversation(_ conversation: Conversation) async throws {
        try await messaging.saveConversation(conversation)
    }

    func fetchConversations(for userId: String) async throws -> [Conversation] {
        try await messaging.fetchConversations(for: userId)
    }

    func listenToConversations(for userId: String, onChange: @escaping ([Conversation]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        messaging.listenToConversations(for: userId, onChange: onChange, onError: onError)
    }

    func deleteConversation(id: UUID) async throws {
        try await messaging.deleteConversation(id: id)
    }

    // MARK: - Message Operations

    func saveMessage(_ message: Message) async throws {
        try await messaging.saveMessage(message)
    }

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [Message] {
        try await messaging.fetchMessages(conversationId: conversationId, limit: limit, before: before)
    }

    func listenToMessages(conversationId: UUID, limit: Int = 100, onChange: @escaping ([Message]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        messaging.listenToMessages(conversationId: conversationId, limit: limit, onChange: onChange, onError: onError)
    }

    func markMessageRead(conversationId: UUID, messageId: UUID, at date: Date = Date()) async throws {
        try await messaging.markMessageRead(conversationId: conversationId, messageId: messageId, at: date)
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
        let syncData = try await sync.fetchAllUserData()
        let profile = try await social.fetchUserProfile()

        return (
            syncData.modules,
            syncData.workouts,
            syncData.sessions,
            syncData.exercises,
            syncData.programs,
            syncData.scheduledWorkouts,
            profile
        )
    }

    // MARK: - Library Operations

    func fetchExerciseLibrary() async throws -> [ExerciseTemplate] {
        try await library.fetchExerciseLibrary()
    }

    func fetchEquipmentLibrary() async throws -> [[String: Any]] {
        try await library.fetchEquipmentLibrary()
    }

    func fetchProgressionSchemes() async throws -> [[String: Any]] {
        try await library.fetchProgressionSchemes()
    }

    // MARK: - Conflict Resolution

    typealias ConflictResolution = FirestoreConflictService.ConflictResolution

    func resolveConflict(localUpdatedAt: Date, cloudUpdatedAt: Date?) -> ConflictResolution {
        conflict.resolveConflict(localUpdatedAt: localUpdatedAt, cloudUpdatedAt: cloudUpdatedAt)
    }

    func fetchModuleTimestamp(_ moduleId: UUID) async throws -> Date? {
        try await conflict.fetchModuleTimestamp(moduleId)
    }

    func fetchWorkoutTimestamp(_ workoutId: UUID) async throws -> Date? {
        try await conflict.fetchWorkoutTimestamp(workoutId)
    }

    func fetchSessionTimestamp(_ sessionId: UUID) async throws -> Date? {
        try await conflict.fetchSessionTimestamp(sessionId)
    }

    func fetchProgramTimestamp(_ programId: UUID) async throws -> Date? {
        try await conflict.fetchProgramTimestamp(programId)
    }

    func fetchCustomExerciseTimestamp(_ exerciseId: UUID) async throws -> Date? {
        try await conflict.fetchCustomExerciseTimestamp(exerciseId)
    }

    func saveModuleWithConflictCheck(_ module: Module, localUpdatedAt: Date) async throws -> Bool {
        try await conflict.saveModuleWithConflictCheck(module, localUpdatedAt: localUpdatedAt)
    }

    func saveWorkoutWithConflictCheck(_ workout: Workout, localUpdatedAt: Date) async throws -> Bool {
        try await conflict.saveWorkoutWithConflictCheck(workout, localUpdatedAt: localUpdatedAt)
    }

    func saveSessionWithConflictCheck(_ session: Session, localUpdatedAt: Date) async throws -> Bool {
        try await conflict.saveSessionWithConflictCheck(session, localUpdatedAt: localUpdatedAt)
    }

    func saveProgram(_ program: Program, localUpdatedAt: Date) async throws -> Bool {
        try await conflict.saveProgramWithConflictCheck(program, localUpdatedAt: localUpdatedAt)
    }

    typealias CloudEntity<T> = FirestoreConflictService.CloudEntity<T>

    func fetchModulesWithTimestamps() async throws -> [CloudEntity<Module>] {
        try await conflict.fetchModulesWithTimestamps()
    }

    func fetchWorkoutsWithTimestamps() async throws -> [CloudEntity<Workout>] {
        try await conflict.fetchWorkoutsWithTimestamps()
    }

    func fetchSessionsWithTimestamps() async throws -> [CloudEntity<Session>] {
        try await conflict.fetchSessionsWithTimestamps()
    }

    func fetchProgramsWithTimestamps() async throws -> [CloudEntity<Program>] {
        try await conflict.fetchProgramsWithTimestamps()
    }

    typealias SyncResult<T> = FirestoreConflictService.SyncResult<T>

    func syncModulesBidirectional(
        localModules: [(module: Module, localUpdatedAt: Date, syncedAt: Date?)]
    ) async throws -> SyncResult<Module> {
        try await conflict.syncModulesBidirectional(localModules: localModules)
    }

    // MARK: - Post Operations

    func savePost(_ post: Post) async throws {
        try await feed.savePost(post)
    }

    func fetchFeedPosts(friendIds: [String], limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        try await feed.fetchFeedPosts(friendIds: friendIds, limit: limit, before: before)
    }

    func fetchPostsByUser(userId: String, limit: Int = 50, before: Date? = nil) async throws -> [Post] {
        try await feed.fetchPostsByUser(userId: userId, limit: limit, before: before)
    }

    func listenToFeedPosts(friendIds: [String], limit: Int = 50, onChange: @escaping ([Post]) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        feed.listenToFeedPosts(friendIds: friendIds, limit: limit, onChange: onChange, onError: onError)
    }

    func listenToPost(postId: UUID, onChange: @escaping (Post?) -> Void, onError: ((Error) -> Void)? = nil) -> ListenerRegistration {
        feed.listenToPost(postId: postId, onChange: onChange, onError: onError)
    }

    func updatePost(_ post: Post) async throws {
        try await feed.updatePost(post)
    }

    func deletePost(_ postId: UUID) async throws {
        try await feed.deletePost(postId)
    }

    // MARK: - Post Like Operations

    func likePost(postId: UUID, userId: String) async throws {
        try await feed.likePost(postId: postId, userId: userId)
    }

    func unlikePost(postId: UUID, userId: String) async throws {
        try await feed.unlikePost(postId: postId, userId: userId)
    }

    func isPostLiked(postId: UUID, userId: String) async throws -> Bool {
        try await feed.isPostLiked(postId: postId, userId: userId)
    }

    func listenToPostLikeStatus(postId: UUID, userId: String, onChange: @escaping (Bool) -> Void) -> ListenerRegistration {
        feed.listenToPostLikeStatus(postId: postId, userId: userId, onChange: onChange)
    }

    func fetchLikedPostIds(postIds: [UUID], userId: String) async -> Set<UUID> {
        await feed.fetchLikedPostIds(postIds: postIds, userId: userId)
    }

    // MARK: - Post Comment Operations

    func addComment(_ comment: PostComment) async throws {
        try await feed.addComment(comment)
    }

    func deleteComment(postId: UUID, commentId: UUID) async throws {
        try await feed.deleteComment(postId: postId, commentId: commentId)
    }

    func fetchComments(postId: UUID, limit: Int = 100) async throws -> [PostComment] {
        try await feed.fetchComments(postId: postId, limit: limit)
    }

    func listenToComments(postId: UUID, limit: Int = 100, onChange: @escaping ([PostComment]) -> Void) -> ListenerRegistration {
        feed.listenToComments(postId: postId, limit: limit, onChange: onChange)
    }

    // MARK: - Deletion Records

    func saveDeletionRecord(_ record: DeletionRecord) async throws {
        try await deletion.saveDeletionRecord(record)
    }

    func saveDeletionRecords(_ records: [DeletionRecord]) async throws {
        try await deletion.saveDeletionRecords(records)
    }

    func fetchDeletionRecords() async throws -> [DeletionRecord] {
        try await deletion.fetchDeletionRecords()
    }

    func fetchDeletionRecords(since date: Date) async throws -> [DeletionRecord] {
        try await deletion.fetchDeletionRecords(since: date)
    }

    func deleteDeletionRecord(_ recordId: UUID) async throws {
        try await deletion.deleteDeletionRecord(recordId)
    }

    func deleteDeletionRecords(_ recordIds: [UUID]) async throws {
        try await deletion.deleteDeletionRecords(recordIds)
    }

    func cleanupOldDeletionRecords(olderThan date: Date) async throws -> Int {
        try await deletion.cleanupOldDeletionRecords(olderThan: date)
    }
}
