//
//  DataRepository.swift
//  gym app
//
//  Main repository coordinator - delegates to entity-specific repositories
//  Maintains @Published arrays for SwiftUI binding and coordinates cloud sync
//

import CoreData
import Combine

@preconcurrency @MainActor
class DataRepository: ObservableObject {
    static let shared = DataRepository()

    // Sub-repositories
    private let moduleRepo: ModuleRepository
    private let workoutRepo: WorkoutRepository
    private let sessionRepo: SessionRepository
    private let programRepo: ProgramRepository

    // Services
    private let persistence = PersistenceController.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let deletionTracker = DeletionTracker.shared
    private let logger = SyncLogger.shared

    // Published state for SwiftUI
    @Published var modules: [Module] = []
    @Published var workouts: [Workout] = []
    @Published var sessions: [Session] = []
    @Published var programs: [Program] = []
    @Published var isSyncing = false

    // Session pagination state (delegated from SessionRepository)
    @Published private(set) var isLoadingMoreSessions = false
    @Published private(set) var hasMoreSessions = true

    init() {
        moduleRepo = ModuleRepository()
        workoutRepo = WorkoutRepository()
        sessionRepo = SessionRepository()
        programRepo = ProgramRepository()
        loadAllData()
    }

    // MARK: - Load All Data

    func loadAllData() {
        loadModules()
        loadWorkouts()
        loadSessions()
        loadPrograms()
    }

    // MARK: - Module Operations

    func loadModules() {
        modules = moduleRepo.loadAll()
    }

    func saveModule(_ module: Module) {
        moduleRepo.save(module)
        loadModules()

        if authService.isAuthenticated {
            Task {
                do {
                    try await firestoreService.saveModule(module)
                } catch {
                    Logger.error(error, context: "saveModule cloud sync")
                }
            }
        }
    }

    func deleteModule(_ module: Module) {
        moduleRepo.delete(module)
        loadModules()

        deletionTracker.recordDeletion(entityType: .module, entityId: module.id)
        logger.info("Deleted module '\(module.name)' (id: \(module.id))", context: "deleteModule")

        if authService.isAuthenticated {
            SyncManager.shared.queueModule(module, action: .delete)
        }
    }

    func getModule(id: UUID) -> Module? {
        modules.first { $0.id == id }
    }

    // MARK: - Workout Operations

    func loadWorkouts() {
        workouts = workoutRepo.loadAll()
    }

    func saveWorkout(_ workout: Workout) {
        workoutRepo.save(workout)
        loadWorkouts()

        if authService.isAuthenticated {
            Task {
                do {
                    try await firestoreService.saveWorkout(workout)
                } catch {
                    Logger.error(error, context: "saveWorkout cloud sync")
                }
            }
        }
    }

    func deleteWorkout(_ workout: Workout) {
        workoutRepo.delete(workout)
        loadWorkouts()

        deletionTracker.recordDeletion(entityType: .workout, entityId: workout.id)
        logger.info("Deleted workout '\(workout.name)' (id: \(workout.id))", context: "deleteWorkout")

        if authService.isAuthenticated {
            SyncManager.shared.queueWorkout(workout, action: .delete)
        }
    }

    func getWorkout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    // MARK: - Session Operations

    func loadSessions() {
        sessions = sessionRepo.loadRecent()
        hasMoreSessions = sessionRepo.hasMore
    }

    func loadMoreSessions() {
        guard !isLoadingMoreSessions, hasMoreSessions else { return }
        isLoadingMoreSessions = true
        _ = sessionRepo.loadMore(currentSessions: &sessions)
        hasMoreSessions = sessionRepo.hasMore
        isLoadingMoreSessions = false
    }

    func loadAllSessions() {
        sessions = sessionRepo.loadAll()
        hasMoreSessions = false
    }

    func saveSession(_ session: Session) {
        sessionRepo.save(session)
        loadSessions()

        if authService.isAuthenticated {
            Task {
                do {
                    try await firestoreService.saveSession(session)
                } catch {
                    Logger.error(error, context: "saveSession cloud sync")
                }
            }
        }
    }

