//
//  SyncManager.swift
//  gym app
//
//  Comprehensive sync manager for bidirectional sync between CoreData and Firebase
//  Handles timing, queuing, and retry logic for all sync operations
//

import Foundation
import CoreData
import Combine

@preconcurrency @MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let dataRepository = DataRepository.shared
    private let firestoreService = FirestoreService.shared
    private let networkMonitor = NetworkMonitorService.shared
    private let persistence = PersistenceController.shared

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    // MARK: - Published State

    @Published var syncState: SyncState = .idle
    @Published var isOnline = true
    @Published var lastSyncDate: Date?
    @Published var pendingSyncCount = 0
    @Published var failedSyncCount = 0

    // MARK: - Configuration

    private let backgroundSyncInterval: TimeInterval = 300  // 5 minutes
    private let minSyncInterval: TimeInterval = 60          // 1 minute minimum between syncs
    private var backgroundSyncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Library Sync Metadata

    private var librarySyncMetadata: LibrarySyncMetadata {
        get {
            guard let data = UserDefaults.standard.data(forKey: "librarySyncMetadata"),
                  let metadata = try? JSONDecoder().decode(LibrarySyncMetadata.self, from: data) else {
                return LibrarySyncMetadata()
            }
            return metadata
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "librarySyncMetadata")
            }
        }
    }

    /// Sync is enabled when user is authenticated
    var syncEnabled: Bool {
        authService.isAuthenticated
    }

    // MARK: - Initialization

    init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
        updatePendingCounts()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = isConnected

                if isConnected {
                    self.syncState = .idle
                    // Flush queue when coming back online
                    if wasOffline && self.syncEnabled {
                        Task { @MainActor in
                            await self.retryFailedSyncs()
                        }
                    }
                } else {
                    self.syncState = .offline
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Background Sync

    func startBackgroundSync() {
        stopBackgroundSync()

        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: backgroundSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.backgroundSyncTick()
            }
        }
    }

    func stopBackgroundSync() {
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
    }

    private func backgroundSyncTick() async {
        guard syncEnabled, isOnline else { return }

        // Retry failed syncs
        await retryFailedSyncs()

        // Check for library updates (once per day)
        await checkLibraryUpdates()
    }

    // MARK: - Main Sync Operations

    /// Full sync on login/app launch - pulls from cloud then pushes local changes
    func syncOnLogin() async {
        guard syncEnabled else {
            print("SyncManager: Not authenticated, skipping login sync")
            return
        }

        guard isOnline else {
            print("SyncManager: Offline, skipping login sync")
            syncState = .offline
            return
        }

        syncState = .syncing(progress: "Syncing...")

        // 1. Pull latest from cloud
        syncState = .syncing(progress: "Pulling from cloud...")
        await pullFromCloud()

        // 2. Push any local changes not yet synced
        syncState = .syncing(progress: "Pushing to cloud...")
        await pushPendingToCloud()

        // 3. Flush any queued items
        syncState = .syncing(progress: "Processing queue...")
        await processQueue()

        lastSyncDate = Date()
        saveLastSyncDate()
        syncState = .success

        // Reset to idle after brief success indication
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        syncState = .idle

        updatePendingCounts()
    }

    /// Manual full sync (same as login flow)
    func syncAll() async {
        await syncOnLogin()
    }

    /// Lightweight sync for individual set during workout (queued, non-blocking)
    func syncSet(_ set: SetData, sessionId: UUID, exerciseId: UUID) {
        guard syncEnabled else { return }

        // Create a lightweight payload for just the set
        let setPayload = SetSyncPayload(
            sessionId: sessionId,
            exerciseId: exerciseId,
            set: set
        )

        guard let payload = try? JSONEncoder().encode(setPayload) else {
            print("SyncManager: Failed to encode set for sync")
            return
        }

        // Queue for sync
        queueSyncItem(
            entityType: .setData,
            entityId: set.id,
            action: .update,
            payload: payload
        )

        // Try immediate sync if online
        if isOnline {
            Task { @MainActor in
                await processQueue()
            }
        }
    }

    /// Sync completed workout immediately
    func syncCompletedWorkout(_ session: Session) async {
        guard syncEnabled else { return }

        guard let payload = try? JSONEncoder().encode(session) else {
            print("SyncManager: Failed to encode session for sync")
            return
        }

        if isOnline {
            // Try immediate sync
            do {
                try await firestoreService.saveSession(session)
                print("SyncManager: Session synced immediately")
            } catch {
                print("SyncManager: Immediate session sync failed, queuing: \(error)")
                queueSyncItem(
                    entityType: .session,
                    entityId: session.id,
                    action: .create,
                    payload: payload
                )
            }
        } else {
            // Queue for later
            queueSyncItem(
                entityType: .session,
                entityId: session.id,
                action: .create,
                payload: payload
            )
        }

        updatePendingCounts()
    }

    /// Retry all failed syncs in queue
    func retryFailedSyncs() async {
        guard syncEnabled, isOnline else { return }

        syncState = .syncing(progress: "Retrying failed syncs...")
        await processQueue()
        syncState = .idle
        updatePendingCounts()
    }

    // MARK: - Pull Operations

    private func pullFromCloud() async {
        // Pull all user data
        await dataRepository.syncFromCloud()

        // Check library updates if needed
        await checkLibraryUpdates()
    }

    private func checkLibraryUpdates() async {
        var metadata = librarySyncMetadata

        // Check exercise library (24-hour cache)
        if metadata.needsRefresh(\.exerciseLibraryLastSync) {
            do {
                _ = try await firestoreService.fetchExerciseLibrary()
                metadata.exerciseLibraryLastSync = Date()
                print("SyncManager: Exercise library updated")
            } catch {
                print("SyncManager: Failed to fetch exercise library: \(error)")
            }
        }

        // Check equipment library
        if metadata.needsRefresh(\.equipmentLibraryLastSync) {
            do {
                _ = try await firestoreService.fetchEquipmentLibrary()
                metadata.equipmentLibraryLastSync = Date()
                print("SyncManager: Equipment library updated")
            } catch {
                print("SyncManager: Failed to fetch equipment library: \(error)")
            }
        }

        // Check progression schemes
        if metadata.needsRefresh(\.progressionSchemesLastSync) {
            do {
                _ = try await firestoreService.fetchProgressionSchemes()
                metadata.progressionSchemesLastSync = Date()
                print("SyncManager: Progression schemes updated")
            } catch {
                print("SyncManager: Failed to fetch progression schemes: \(error)")
            }
        }

        librarySyncMetadata = metadata
    }

    // MARK: - Push Operations

    private func pushPendingToCloud() async {
        await dataRepository.pushAllToCloud()
    }

    // MARK: - Queue Management

    private func queueSyncItem(entityType: SyncEntityType, entityId: UUID, action: SyncAction, payload: Data) {
        let entity = SyncQueueEntity(context: viewContext)
        entity.id = UUID()
        entity.entityType = entityType
        entity.entityId = entityId
        entity.action = action
        entity.payload = payload
        entity.createdAt = Date()
        entity.retryCount = 0

        do {
            try viewContext.save()
            updatePendingCounts()
            print("SyncManager: Queued \(entityType.rawValue) \(entityId) for \(action.rawValue)")
        } catch {
            print("SyncManager: Failed to queue sync item: \(error)")
        }
    }

    private func processQueue() async {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncQueueEntity.createdAt, ascending: true)
        ]
        // Only process items that haven't exceeded retry limit
        request.predicate = NSPredicate(format: "retryCount < %d", SyncQueueItem.maxRetries)

        do {
            let items = try viewContext.fetch(request)

            // Sort by priority (entityType priority)
            let sortedItems = items.sorted { item1, item2 in
                item1.entityType.priority < item2.entityType.priority
            }

            for item in sortedItems {
                await processQueueItem(item)
            }
        } catch {
            print("SyncManager: Failed to fetch queue items: \(error)")
        }

        updatePendingCounts()
    }

    private func processQueueItem(_ item: SyncQueueEntity) async {
        guard isOnline else { return }

        do {
            switch item.entityType {
            case .setData:
                try await syncSetFromQueue(item)
            case .session:
                try await syncSessionFromQueue(item)
            case .module:
                try await syncModuleFromQueue(item)
            case .workout:
                try await syncWorkoutFromQueue(item)
            case .program:
                try await syncProgramFromQueue(item)
            case .scheduledWorkout:
                try await syncScheduledWorkoutFromQueue(item)
            case .customExercise:
                try await syncCustomExerciseFromQueue(item)
            case .userProfile:
                try await syncUserProfileFromQueue(item)
            }

            // Success - remove from queue
            viewContext.delete(item)
            try viewContext.save()
            print("SyncManager: Successfully synced \(item.entityType.rawValue) \(item.entityId)")

        } catch {
            // Failed - increment retry count
            item.retryCount += 1
            item.lastAttemptAt = Date()
            item.lastError = error.localizedDescription

            do {
                try viewContext.save()
            } catch {
                print("SyncManager: Failed to update queue item: \(error)")
            }

            print("SyncManager: Failed to sync \(item.entityType.rawValue) \(item.entityId), retry \(item.retryCount): \(error)")
        }
    }

    // MARK: - Entity-Specific Sync

    private func syncSetFromQueue(_ item: SyncQueueEntity) async throws {
        guard let payload = try? JSONDecoder().decode(SetSyncPayload.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        // For sets, we update the parent session
        // This is a lightweight incremental update
        try await firestoreService.updateSessionSet(
            sessionId: payload.sessionId,
            exerciseId: payload.exerciseId,
            set: payload.set
        )
    }

    private func syncSessionFromQueue(_ item: SyncQueueEntity) async throws {
        guard let session = try? JSONDecoder().decode(Session.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveSession(session)
        case .delete:
            try await firestoreService.deleteSession(session.id)
        }
    }

    private func syncModuleFromQueue(_ item: SyncQueueEntity) async throws {
        guard let module = try? JSONDecoder().decode(Module.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveModule(module)
        case .delete:
            try await firestoreService.deleteModule(module.id)
        }
    }

    private func syncWorkoutFromQueue(_ item: SyncQueueEntity) async throws {
        guard let workout = try? JSONDecoder().decode(Workout.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveWorkout(workout)
        case .delete:
            try await firestoreService.deleteWorkout(workout.id)
        }
    }

    private func syncProgramFromQueue(_ item: SyncQueueEntity) async throws {
        guard let program = try? JSONDecoder().decode(Program.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveProgram(program)
        case .delete:
            try await firestoreService.deleteProgram(program.id)
        }
    }

    private func syncScheduledWorkoutFromQueue(_ item: SyncQueueEntity) async throws {
        guard let scheduled = try? JSONDecoder().decode(ScheduledWorkout.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveScheduledWorkout(scheduled)
        case .delete:
            try await firestoreService.deleteScheduledWorkout(scheduled.id)
        }
    }

    private func syncCustomExerciseFromQueue(_ item: SyncQueueEntity) async throws {
        guard let exercise = try? JSONDecoder().decode(ExerciseTemplate.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        switch item.action {
        case .create, .update:
            try await firestoreService.saveCustomExercise(exercise)
        case .delete:
            try await firestoreService.deleteCustomExercise(exercise.id)
        }
    }

    private func syncUserProfileFromQueue(_ item: SyncQueueEntity) async throws {
        guard let profile = try? JSONDecoder().decode(UserProfile.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }

        try await firestoreService.saveUserProfile(profile)
    }

    // MARK: - Queue Helpers

    func queueModule(_ module: Module, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(module) else { return }
        queueSyncItem(entityType: .module, entityId: module.id, action: action, payload: payload)
    }

    func queueWorkout(_ workout: Workout, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(workout) else { return }
        queueSyncItem(entityType: .workout, entityId: workout.id, action: action, payload: payload)
    }

    func queueProgram(_ program: Program, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(program) else { return }
        queueSyncItem(entityType: .program, entityId: program.id, action: action, payload: payload)
    }

    func queueScheduledWorkout(_ scheduled: ScheduledWorkout, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(scheduled) else { return }
        queueSyncItem(entityType: .scheduledWorkout, entityId: scheduled.id, action: action, payload: payload)
    }

    func queueSession(_ session: Session, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(session) else { return }
        queueSyncItem(entityType: .session, entityId: session.id, action: action, payload: payload)
    }

    func queueCustomExercise(_ exercise: ExerciseTemplate, action: SyncAction) {
        guard let payload = try? JSONEncoder().encode(exercise) else { return }
        queueSyncItem(entityType: .customExercise, entityId: exercise.id, action: action, payload: payload)
    }

    func queueUserProfile(_ profile: UserProfile) {
        guard let payload = try? JSONEncoder().encode(profile) else { return }
        queueSyncItem(entityType: .userProfile, entityId: UUID(), action: .update, payload: payload)
    }

    // MARK: - Pending Count Management

    private func updatePendingCounts() {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")

        do {
            let allItems = try viewContext.fetch(request)
            pendingSyncCount = allItems.filter { !$0.needsManualIntervention }.count
            failedSyncCount = allItems.filter { $0.needsManualIntervention }.count
        } catch {
            print("SyncManager: Failed to count pending items: \(error)")
        }
    }

    /// Clear failed items that need manual intervention
    func clearFailedSyncs() {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
        request.predicate = NSPredicate(format: "retryCount >= %d", SyncQueueItem.maxRetries)

        do {
            let failedItems = try viewContext.fetch(request)
            for item in failedItems {
                viewContext.delete(item)
            }
            try viewContext.save()
            updatePendingCounts()
        } catch {
            print("SyncManager: Failed to clear failed syncs: \(error)")
        }
    }

    // MARK: - Persistence

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }
}

// MARK: - App Lifecycle Integration

extension SyncManager {
    func appDidBecomeActive() {
        guard syncEnabled else { return }
        startBackgroundSync()

        // Sync if it's been a while
        if shouldSyncOnResume() {
            Task { @MainActor in
                await syncOnLogin()
            }
        }
    }

    func appWillResignActive() {
        stopBackgroundSync()

        guard syncEnabled else { return }
        // Push any pending changes before going to background
        Task { @MainActor in
            await processQueue()
        }
    }

    private func shouldSyncOnResume() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > minSyncInterval
    }
}

// MARK: - Supporting Types

/// Lightweight payload for syncing individual sets during workout
struct SetSyncPayload: Codable {
    let sessionId: UUID
    let exerciseId: UUID
    let set: SetData
}

/// Sync-specific errors
enum SyncError: LocalizedError {
    case notAuthenticated
    case offline
    case encodingFailed
    case decodingFailed
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .offline:
            return "No internet connection"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .syncFailed(let message):
            return message
        }
    }
}
