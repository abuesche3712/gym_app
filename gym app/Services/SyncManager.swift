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

// MARK: - Background Queue Processor

/// Actor that handles all sync queue operations on a background thread
/// This prevents blocking the main thread during CoreData and Firebase operations
actor SyncQueueProcessor {
    private let persistence: PersistenceController
    private let firestoreService: FirestoreService
    private var handlers: [SyncEntityType: AnySyncHandler] = [:]

    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistence.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()

    init(persistence: PersistenceController, firestoreService: FirestoreService) {
        self.persistence = persistence
        self.firestoreService = firestoreService
        self.handlers = Self.makeHandlers(firestoreService: firestoreService)
    }

    private static func makeHandlers(firestoreService: FirestoreService) -> [SyncEntityType: AnySyncHandler] {
        var handlers: [SyncEntityType: AnySyncHandler] = [:]

        func register<H: SyncHandler>(_ handler: H) {
            handlers[handler.entityType] = AnySyncHandler(handler)
        }

        register(ModuleSyncHandler(firestoreService: firestoreService))
        register(WorkoutSyncHandler(firestoreService: firestoreService))
        register(SessionSyncHandler(firestoreService: firestoreService))
        register(ProgramSyncHandler(firestoreService: firestoreService))
        register(ScheduledWorkoutSyncHandler(firestoreService: firestoreService))
        register(CustomExerciseSyncHandler(firestoreService: firestoreService))

        return handlers
    }

    // Non-blocking log helpers to avoid MainActor deadlock
    private func logInfo(_ message: String, context: String) {
        Task { @MainActor in
            SyncLogger.shared.info(message, context: context)
        }
    }

    private func logWarning(_ message: String, context: String) {
        Task { @MainActor in
            SyncLogger.shared.warning(message, context: context)
        }
    }

    private func logError(_ error: Error, context: String, additionalInfo: String?) {
        Task { @MainActor in
            SyncLogger.shared.logError(error, context: context, additionalInfo: additionalInfo)
        }
    }

    // MARK: - Queue Item Management

    func queueItem(entityType: SyncEntityType, entityId: UUID, action: SyncAction, payload: Data) async -> Bool {
        let entity = SyncQueueEntity(context: backgroundContext)
        entity.id = UUID()
        entity.entityType = entityType
        entity.entityId = entityId
        entity.action = action
        entity.payload = payload
        entity.createdAt = Date()
        entity.retryCount = 0

        do {
            try backgroundContext.save()
            logInfo("Queued \(entityType.rawValue) \(entityId) for \(action.rawValue)", context: "SyncQueueProcessor")
            return true
        } catch {
            logError(error, context: "SyncQueueProcessor.queueItem", additionalInfo: "Failed to queue sync item")
            return false
        }
    }

    // MARK: - Queue Processing

    func processQueue() async {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncQueueEntity.createdAt, ascending: true)
        ]
        request.predicate = NSPredicate(format: "retryCount < %d", SyncQueueItem.maxRetries)

        do {
            let items = try backgroundContext.fetch(request)
            let sortedItems = items.sorted { $0.entityType.priority < $1.entityType.priority }

            for item in sortedItems {
                await processQueueItem(item)
            }
        } catch {
            logError(error, context: "SyncQueueProcessor.processQueue", additionalInfo: "Failed to fetch queue items")
        }
    }

    private func processQueueItem(_ item: SyncQueueEntity) async {
        // Capture values before any operations (in case item gets deleted)
        let entityTypeStr = item.entityType.rawValue
        let entityIdStr = item.entityId.uuidString

        do {
            // Special cases that don't fit the standard handler pattern
            switch item.entityType {
            case .setData:
                try await syncSetFromQueue(item)
            case .userProfile:
                try await syncUserProfileFromQueue(item)
            default:
                // Use registered handler
                guard let handler = handlers[item.entityType] else {
                    logWarning("No handler registered for \(entityTypeStr)", context: "SyncQueueProcessor")
                    return
                }
                try await handler.process(payload: item.payload, action: item.action)
            }

            // Success - remove from queue
            backgroundContext.delete(item)
            try backgroundContext.save()
            logInfo("Successfully synced \(entityTypeStr) \(entityIdStr)", context: "SyncQueueProcessor")

        } catch {
            // Decoding failures will never succeed - remove immediately
            if case SyncError.decodingFailed = error {
                logWarning("Removing undecodable \(entityTypeStr) \(entityIdStr) from queue", context: "SyncQueueProcessor")
                backgroundContext.delete(item)
                try? backgroundContext.save()
                return
            }

            // Other failures - increment retry count
            item.retryCount += 1
            item.lastAttemptAt = Date()
            item.lastError = error.localizedDescription
            try? backgroundContext.save()

            logError(error, context: "SyncQueueProcessor", additionalInfo: "Failed to sync \(entityTypeStr) \(entityIdStr), retry \(item.retryCount)")
        }
    }

    // MARK: - Special Case Sync Methods

    private func syncSetFromQueue(_ item: SyncQueueEntity) async throws {
        guard let payload = try? JSONDecoder().decode(SetSyncPayload.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }
        try await firestoreService.updateSessionSet(
            sessionId: payload.sessionId,
            exerciseId: payload.exerciseId,
            set: payload.set
        )
    }

    private func syncUserProfileFromQueue(_ item: SyncQueueEntity) async throws {
        guard let profile = try? JSONDecoder().decode(UserProfile.self, from: item.payload) else {
            throw SyncError.decodingFailed
        }
        try await firestoreService.saveUserProfile(profile)
    }

    // MARK: - Queue Counts

    func getPendingCounts() -> (pending: Int, failed: Int) {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
        do {
            let allItems = try backgroundContext.fetch(request)
            let pending = allItems.filter { !$0.needsManualIntervention }.count
            let failed = allItems.filter { $0.needsManualIntervention }.count
            return (pending, failed)
        } catch {
            logError(error, context: "SyncQueueProcessor.getPendingCounts", additionalInfo: "Failed to count items")
            return (0, 0)
        }
    }

    // MARK: - Queue Clearing

    func clearFailedItems() {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
        request.predicate = NSPredicate(format: "retryCount >= %d", SyncQueueItem.maxRetries)

        do {
            let failedItems = try backgroundContext.fetch(request)
            for item in failedItems {
                backgroundContext.delete(item)
            }
            try backgroundContext.save()
            logInfo("Cleared \(failedItems.count) failed sync items", context: "SyncQueueProcessor")
        } catch {
            logError(error, context: "SyncQueueProcessor.clearFailedItems", additionalInfo: "Failed to clear")
        }
    }

    func clearAllItems() {
        let request = NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")

        do {
            let allItems = try backgroundContext.fetch(request)
            for item in allItems {
                backgroundContext.delete(item)
            }
            try backgroundContext.save()
            logInfo("Cleared all \(allItems.count) sync queue items", context: "SyncQueueProcessor")
        } catch {
            logError(error, context: "SyncQueueProcessor.clearAllItems", additionalInfo: "Failed to clear")
        }
    }
}