    func deleteSession(_ session: Session) {
        sessionRepo.delete(session)
        loadSessions()

        deletionTracker.recordDeletion(entityType: .session, entityId: session.id)
        logger.info("Deleted session (id: \(session.id))", context: "deleteSession")

        if authService.isAuthenticated {
            SyncManager.shared.queueSession(session, action: .delete)
        }
    }

    func getSessions(for workoutId: UUID) -> [Session] {
        sessions.filter { $0.workoutId == workoutId }
    }

    func getRecentSessions(limit: Int = 10) -> [Session] {
        Array(sessions.prefix(limit))
    }

    func getTotalSessionCount() -> Int {
        sessionRepo.getTotalCount()
    }

    func getExerciseHistory(exerciseName: String, limit: Int? = nil) -> [SessionExercise] {
        sessionRepo.getExerciseHistory(exerciseName: exerciseName, limit: limit)
    }

    func getLastProgressionRecommendation(exerciseName: String) -> (recommendation: ProgressionRecommendation, date: Date)? {
        sessionRepo.getLastProgressionRecommendation(exerciseName: exerciseName, loadedSessions: sessions)
    }

    // MARK: - Program Operations

    func loadPrograms() {
        programs = programRepo.loadAll()
    }

    func saveProgram(_ program: Program) {
        programRepo.save(program)
        loadPrograms()

        if authService.isAuthenticated {
            Task {
                do {
                    try await firestoreService.saveProgram(program)
                } catch {
                    Logger.error(error, context: "saveProgram cloud sync")
                }
            }
        }
    }

    func deleteProgram(_ program: Program) {
        programRepo.delete(program)
        loadPrograms()

        deletionTracker.recordDeletion(entityType: .program, entityId: program.id)
        logger.info("Deleted program '\(program.name)' (id: \(program.id))", context: "deleteProgram")

        if authService.isAuthenticated {
            SyncManager.shared.queueProgram(program, action: .delete)
        }
    }

    func getProgram(id: UUID) -> Program? {
        programs.first { $0.id == id }
    }

    func getActiveProgram() -> Program? {
        programs.first { $0.isActive }
    }

    // MARK: - ExerciseInstance Operations

    func resolveExercises(for module: Module) -> [ResolvedExercise] {
        ExerciseResolver.shared.resolve(module.exercises)
    }

    func resolveExercisesGrouped(for module: Module) -> [[ResolvedExercise]] {
        ExerciseResolver.shared.resolveGrouped(module.exercises)
    }

    // MARK: - In-Progress Session Recovery

    func saveInProgressSession(_ session: Session) {
        sessionRepo.saveInProgress(session)
    }

    func loadInProgressSession() -> Session? {
        sessionRepo.loadInProgress()
    }

    func getInProgressSessionInfo() -> (workoutName: String, startTime: Date, lastUpdated: Date)? {
        sessionRepo.getInProgressInfo()
    }

    func clearInProgressSession() {
        sessionRepo.clearInProgress()
    }

    // MARK: - Cloud Sync

    func syncFromCloud() async {
        guard authService.isAuthenticated else {
            logger.info("Not authenticated, skipping", context: "syncFromCloud")
            return
        }

        logger.info("Starting sync...", context: "syncFromCloud")
        isSyncing = true

        let timer = PerformanceTimer("syncFromCloud", threshold: AppConfig.slowSyncThreshold)

        do {
            // 0. One-time migration from legacy exerciseLibrary to customExercises
            let migratedCount = try await firestoreService.migrateExerciseLibraryToCustomExercises()
            if migratedCount > 0 {
                logger.info("Migrated \(migratedCount) exercises from legacy exerciseLibrary", context: "syncFromCloud")
            }

            // 1. Fetch and apply cloud deletions first
            await syncDeletionsFromCloud()

            let cloudData = try await firestoreService.fetchAllUserData()
            logger.info("Fetched \(cloudData.modules.count) modules, \(cloudData.workouts.count) workouts, \(cloudData.sessions.count) sessions, \(cloudData.programs.count) programs", context: "syncFromCloud")

            // 2. Push our deletions to cloud
            await pushDeletionsToCloud()

            // Merge cloud modules
            mergeCloudModules(cloudData.modules)

            // Extract custom exercises from module data
            extractCustomExercises(from: cloudData.modules)

            // Merge cloud workouts
            mergeCloudWorkouts(cloudData.workouts)

            // Merge cloud sessions
            mergeCloudSessions(cloudData.sessions)

            // Merge custom exercises
            mergeCustomExercises(cloudData.exercises)

            // Merge cloud programs
            mergeCloudPrograms(cloudData.programs)

            // Merge cloud scheduled workouts
            NotificationCenter.default.post(
                name: .scheduledWorkoutsSyncedFromCloud,
                object: cloudData.scheduledWorkouts
            )

            // Merge user profile
            if let cloudProfile = cloudData.profile {
                NotificationCenter.default.post(
                    name: .userProfileSyncedFromCloud,
                    object: cloudProfile
                )
            }

            // Reload all data after merge
            loadAllData()

            // Cleanup old deletion records (30 days)
            deletionTracker.cleanupOldRecords()
            await cleanupOldDeletionsFromCloud()

            logger.info("Sync completed successfully", context: "syncFromCloud")
        } catch {
            logger.logError(error, context: "syncFromCloud", additionalInfo: "Sync failed")
        }

        timer.stop()
        isSyncing = false
    }

    func syncFromCloudThrowing() async throws {
        guard authService.isAuthenticated else {
            logger.info("Not authenticated, skipping", context: "syncFromCloudThrowing")
            return
        }

        logger.info("Starting sync...", context: "syncFromCloudThrowing")
        isSyncing = true

        let timer = PerformanceTimer("syncFromCloudThrowing", threshold: AppConfig.slowSyncThreshold)

        defer {
            timer.stop()
            isSyncing = false
        }

        await syncDeletionsFromCloud()

        let cloudData = try await firestoreService.fetchAllUserData()
        logger.info("Fetched \(cloudData.modules.count) modules, \(cloudData.workouts.count) workouts, \(cloudData.sessions.count) sessions, \(cloudData.programs.count) programs", context: "syncFromCloudThrowing")

        await pushDeletionsToCloud()

        mergeCloudModules(cloudData.modules)
        extractCustomExercises(from: cloudData.modules)
        mergeCloudWorkouts(cloudData.workouts)
        mergeCloudSessions(cloudData.sessions)
        mergeCustomExercises(cloudData.exercises)
        mergeCloudPrograms(cloudData.programs)

        NotificationCenter.default.post(
            name: .scheduledWorkoutsSyncedFromCloud,
            object: cloudData.scheduledWorkouts
        )

        if let cloudProfile = cloudData.profile {
            NotificationCenter.default.post(
                name: .userProfileSyncedFromCloud,
                object: cloudProfile
            )
        }

        loadAllData()

        deletionTracker.cleanupOldRecords()
        await cleanupOldDeletionsFromCloud()

        logger.info("Sync completed successfully", context: "syncFromCloudThrowing")
    }