// MARK: - Main Sync Manager

@preconcurrency @MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // MARK: - Dependencies

    private let authService = AuthService.shared
    private let dataRepository = DataRepository.shared
    private let firestoreService = FirestoreService.shared
    private let networkMonitor = NetworkMonitorService.shared
    private let persistence = PersistenceController.shared
    private let logger = SyncLogger.shared

    /// Background queue processor - handles heavy work off main thread
    private lazy var queueProcessor = SyncQueueProcessor(
        persistence: persistence,
        firestoreService: firestoreService
    )

    // MARK: - Published State (UI updates on main thread)

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
        Task { await updatePendingCounts() }
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
                    if wasOffline && self.syncEnabled {
                        Task {
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
        await retryFailedSyncs()
        await checkLibraryUpdates()
    }

    // MARK: - Main Sync Operations

    /// Full sync on login/app launch
    func syncOnLogin() async {
        guard syncEnabled else {
            logger.info("Not authenticated, skipping login sync", context: "SyncManager")
            return
        }

        guard isOnline else {
            logger.warning("Offline, skipping login sync", context: "SyncManager")
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

        // 3. Flush any queued items (runs on background thread)
        syncState = .syncing(progress: "Processing queue...")
        await queueProcessor.processQueue()

        lastSyncDate = Date()
        saveLastSyncDate()
        syncState = .success

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        syncState = .idle

        await updatePendingCounts()
    }

    /// Manual full sync
    func syncAll() async {
        await syncOnLogin()
    }

    /// Lightweight sync for individual set during workout
    func syncSet(_ set: SetData, sessionId: UUID, exerciseId: UUID) {
        guard syncEnabled else { return }

        let setPayload = SetSyncPayload(
            sessionId: sessionId,
            exerciseId: exerciseId,
            set: set
        )

        guard let payload = try? JSONEncoder().encode(setPayload) else {
            logger.error("Failed to encode set for sync", context: "SyncManager.syncSet")
            return
        }

        Task {
            let queued = await queueProcessor.queueItem(
                entityType: .setData,
                entityId: set.id,
                action: .update,
                payload: payload
            )

            if queued && isOnline {
                await queueProcessor.processQueue()
                await updatePendingCounts()
            }
        }
    }

    /// Sync completed workout immediately
    func syncCompletedWorkout(_ session: Session) async {
        guard syncEnabled else { return }

        guard let payload = try? JSONEncoder().encode(session) else {
            logger.error("Failed to encode session for sync", context: "SyncManager.syncCompletedWorkout")
            return
        }

        if isOnline {
            do {
                try await firestoreService.saveSession(session)
                logger.info("Session synced immediately", context: "SyncManager.syncCompletedWorkout")
            } catch {
                logger.logError(error, context: "SyncManager.syncCompletedWorkout", additionalInfo: "Immediate sync failed, queuing")
                _ = await queueProcessor.queueItem(
                    entityType: .session,
                    entityId: session.id,
                    action: .create,
                    payload: payload
                )
            }
        } else {
            _ = await queueProcessor.queueItem(
                entityType: .session,
                entityId: session.id,
                action: .create,
                payload: payload
            )
        }

        await updatePendingCounts()
    }

    /// Retry all failed syncs in queue
    func retryFailedSyncs() async {
        guard syncEnabled, isOnline else { return }

        syncState = .syncing(progress: "Retrying failed syncs...")
        await queueProcessor.processQueue()
        syncState = .idle
        await updatePendingCounts()
    }

    // MARK: - Pull Operations

    private func pullFromCloud() async {
        await dataRepository.syncFromCloud()
        await checkLibraryUpdates()
    }

    private func checkLibraryUpdates() async {
        var metadata = librarySyncMetadata

        if metadata.needsRefresh(\.exerciseLibraryLastSync) {
            do {
                _ = try await firestoreService.fetchExerciseLibrary()
                metadata.exerciseLibraryLastSync = Date()
                logger.info("Exercise library updated", context: "SyncManager.checkLibraryUpdates")
            } catch {
                logger.logError(error, context: "SyncManager.checkLibraryUpdates", additionalInfo: "Failed to fetch exercise library")
            }
        }

        if metadata.needsRefresh(\.equipmentLibraryLastSync) {
            do {
                _ = try await firestoreService.fetchEquipmentLibrary()
                metadata.equipmentLibraryLastSync = Date()
                logger.info("Equipment library updated", context: "SyncManager.checkLibraryUpdates")
            } catch {
                logger.logError(error, context: "SyncManager.checkLibraryUpdates", additionalInfo: "Failed to fetch equipment library")
            }
        }

        if metadata.needsRefresh(\.progressionSchemesLastSync) {
            do {
                _ = try await firestoreService.fetchProgressionSchemes()
                metadata.progressionSchemesLastSync = Date()
                logger.info("Progression schemes updated", context: "SyncManager.checkLibraryUpdates")
            } catch {
                logger.logError(error, context: "SyncManager.checkLibraryUpdates", additionalInfo: "Failed to fetch progression schemes")
            }
        }

        librarySyncMetadata = metadata
    }

    // MARK: - Push Operations

    private func pushPendingToCloud() async {
        await dataRepository.pushAllToCloud()
    }

    // MARK: - Generic Queue Method

    /// Queue any Codable entity for sync
    private func queue<T: Codable & Identifiable>(
        _ entity: T,
        entityType: SyncEntityType,
        action: SyncAction,
        processImmediately: Bool = false
    ) where T.ID == UUID {
        guard let payload = try? JSONEncoder().encode(entity) else {
            logger.error("Failed to encode \(entityType.rawValue) for sync", context: "SyncManager")
            return
        }
        Task {
            let queued = await queueProcessor.queueItem(
                entityType: entityType,
                entityId: entity.id,
                action: action,
                payload: payload
            )
            if queued && processImmediately && isOnline {
                await queueProcessor.processQueue()
            }
            await updatePendingCounts()
        }
    }

    // MARK: - Type-Safe Queue Methods

    func queueModule(_ module: Module, action: SyncAction) {
        queue(module, entityType: .module, action: action)
    }

    func queueWorkout(_ workout: Workout, action: SyncAction) {
        queue(workout, entityType: .workout, action: action)
    }

    func queueProgram(_ program: Program, action: SyncAction) {
        queue(program, entityType: .program, action: action)
    }

    func queueSession(_ session: Session, action: SyncAction) {
        queue(session, entityType: .session, action: action)
    }

    func queueScheduledWorkout(_ scheduled: ScheduledWorkout, action: SyncAction) {
        queue(scheduled, entityType: .scheduledWorkout, action: action, processImmediately: true)
    }

    func queueCustomExercise(_ exercise: ExerciseTemplate, action: SyncAction) {
        queue(exercise, entityType: .customExercise, action: action)
    }

    /// UserProfile has special handling (no ID from entity, no delete action)
    func queueUserProfile(_ profile: UserProfile) {
        guard let payload = try? JSONEncoder().encode(profile) else { return }
        Task {
            _ = await queueProcessor.queueItem(entityType: .userProfile, entityId: UUID(), action: .update, payload: payload)
            await updatePendingCounts()
        }
    }

    // MARK: - Pending Count Management

    private func updatePendingCounts() async {
        let counts = await queueProcessor.getPendingCounts()
        pendingSyncCount = counts.pending
        failedSyncCount = counts.failed
    }

    /// Clear failed items that need manual intervention
    func clearFailedSyncs() {
        Task {
            await queueProcessor.clearFailedItems()
            await updatePendingCounts()
        }
    }

    /// Clear ALL items from sync queue (use for recovery)
    func clearAllSyncQueue() {
        Task {
            await queueProcessor.clearAllItems()
            await updatePendingCounts()
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

        if shouldSyncOnResume() {
            Task {
                await syncOnLogin()
            }
        }
    }

    func appWillResignActive() {
        stopBackgroundSync()

        guard syncEnabled else { return }
        Task {
            await queueProcessor.processQueue()
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