    func pushAllToCloud() async {
        guard authService.isAuthenticated else {
            Logger.debug("pushAllToCloud: Not authenticated, skipping")
            return
        }

        Logger.debug("pushAllToCloud: Starting - \(modules.count) modules, \(workouts.count) workouts, \(sessions.count) sessions, \(programs.count) programs")
        isSyncing = true

        let timer = PerformanceTimer("pushAllToCloud", threshold: AppConfig.slowSyncThreshold)

        do {
            for module in modules {
                try await firestoreService.saveModule(module)
            }

            for workout in workouts {
                try await firestoreService.saveWorkout(workout)
            }

            for session in sessions {
                try await firestoreService.saveSession(session)
            }

            let customLibrary = CustomExerciseLibrary.shared
            for exercise in customLibrary.exercises {
                try await firestoreService.saveCustomExercise(exercise)
            }

            for program in programs {
                try await firestoreService.saveProgram(program)
            }

            NotificationCenter.default.post(name: .requestScheduledWorkoutsForSync, object: nil)
            NotificationCenter.default.post(name: .requestUserProfileForSync, object: nil)

            Logger.debug("pushAllToCloud: Completed successfully")
        } catch {
            Logger.error(error, context: "pushAllToCloud")
        }

        timer.stop()
        isSyncing = false
    }

    func pushAllToCloudThrowing() async throws {
        guard authService.isAuthenticated else {
            Logger.debug("pushAllToCloudThrowing: Not authenticated, skipping")
            return
        }

        Logger.debug("pushAllToCloudThrowing: Starting - \(modules.count) modules, \(workouts.count) workouts, \(sessions.count) sessions, \(programs.count) programs")
        isSyncing = true

        let timer = PerformanceTimer("pushAllToCloudThrowing", threshold: AppConfig.slowSyncThreshold)

        defer {
            timer.stop()
            isSyncing = false
        }

        for module in modules {
            try await firestoreService.saveModule(module)
        }

        for workout in workouts {
            try await firestoreService.saveWorkout(workout)
        }

        for session in sessions {
            try await firestoreService.saveSession(session)
        }

        let customLibrary = CustomExerciseLibrary.shared
        for exercise in customLibrary.exercises {
            try await firestoreService.saveCustomExercise(exercise)
        }

        for program in programs {
            try await firestoreService.saveProgram(program)
        }

        NotificationCenter.default.post(name: .requestScheduledWorkoutsForSync, object: nil)
        NotificationCenter.default.post(name: .requestUserProfileForSync, object: nil)

        Logger.debug("pushAllToCloudThrowing: Completed successfully")
    }

    // MARK: - Private Sync Helpers

    private func mergeCloudModules(_ cloudModules: [Module]) {
        let deletedModuleIds = deletionTracker.getDeletedIds(entityType: .module)
        logger.info("Local modules: \(modules.count), deletions tracked: \(deletedModuleIds.count)", context: "syncFromCloud")

        for cloudModule in cloudModules {
            if deletionTracker.wasDeletedAfter(entityType: .module, entityId: cloudModule.id, date: cloudModule.updatedAt) {
                logger.info("Module '\(cloudModule.name)' was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                continue
            }

            if deletedModuleIds.contains(cloudModule.id) {
                logger.info("Module '\(cloudModule.name)' was deleted locally, skipping", context: "syncFromCloud")
                continue
            }

            if let local = modules.first(where: { $0.id == cloudModule.id }) {
                let mergedModule = local.mergedWith(cloudModule)
                if local.needsSync(comparedTo: mergedModule) {
                    logger.info("Deep merging module '\(cloudModule.name)'", context: "syncFromCloud")
                    moduleRepo.save(mergedModule)
                }
            } else {
                logger.info("Module '\(cloudModule.name)' is new, saving locally", context: "syncFromCloud")
                moduleRepo.save(cloudModule)
            }
        }
    }

    private func extractCustomExercises(from cloudModules: [Module]) {
        let builtInLibrary = ExerciseLibrary.shared
        let customLibrary = CustomExerciseLibrary.shared
        let deletedCustomExerciseIds = deletionTracker.getDeletedIds(entityType: .customExercise)
        var extractedCount = 0

        for cloudModule in cloudModules {
            for exerciseInstance in cloudModule.exercises {
                let name = exerciseInstance.name
                let isBuiltInTemplate = exerciseInstance.templateId.flatMap { builtInLibrary.template(id: $0) } != nil
                let isAlreadyCustom = customLibrary.contains(name: name)
                let wasDeletedLocally = exerciseInstance.templateId.map { deletedCustomExerciseIds.contains($0) } ?? false

                if !isBuiltInTemplate && !isAlreadyCustom && !wasDeletedLocally {
                    Logger.debug("Extracting custom exercise '\(name)' from module '\(cloudModule.name)'")
                    customLibrary.addExercise(name: name, exerciseType: exerciseInstance.exerciseType)
                    extractedCount += 1
                }
            }
        }
        Logger.debug("Extracted \(extractedCount) custom exercises from module data")
    }

    private func mergeCloudWorkouts(_ cloudWorkouts: [Workout]) {
        let deletedWorkoutIds = deletionTracker.getDeletedIds(entityType: .workout)
        logger.info("Local workouts: \(workouts.count), deletions tracked: \(deletedWorkoutIds.count)", context: "syncFromCloud")

        for cloudWorkout in cloudWorkouts {
            if deletionTracker.wasDeletedAfter(entityType: .workout, entityId: cloudWorkout.id, date: cloudWorkout.updatedAt) {
                logger.info("Workout '\(cloudWorkout.name)' was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                continue
            }

            if deletedWorkoutIds.contains(cloudWorkout.id) {
                logger.info("Workout '\(cloudWorkout.name)' was deleted locally, skipping", context: "syncFromCloud")
                continue
            }

            if let local = workouts.first(where: { $0.id == cloudWorkout.id }) {
                let mergedWorkout = local.mergedWith(cloudWorkout)
                if local.needsSync(comparedTo: mergedWorkout) {
                    logger.info("Deep merging workout '\(cloudWorkout.name)'", context: "syncFromCloud")
                    workoutRepo.save(mergedWorkout)
                }
            } else {
                logger.info("Workout '\(cloudWorkout.name)' is new, saving locally", context: "syncFromCloud")
                workoutRepo.save(cloudWorkout)
            }
        }
    }

    private func mergeCloudSessions(_ cloudSessions: [Session]) {
        let deletedSessionIds = deletionTracker.getDeletedIds(entityType: .session)
        logger.info("Local sessions: \(sessions.count), deletions tracked: \(deletedSessionIds.count)", context: "syncFromCloud")

        for cloudSession in cloudSessions {
            if deletionTracker.wasDeletedAfter(entityType: .session, entityId: cloudSession.id, date: cloudSession.date) {
                logger.info("Session was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                continue
            }

            if deletedSessionIds.contains(cloudSession.id) {
                continue
            }

            if !sessions.contains(where: { $0.id == cloudSession.id }) {
                sessionRepo.save(cloudSession)
            }
        }
    }

    private func mergeCustomExercises(_ cloudExercises: [ExerciseTemplate]) {
        let customLibrary = CustomExerciseLibrary.shared
        let deletedCustomExerciseIds = deletionTracker.getDeletedIds(entityType: .customExercise)
        Logger.verbose("Custom exercises - cloud: \(cloudExercises.count), local: \(customLibrary.exercises.count)")

        for cloudExercise in cloudExercises {
            if deletedCustomExerciseIds.contains(cloudExercise.id) {
                Logger.debug("Skipping custom exercise '\(cloudExercise.name)' - was deleted locally")
                continue
            }

            if !customLibrary.exercises.contains(where: { $0.id == cloudExercise.id }) {
                Logger.debug("Adding custom exercise '\(cloudExercise.name)'")
                customLibrary.addExercise(cloudExercise)
            }
        }
        Logger.debug("After sync, local custom exercises: \(customLibrary.exercises.count)")
    }

    private func mergeCloudPrograms(_ cloudPrograms: [Program]) {
        let deletedProgramIds = deletionTracker.getDeletedIds(entityType: .program)
        logger.info("Local programs: \(programs.count), deletions tracked: \(deletedProgramIds.count)", context: "syncFromCloud")

        for cloudProgram in cloudPrograms {
            if deletionTracker.wasDeletedAfter(entityType: .program, entityId: cloudProgram.id, date: cloudProgram.updatedAt) {
                logger.info("Program '\(cloudProgram.name)' was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                continue
            }

            if deletedProgramIds.contains(cloudProgram.id) {
                logger.info("Program '\(cloudProgram.name)' was deleted locally, skipping", context: "syncFromCloud")
                continue
            }

            if let local = programs.first(where: { $0.id == cloudProgram.id }) {
                if cloudProgram.updatedAt >= local.updatedAt {
                    logger.info("Cloud program '\(cloudProgram.name)' is newer, updating local", context: "syncFromCloud")
                    programRepo.save(cloudProgram)
                }
            } else {
                logger.info("Program '\(cloudProgram.name)' is new, saving locally", context: "syncFromCloud")
                programRepo.save(cloudProgram)
            }
        }
    }

    // MARK: - Deletion Sync

    private func syncDeletionsFromCloud() async {
        do {
            let cloudDeletions = try await firestoreService.fetchDeletionRecords()
            logger.info("Fetched \(cloudDeletions.count) deletion records from cloud", context: "syncDeletionsFromCloud")

            for deletion in cloudDeletions {
                deletionTracker.importFromCloud(deletion)
                applyDeletionLocally(deletion)
            }
        } catch {
            logger.logError(error, context: "syncDeletionsFromCloud", additionalInfo: "Failed to fetch deletions")
        }
    }

    private func applyDeletionLocally(_ deletion: DeletionRecord) {
        switch deletion.entityType {
        case .module:
            if let entity = moduleRepo.findEntity(id: deletion.entityId) {
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local module updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                moduleRepo.deleteEntity(id: deletion.entityId)
                logger.info("Applied cloud deletion for module \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .workout:
            if let entity = workoutRepo.findEntity(id: deletion.entityId) {
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local workout updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                workoutRepo.deleteEntity(id: deletion.entityId)
                logger.info("Applied cloud deletion for workout \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .program:
            if let entity = programRepo.findEntity(id: deletion.entityId) {
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local program updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                programRepo.deleteEntity(id: deletion.entityId)
                logger.info("Applied cloud deletion for program \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .session:
            if sessionRepo.findEntity(id: deletion.entityId) != nil {
                sessionRepo.deleteEntity(id: deletion.entityId)
                logger.info("Applied cloud deletion for session \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .scheduledWorkout:
            NotificationCenter.default.post(
                name: .deletionRecordSyncedFromCloud,
                object: deletion
            )
        case .customExercise:
            let customLibrary = CustomExerciseLibrary.shared
            if let exercise = customLibrary.exercises.first(where: { $0.id == deletion.entityId }) {
                customLibrary.deleteExercise(exercise)
                logger.info("Applied cloud deletion for custom exercise \(deletion.entityId)", context: "applyDeletionLocally")
            }
        }
    }

    private func pushDeletionsToCloud() async {
        let unsyncedDeletions = deletionTracker.getUnsyncedDeletions()
        guard !unsyncedDeletions.isEmpty else { return }

        logger.info("Pushing \(unsyncedDeletions.count) deletion records to cloud", context: "pushDeletionsToCloud")

        do {
            try await firestoreService.saveDeletionRecords(unsyncedDeletions)

            for deletion in unsyncedDeletions {
                deletionTracker.markAsSynced(entityType: deletion.entityType, entityId: deletion.entityId)
            }
        } catch {
            logger.logError(error, context: "pushDeletionsToCloud", additionalInfo: "Failed to push deletions")
        }
    }

    private func cleanupOldDeletionsFromCloud() async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        do {
            let cleanedCount = try await firestoreService.cleanupOldDeletionRecords(olderThan: cutoffDate)
            if cleanedCount > 0 {
                logger.info("Cleaned up \(cleanedCount) old deletion records from cloud", context: "cleanupOldDeletionsFromCloud")
            }
        } catch {
            logger.logError(error, context: "cleanupOldDeletionsFromCloud", additionalInfo: "Failed to cleanup")
        }
    }
}
