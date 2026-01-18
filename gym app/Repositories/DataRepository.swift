//
//  DataRepository.swift
//  gym app
//
//  Main repository for data access - handles conversion between CoreData and Swift models
//

import CoreData
import Combine

@preconcurrency @MainActor
class DataRepository: ObservableObject {
    static let shared = DataRepository()

    private let persistence = PersistenceController.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let deletionTracker = DeletionTracker.shared
    private let logger = SyncLogger.shared

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published var modules: [Module] = []
    @Published var workouts: [Workout] = []
    @Published var sessions: [Session] = []
    @Published var programs: [Program] = []
    @Published var isSyncing = false

    init() {
        loadAllData()
    }

    // MARK: - Cloud Sync

    /// Sync data from Firestore on app launch (if authenticated)
    func syncFromCloud() async {
        guard authService.isAuthenticated else {
            logger.info("Not authenticated, skipping", context: "syncFromCloud")
            return
        }

        logger.info("Starting sync...", context: "syncFromCloud")
        isSyncing = true

        let timer = PerformanceTimer("syncFromCloud", threshold: AppConfig.slowSyncThreshold)

        do {
            // 1. Fetch and apply cloud deletions first
            await syncDeletionsFromCloud()

            let cloudData = try await firestoreService.fetchAllUserData()
            logger.info("Fetched \(cloudData.modules.count) modules, \(cloudData.workouts.count) workouts, \(cloudData.sessions.count) sessions, \(cloudData.programs.count) programs", context: "syncFromCloud")

            // 2. Push our deletions to cloud
            await pushDeletionsToCloud()

            // Merge cloud modules (with deletion-aware conflict resolution)
            let deletedModuleIds = deletionTracker.getDeletedIds(entityType: .module)
            logger.info("Local modules: \(modules.count), deletions tracked: \(deletedModuleIds.count)", context: "syncFromCloud")
            var totalExercises = 0
            var totalExerciseInstances = 0
            for cloudModule in cloudData.modules {
                totalExercises += cloudModule.exercises.count
                totalExerciseInstances += cloudModule.exerciseInstances.count

                // Skip if deleted locally - check if deletion is newer than cloud edit
                if deletionTracker.wasDeletedAfter(entityType: .module, entityId: cloudModule.id, date: cloudModule.updatedAt) {
                    logger.info("Module '\(cloudModule.name)' was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                    continue
                }

                // Skip if deleted locally (even if deletion is older, to be safe)
                if deletedModuleIds.contains(cloudModule.id) {
                    logger.info("Module '\(cloudModule.name)' was deleted locally, skipping", context: "syncFromCloud")
                    continue
                }

                if let local = modules.first(where: { $0.id == cloudModule.id }) {
                    let mergedModule = local.mergedWith(cloudModule)
                    if local.needsSync(comparedTo: mergedModule) {
                        logger.info("Deep merging module '\(cloudModule.name)'", context: "syncFromCloud")
                        saveModuleLocally(mergedModule)
                    }
                } else {
                    logger.info("Module '\(cloudModule.name)' is new, saving locally", context: "syncFromCloud")
                    saveModuleLocally(cloudModule)
                }
            }

            logger.info("Total exercises: \(totalExercises) legacy, \(totalExerciseInstances) instances", context: "syncFromCloud")

            // Extract custom exercises from module data (for legacy format)
            let builtInLibrary = ExerciseLibrary.shared
            let customLibraryPreExtract = CustomExerciseLibrary.shared
            var extractedCount = 0
            for cloudModule in cloudData.modules {
                for exercise in cloudModule.exercises {
                    // Check if this exercise is NOT in the built-in library and NOT already in custom library
                    let isBuiltIn = builtInLibrary.exercises.contains { $0.name.lowercased() == exercise.name.lowercased() }
                    let isAlreadyCustom = customLibraryPreExtract.contains(name: exercise.name)

                    if !isBuiltIn && !isAlreadyCustom {
                        Logger.debug("Extracting custom exercise '\(exercise.name)' from module '\(cloudModule.name)'")
                        customLibraryPreExtract.addExercise(
                            name: exercise.name,
                            exerciseType: exercise.exerciseType,
                            muscleGroupIds: [],
                            implementIds: []
                        )
                        extractedCount += 1
                    }
                }
            }
            Logger.debug("Extracted \(extractedCount) custom exercises from module data")

            // Merge cloud workouts
            let deletedWorkoutIds = deletionTracker.getDeletedIds(entityType: .workout)
            logger.info("Local workouts: \(workouts.count), deletions tracked: \(deletedWorkoutIds.count)", context: "syncFromCloud")
            for cloudWorkout in cloudData.workouts {
                // Skip if deleted locally after cloud edit
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
                        saveWorkoutLocally(mergedWorkout)
                    }
                } else {
                    logger.info("Workout '\(cloudWorkout.name)' is new, saving locally", context: "syncFromCloud")
                    saveWorkoutLocally(cloudWorkout)
                }
            }

            // Merge cloud sessions
            let deletedSessionIds = deletionTracker.getDeletedIds(entityType: .session)
            logger.info("Local sessions: \(sessions.count), deletions tracked: \(deletedSessionIds.count)", context: "syncFromCloud")
            for cloudSession in cloudData.sessions {
                // Skip if deleted locally after cloud edit
                if deletionTracker.wasDeletedAfter(entityType: .session, entityId: cloudSession.id, date: cloudSession.date) {
                    logger.info("Session was deleted locally after cloud edit, skipping", context: "syncFromCloud")
                    continue
                }

                if deletedSessionIds.contains(cloudSession.id) {
                    continue
                }

                if !sessions.contains(where: { $0.id == cloudSession.id }) {
                    saveSessionLocally(cloudSession)
                }
            }

            // Merge custom exercises
            let customLibrary = CustomExerciseLibrary.shared
            Logger.verbose("Custom exercises - cloud: \(cloudData.exercises.count), local: \(customLibrary.exercises.count)")
            for cloudExercise in cloudData.exercises {
                Logger.verbose("Processing custom exercise '\(cloudExercise.name)'")
                if !customLibrary.exercises.contains(where: { $0.id == cloudExercise.id }) {
                    Logger.debug("Adding custom exercise '\(cloudExercise.name)'")
                    customLibrary.addExercise(cloudExercise)
                } else {
                    Logger.verbose("Custom exercise '\(cloudExercise.name)' already exists locally")
                }
            }
            Logger.debug("After sync, local custom exercises: \(customLibrary.exercises.count)")

            // Merge cloud programs
            let deletedProgramIds = deletionTracker.getDeletedIds(entityType: .program)
            logger.info("Local programs: \(programs.count), deletions tracked: \(deletedProgramIds.count)", context: "syncFromCloud")
            for cloudProgram in cloudData.programs {
                // Skip if deleted locally after cloud edit
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
                        saveProgramLocally(cloudProgram)
                    }
                } else {
                    logger.info("Program '\(cloudProgram.name)' is new, saving locally", context: "syncFromCloud")
                    saveProgramLocally(cloudProgram)
                }
            }

            // Merge cloud scheduled workouts
            // Note: This needs to notify WorkoutViewModel to update its local storage
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

    // MARK: - Deletion Sync

    /// Fetch deletion records from cloud and apply them locally
    private func syncDeletionsFromCloud() async {
        do {
            let cloudDeletions = try await firestoreService.fetchDeletionRecords()
            logger.info("Fetched \(cloudDeletions.count) deletion records from cloud", context: "syncDeletionsFromCloud")

            for deletion in cloudDeletions {
                // Import to local tracker
                deletionTracker.importFromCloud(deletion)

                // Apply the deletion locally if the entity exists
                applyDeletionLocally(deletion)
            }
        } catch {
            logger.logError(error, context: "syncDeletionsFromCloud", additionalInfo: "Failed to fetch deletions")
        }
    }

    /// Apply a deletion record by removing the local entity
    private func applyDeletionLocally(_ deletion: DeletionRecord) {
        switch deletion.entityType {
        case .module:
            if let entity = findModuleEntity(id: deletion.entityId) {
                // Check if local module was updated after the deletion
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local module updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                viewContext.delete(entity)
                save()
                logger.info("Applied cloud deletion for module \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .workout:
            if let entity = findWorkoutEntity(id: deletion.entityId) {
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local workout updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                viewContext.delete(entity)
                save()
                logger.info("Applied cloud deletion for workout \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .program:
            if let entity = findProgramEntity(id: deletion.entityId) {
                if let updatedAt = entity.updatedAt, updatedAt > deletion.deletedAt {
                    logger.info("Local program updated after deletion, keeping it", context: "applyDeletionLocally")
                    return
                }
                viewContext.delete(entity)
                save()
                logger.info("Applied cloud deletion for program \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .session:
            if let entity = findSessionEntity(id: deletion.entityId) {
                viewContext.delete(entity)
                save()
                logger.info("Applied cloud deletion for session \(deletion.entityId)", context: "applyDeletionLocally")
            }
        case .scheduledWorkout:
            // Handled by WorkoutViewModel
            NotificationCenter.default.post(
                name: .deletionRecordSyncedFromCloud,
                object: deletion
            )
        case .customExercise:
            // Handled by CustomExerciseLibrary
            let customLibrary = CustomExerciseLibrary.shared
            if let exercise = customLibrary.exercises.first(where: { $0.id == deletion.entityId }) {
                customLibrary.deleteExercise(exercise)
                logger.info("Applied cloud deletion for custom exercise \(deletion.entityId)", context: "applyDeletionLocally")
            }
        }
    }

    /// Push local deletion records to cloud
    private func pushDeletionsToCloud() async {
        let unsyncedDeletions = deletionTracker.getUnsyncedDeletions()
        guard !unsyncedDeletions.isEmpty else { return }

        logger.info("Pushing \(unsyncedDeletions.count) deletion records to cloud", context: "pushDeletionsToCloud")

        do {
            try await firestoreService.saveDeletionRecords(unsyncedDeletions)

            // Mark as synced
            for deletion in unsyncedDeletions {
                deletionTracker.markAsSynced(entityType: deletion.entityType, entityId: deletion.entityId)
            }
        } catch {
            logger.logError(error, context: "pushDeletionsToCloud", additionalInfo: "Failed to push deletions")
        }
    }

    /// Cleanup old deletion records from cloud (30 days)
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

    /// Push all local data to cloud (useful for initial sync after sign-in)
    func pushAllToCloud() async {
        guard authService.isAuthenticated else {
            Logger.debug("pushAllToCloud: Not authenticated, skipping")
            return
        }

        Logger.debug("pushAllToCloud: Starting - \(modules.count) modules, \(workouts.count) workouts, \(sessions.count) sessions, \(programs.count) programs")
        isSyncing = true

        let timer = PerformanceTimer("pushAllToCloud", threshold: AppConfig.slowSyncThreshold)

        do {
            // Push all modules
            for module in modules {
                Logger.verbose("Saving module '\(module.name)'")
                try await firestoreService.saveModule(module)
            }

            // Push all workouts
            for workout in workouts {
                Logger.verbose("Saving workout '\(workout.name)'")
                try await firestoreService.saveWorkout(workout)
            }

            // Push all sessions
            for session in sessions {
                Logger.verbose("Saving session \(Logger.redactUUID(session.id))")
                try await firestoreService.saveSession(session)
            }

            // Push custom exercises
            let customLibrary = CustomExerciseLibrary.shared
            for exercise in customLibrary.exercises {
                Logger.verbose("Saving custom exercise '\(exercise.name)'")
                try await firestoreService.saveCustomExercise(exercise)
            }

            // Push all programs
            for program in programs {
                Logger.verbose("Saving program '\(program.name)'")
                try await firestoreService.saveProgram(program)
            }

            // Request scheduled workouts from WorkoutViewModel and push them
            NotificationCenter.default.post(name: .requestScheduledWorkoutsForSync, object: nil)

            // Push user profile
            NotificationCenter.default.post(name: .requestUserProfileForSync, object: nil)

            Logger.debug("pushAllToCloud: Completed successfully")
        } catch {
            Logger.error(error, context: "pushAllToCloud")
        }

        timer.stop()
        isSyncing = false
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
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ModuleEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            modules = entities.map { convertToModule($0) }
        } catch {
            Logger.error(error, context: "loadModules")
        }
    }

    func saveModule(_ module: Module) {
        saveModuleLocally(module)

        // Sync to cloud if authenticated
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

    /// Save module to CoreData only (used during cloud sync to avoid loops)
    private func saveModuleLocally(_ module: Module) {
        Logger.verbose("Saving module '\(module.name)' locally")
        let entity = findOrCreateModuleEntity(id: module.id)
        updateModuleEntity(entity, from: module)
        save()
        loadModules()
        Logger.verbose("Modules count after reload: \(modules.count)")
    }

    func deleteModule(_ module: Module) {
        if let entity = findModuleEntity(id: module.id) {
            viewContext.delete(entity)
            save()
            loadModules()

            // Track this deletion using DeletionTracker
            deletionTracker.recordDeletion(entityType: .module, entityId: module.id)
            logger.info("Deleted module '\(module.name)' (id: \(module.id))", context: "deleteModule")

            // Queue deletion for cloud sync if authenticated
            if authService.isAuthenticated {
                // Queue the deletion - SyncManager will handle online/offline
                SyncManager.shared.queueModule(module, action: .delete)
            }
        }
    }

    func getModule(id: UUID) -> Module? {
        modules.first { $0.id == id }
    }

    // MARK: - Workout Operations

    func loadWorkouts() {
        let request = NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutEntity.name, ascending: true)]
        request.predicate = NSPredicate(format: "archived == NO")

        do {
            let entities = try viewContext.fetch(request)
            workouts = entities.map { convertToWorkout($0) }
        } catch {
            Logger.error(error, context: "loadWorkouts")
        }
    }

    func saveWorkout(_ workout: Workout) {
        saveWorkoutLocally(workout)

        // Sync to cloud if authenticated
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

    /// Save workout to CoreData only (used during cloud sync to avoid loops)
    private func saveWorkoutLocally(_ workout: Workout) {
        let entity = findOrCreateWorkoutEntity(id: workout.id)
        updateWorkoutEntity(entity, from: workout)
        save()
        loadWorkouts()
    }

    func deleteWorkout(_ workout: Workout) {
        if let entity = findWorkoutEntity(id: workout.id) {
            viewContext.delete(entity)
            save()
            loadWorkouts()

            // Track this deletion using DeletionTracker
            deletionTracker.recordDeletion(entityType: .workout, entityId: workout.id)
            logger.info("Deleted workout '\(workout.name)' (id: \(workout.id))", context: "deleteWorkout")

            // Queue deletion for cloud sync if authenticated
            if authService.isAuthenticated {
                SyncManager.shared.queueWorkout(workout, action: .delete)
            }
        }
    }

    func getWorkout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    // MARK: - Session Operations

    func loadSessions() {
        let request = NSFetchRequest<SessionEntity>(entityName: "SessionEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionEntity.date, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            sessions = entities.map { convertToSession($0) }
        } catch {
            Logger.error(error, context: "loadSessions")
        }
    }

    func saveSession(_ session: Session) {
        saveSessionLocally(session)

        // Sync to cloud if authenticated
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

    /// Save session to CoreData only (used during cloud sync to avoid loops)
    private func saveSessionLocally(_ session: Session) {
        let entity = findOrCreateSessionEntity(id: session.id)
        updateSessionEntity(entity, from: session)
        save()
        loadSessions()
    }

    func deleteSession(_ session: Session) {
        if let entity = findSessionEntity(id: session.id) {
            viewContext.delete(entity)
            save()
            loadSessions()

            // Track this deletion using DeletionTracker
            deletionTracker.recordDeletion(entityType: .session, entityId: session.id)
            logger.info("Deleted session (id: \(session.id))", context: "deleteSession")

            // Queue deletion for cloud sync if authenticated
            if authService.isAuthenticated {
                SyncManager.shared.queueSession(session, action: .delete)
            }
        }
    }

    func getSessions(for workoutId: UUID) -> [Session] {
        sessions.filter { $0.workoutId == workoutId }
    }

    func getRecentSessions(limit: Int = 10) -> [Session] {
        Array(sessions.prefix(limit))
    }

    func getExerciseHistory(exerciseName: String) -> [SessionExercise] {
        sessions.flatMap { session in
            session.completedModules.flatMap { module in
                module.completedExercises.filter { $0.exerciseName == exerciseName }
            }
        }
    }

    /// Get the most recent progression recommendation for an exercise
    func getLastProgressionRecommendation(exerciseName: String) -> (recommendation: ProgressionRecommendation, date: Date)? {
        // Sessions are already sorted by date descending
        for session in sessions {
            for module in session.completedModules {
                if let exercise = module.completedExercises.first(where: { $0.exerciseName == exerciseName }),
                   let recommendation = exercise.progressionRecommendation {
                    return (recommendation, session.date)
                }
            }
        }
        return nil
    }

    // MARK: - Program Operations

    func loadPrograms() {
        let request = NSFetchRequest<ProgramEntity>(entityName: "ProgramEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgramEntity.updatedAt, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            programs = entities.map { convertToProgram($0) }
        } catch {
            Logger.error(error, context: "loadPrograms")
        }
    }

    func saveProgram(_ program: Program) {
        saveProgramLocally(program)

        // Sync to cloud if authenticated
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

    /// Save program to CoreData only (used during cloud sync to avoid loops)
    private func saveProgramLocally(_ program: Program) {
        let entity = findOrCreateProgramEntity(id: program.id)
        updateProgramEntity(entity, from: program)
        save()
        loadPrograms()
    }

    func deleteProgram(_ program: Program) {
        if let entity = findProgramEntity(id: program.id) {
            viewContext.delete(entity)
            save()
            loadPrograms()

            // Track this deletion using DeletionTracker
            deletionTracker.recordDeletion(entityType: .program, entityId: program.id)
            logger.info("Deleted program '\(program.name)' (id: \(program.id))", context: "deleteProgram")

            // Queue deletion for cloud sync if authenticated
            if authService.isAuthenticated {
                SyncManager.shared.queueProgram(program, action: .delete)
            }
        }
    }

    func getProgram(id: UUID) -> Program? {
        programs.first { $0.id == id }
    }

    func getActiveProgram() -> Program? {
        programs.first { $0.isActive }
    }

    // MARK: - ExerciseInstance Operations

    /// Resolves exercise instances for a module using ExerciseResolver
    func resolveExercises(for module: Module) -> [ResolvedExercise] {
        ExerciseResolver.shared.resolve(module.exerciseInstances)
    }

    /// Resolves exercise instances grouped by superset
    func resolveExercisesGrouped(for module: Module) -> [[ResolvedExercise]] {
        ExerciseResolver.shared.resolveGrouped(module.exerciseInstances)
    }

    /// Converts ExerciseInstance entities from CoreData to model objects
    private func convertExerciseInstanceEntities(_ entities: [ExerciseInstanceEntity]) -> [ExerciseInstance] {
        entities.map { instanceEntity in
            let setGroups = instanceEntity.setGroupArray.map { sgEntity in
                SetGroup(
                    id: sgEntity.id,
                    sets: Int(sgEntity.sets),
                    targetReps: sgEntity.targetReps > 0 ? Int(sgEntity.targetReps) : nil,
                    targetWeight: sgEntity.targetWeight > 0 ? sgEntity.targetWeight : nil,
                    targetRPE: sgEntity.targetRPE > 0 ? Int(sgEntity.targetRPE) : nil,
                    targetDuration: sgEntity.targetDuration > 0 ? Int(sgEntity.targetDuration) : nil,
                    targetDistance: sgEntity.targetDistance > 0 ? sgEntity.targetDistance : nil,
                    targetHoldTime: sgEntity.targetHoldTime > 0 ? Int(sgEntity.targetHoldTime) : nil,
                    restPeriod: sgEntity.restPeriod > 0 ? Int(sgEntity.restPeriod) : nil,
                    notes: sgEntity.notes,
                    isInterval: sgEntity.isInterval,
                    workDuration: sgEntity.workDuration > 0 ? Int(sgEntity.workDuration) : nil,
                    intervalRestDuration: sgEntity.intervalRestDuration > 0 ? Int(sgEntity.intervalRestDuration) : nil,
                    implementMeasurableLabel: sgEntity.implementMeasurableLabel,
                    implementMeasurableUnit: sgEntity.implementMeasurableUnit,
                    implementMeasurableValue: sgEntity.implementMeasurableValue > 0 ? sgEntity.implementMeasurableValue : nil,
                    implementMeasurableStringValue: sgEntity.implementMeasurableStringValue
                )
            }

            return ExerciseInstance(
                id: instanceEntity.id,
                templateId: instanceEntity.templateId,
                setGroups: setGroups,
                supersetGroupId: instanceEntity.supersetGroupId,
                order: Int(instanceEntity.orderIndex),
                notes: instanceEntity.notes,
                nameOverride: instanceEntity.nameOverride,
                exerciseTypeOverride: instanceEntity.exerciseTypeOverride,
                createdAt: instanceEntity.createdAt ?? Date(),
                updatedAt: instanceEntity.updatedAt ?? Date()
            )
        }
    }

    /// Creates ExerciseInstance entities for a module
    private func createExerciseInstanceEntities(
        from instances: [ExerciseInstance],
        for moduleEntity: ModuleEntity
    ) -> [ExerciseInstanceEntity] {
        instances.enumerated().map { index, instance in
            let instanceEntity = ExerciseInstanceEntity(context: viewContext)
            instanceEntity.id = instance.id
            instanceEntity.templateId = instance.templateId
            instanceEntity.supersetGroupId = instance.supersetGroupId
            instanceEntity.notes = instance.notes
            instanceEntity.orderIndex = Int32(index)
            instanceEntity.createdAt = instance.createdAt
            instanceEntity.updatedAt = instance.updatedAt
            instanceEntity.nameOverride = instance.nameOverride
            instanceEntity.exerciseTypeOverride = instance.exerciseTypeOverride
            instanceEntity.module = moduleEntity

            // Add set groups
            let setGroupEntities = instance.setGroups.enumerated().map { sgIndex, setGroup in
                let sgEntity = SetGroupEntity(context: viewContext)
                sgEntity.id = setGroup.id
                sgEntity.sets = Int32(setGroup.sets)
                sgEntity.targetReps = Int32(setGroup.targetReps ?? 0)
                sgEntity.targetWeight = setGroup.targetWeight ?? 0
                sgEntity.targetRPE = Int32(setGroup.targetRPE ?? 0)
                sgEntity.targetDuration = Int32(setGroup.targetDuration ?? 0)
                sgEntity.targetDistance = setGroup.targetDistance ?? 0
                sgEntity.targetHoldTime = Int32(setGroup.targetHoldTime ?? 0)
                sgEntity.restPeriod = Int32(setGroup.restPeriod ?? 0)
                sgEntity.notes = setGroup.notes
                sgEntity.orderIndex = Int32(sgIndex)
                sgEntity.exerciseInstance = instanceEntity
                // Interval fields
                sgEntity.isInterval = setGroup.isInterval
                sgEntity.workDuration = Int32(setGroup.workDuration ?? 0)
                sgEntity.intervalRestDuration = Int32(setGroup.intervalRestDuration ?? 0)
                // Implement measurable fields
                sgEntity.implementMeasurableLabel = setGroup.implementMeasurableLabel
                sgEntity.implementMeasurableUnit = setGroup.implementMeasurableUnit
                sgEntity.implementMeasurableValue = setGroup.implementMeasurableValue ?? 0
                sgEntity.implementMeasurableStringValue = setGroup.implementMeasurableStringValue
                return sgEntity
            }
            instanceEntity.setGroups = NSOrderedSet(array: setGroupEntities)
            return instanceEntity
        }
    }

    // MARK: - Private Helpers

    private func save() {
        persistence.save()
    }

    // MARK: - Module Conversion

    private func findModuleEntity(id: UUID) -> ModuleEntity? {
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateModuleEntity(id: UUID) -> ModuleEntity {
        if let existing = findModuleEntity(id: id) {
            return existing
        }
        let entity = ModuleEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateModuleEntity(_ entity: ModuleEntity, from module: Module) {
        entity.name = module.name
        entity.type = module.type
        entity.notes = module.notes
        entity.estimatedDuration = Int32(module.estimatedDuration ?? 0)
        entity.createdAt = module.createdAt
        entity.updatedAt = module.updatedAt
        entity.syncStatus = module.syncStatus

        // Clear existing exercises
        if let existingExercises = entity.exercises {
            for case let exercise as ExerciseEntity in existingExercises {
                viewContext.delete(exercise)
            }
        }

        // Add exercises
        let exerciseEntities = module.exercises.enumerated().map { index, exercise in
            let exerciseEntity = ExerciseEntity(context: viewContext)
            exerciseEntity.id = exercise.id
            exerciseEntity.name = exercise.name
            exerciseEntity.templateId = exercise.templateId
            exerciseEntity.exerciseType = exercise.exerciseType
            exerciseEntity.cardioMetric = exercise.cardioMetric
            exerciseEntity.distanceUnit = exercise.distanceUnit
            exerciseEntity.trackingMetrics = exercise.trackingMetrics
            exerciseEntity.notes = exercise.notes
            exerciseEntity.orderIndex = Int32(index)
            exerciseEntity.createdAt = exercise.createdAt
            exerciseEntity.updatedAt = exercise.updatedAt
            exerciseEntity.module = entity
            // Library system fields
            exerciseEntity.muscleGroupIds = exercise.muscleGroupIds
            exerciseEntity.implementIds = exercise.implementIds

            // Add set groups
            let setGroupEntities = exercise.setGroups.enumerated().map { sgIndex, setGroup in
                let sgEntity = SetGroupEntity(context: viewContext)
                sgEntity.id = setGroup.id
                sgEntity.sets = Int32(setGroup.sets)
                sgEntity.targetReps = Int32(setGroup.targetReps ?? 0)
                sgEntity.targetWeight = setGroup.targetWeight ?? 0
                sgEntity.targetRPE = Int32(setGroup.targetRPE ?? 0)
                sgEntity.targetDuration = Int32(setGroup.targetDuration ?? 0)
                sgEntity.targetDistance = setGroup.targetDistance ?? 0
                sgEntity.targetHoldTime = Int32(setGroup.targetHoldTime ?? 0)
                sgEntity.restPeriod = Int32(setGroup.restPeriod ?? 0)
                sgEntity.notes = setGroup.notes
                sgEntity.orderIndex = Int32(sgIndex)
                sgEntity.exercise = exerciseEntity
                // Interval fields
                sgEntity.isInterval = setGroup.isInterval
                sgEntity.workDuration = Int32(setGroup.workDuration ?? 0)
                sgEntity.intervalRestDuration = Int32(setGroup.intervalRestDuration ?? 0)
                // Implement measurable fields
                sgEntity.implementMeasurableLabel = setGroup.implementMeasurableLabel
                sgEntity.implementMeasurableUnit = setGroup.implementMeasurableUnit
                sgEntity.implementMeasurableValue = setGroup.implementMeasurableValue ?? 0
                sgEntity.implementMeasurableStringValue = setGroup.implementMeasurableStringValue
                return sgEntity
            }
            exerciseEntity.setGroups = NSOrderedSet(array: setGroupEntities)
            return exerciseEntity
        }
        entity.exercises = NSOrderedSet(array: exerciseEntities)

        // Clear existing exercise instances
        if let existingInstances = entity.exerciseInstances {
            for case let instance as ExerciseInstanceEntity in existingInstances {
                viewContext.delete(instance)
            }
        }

        // Add exercise instances (new normalized model)
        let instanceEntities = createExerciseInstanceEntities(from: module.exerciseInstances, for: entity)
        entity.exerciseInstances = NSOrderedSet(array: instanceEntities)
    }

    private func convertToModule(_ entity: ModuleEntity) -> Module {
        // Load old-style exercises (for backward compatibility)
        let exercises = entity.exerciseArray.map { exerciseEntity in
            let setGroups = exerciseEntity.setGroupArray.map { sgEntity in
                SetGroup(
                    id: sgEntity.id,
                    sets: Int(sgEntity.sets),
                    targetReps: sgEntity.targetReps > 0 ? Int(sgEntity.targetReps) : nil,
                    targetWeight: sgEntity.targetWeight > 0 ? sgEntity.targetWeight : nil,
                    targetRPE: sgEntity.targetRPE > 0 ? Int(sgEntity.targetRPE) : nil,
                    targetDuration: sgEntity.targetDuration > 0 ? Int(sgEntity.targetDuration) : nil,
                    targetDistance: sgEntity.targetDistance > 0 ? sgEntity.targetDistance : nil,
                    targetHoldTime: sgEntity.targetHoldTime > 0 ? Int(sgEntity.targetHoldTime) : nil,
                    restPeriod: sgEntity.restPeriod > 0 ? Int(sgEntity.restPeriod) : nil,
                    notes: sgEntity.notes,
                    isInterval: sgEntity.isInterval,
                    workDuration: sgEntity.workDuration > 0 ? Int(sgEntity.workDuration) : nil,
                    intervalRestDuration: sgEntity.intervalRestDuration > 0 ? Int(sgEntity.intervalRestDuration) : nil,
                    implementMeasurableLabel: sgEntity.implementMeasurableLabel,
                    implementMeasurableUnit: sgEntity.implementMeasurableUnit,
                    implementMeasurableValue: sgEntity.implementMeasurableValue > 0 ? sgEntity.implementMeasurableValue : nil,
                    implementMeasurableStringValue: sgEntity.implementMeasurableStringValue
                )
            }

            return Exercise(
                id: exerciseEntity.id,
                name: exerciseEntity.name,
                templateId: exerciseEntity.templateId,
                exerciseType: exerciseEntity.exerciseType,
                cardioMetric: exerciseEntity.cardioMetric,
                distanceUnit: exerciseEntity.distanceUnit,
                setGroups: setGroups,
                trackingMetrics: exerciseEntity.trackingMetrics,
                notes: exerciseEntity.notes,
                createdAt: exerciseEntity.createdAt ?? Date(),
                updatedAt: exerciseEntity.updatedAt ?? Date(),
                muscleGroupIds: exerciseEntity.muscleGroupIds,
                implementIds: exerciseEntity.implementIds
            )
        }

        // Load new-style exercise instances (normalized model)
        let exerciseInstances = convertExerciseInstanceEntities(entity.exerciseInstanceArray)

        return Module(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            exercises: exercises,
            exerciseInstances: exerciseInstances,
            notes: entity.notes,
            estimatedDuration: entity.estimatedDuration > 0 ? Int(entity.estimatedDuration) : nil,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            syncStatus: entity.syncStatus
        )
    }

    // MARK: - Workout Conversion

    private func findWorkoutEntity(id: UUID) -> WorkoutEntity? {
        let request = NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateWorkoutEntity(id: UUID) -> WorkoutEntity {
        if let existing = findWorkoutEntity(id: id) {
            return existing
        }
        let entity = WorkoutEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateWorkoutEntity(_ entity: WorkoutEntity, from workout: Workout) {
        entity.name = workout.name
        entity.estimatedDuration = Int32(workout.estimatedDuration ?? 0)
        entity.notes = workout.notes
        entity.archived = workout.archived
        entity.createdAt = workout.createdAt
        entity.updatedAt = workout.updatedAt
        entity.syncStatus = workout.syncStatus

        // Clear existing module references
        if let existingRefs = entity.moduleReferences {
            for case let ref as ModuleReferenceEntity in existingRefs {
                viewContext.delete(ref)
            }
        }

        // Add module references
        let refEntities = workout.moduleReferences.map { ref in
            let refEntity = ModuleReferenceEntity(context: viewContext)
            refEntity.id = ref.id
            refEntity.moduleId = ref.moduleId
            refEntity.orderIndex = Int32(ref.order)
            refEntity.isRequired = ref.isRequired
            refEntity.notes = ref.notes
            refEntity.workout = entity
            return refEntity
        }
        entity.moduleReferences = NSOrderedSet(array: refEntities)

        // Save standalone exercises
        entity.standaloneExercises = workout.standaloneExercises
    }

    private func convertToWorkout(_ entity: WorkoutEntity) -> Workout {
        let moduleRefs = entity.moduleReferenceArray.map { refEntity in
            ModuleReference(
                id: refEntity.id,
                moduleId: refEntity.moduleId,
                order: Int(refEntity.orderIndex),
                isRequired: refEntity.isRequired,
                notes: refEntity.notes
            )
        }

        return Workout(
            id: entity.id,
            name: entity.name,
            moduleReferences: moduleRefs,
            standaloneExercises: entity.standaloneExercises,
            estimatedDuration: entity.estimatedDuration > 0 ? Int(entity.estimatedDuration) : nil,
            notes: entity.notes,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            archived: entity.archived,
            syncStatus: entity.syncStatus
        )
    }

    // MARK: - Session Conversion

    private func findSessionEntity(id: UUID) -> SessionEntity? {
        let request = NSFetchRequest<SessionEntity>(entityName: "SessionEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateSessionEntity(id: UUID) -> SessionEntity {
        if let existing = findSessionEntity(id: id) {
            return existing
        }
        let entity = SessionEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateSessionEntity(_ entity: SessionEntity, from session: Session) {
        entity.workoutId = session.workoutId
        entity.workoutName = session.workoutName
        entity.date = session.date
        entity.skippedModuleIds = session.skippedModuleIds
        entity.duration = Int32(session.duration ?? 0)
        entity.overallFeeling = Int32(session.overallFeeling ?? 0)
        entity.notes = session.notes
        entity.createdAt = session.createdAt
        entity.syncStatus = session.syncStatus

        // Clear existing completed modules
        if let existingModules = entity.completedModules {
            for case let module as CompletedModuleEntity in existingModules {
                viewContext.delete(module)
            }
        }

        // Add completed modules
        let moduleEntities = session.completedModules.enumerated().map { index, completedModule in
            let moduleEntity = CompletedModuleEntity(context: viewContext)
            moduleEntity.id = completedModule.id
            moduleEntity.moduleId = completedModule.moduleId
            moduleEntity.moduleName = completedModule.moduleName
            moduleEntity.moduleType = completedModule.moduleType
            moduleEntity.skipped = completedModule.skipped
            moduleEntity.notes = completedModule.notes
            moduleEntity.orderIndex = Int32(index)
            moduleEntity.session = entity

            // Add completed exercises
            let exerciseEntities = completedModule.completedExercises.enumerated().map { exIndex, sessionExercise in
                let exerciseEntity = SessionExerciseEntity(context: viewContext)
                exerciseEntity.id = sessionExercise.id
                exerciseEntity.exerciseId = sessionExercise.exerciseId
                exerciseEntity.exerciseName = sessionExercise.exerciseName
                exerciseEntity.exerciseType = sessionExercise.exerciseType
                exerciseEntity.cardioMetric = sessionExercise.cardioMetric
                exerciseEntity.distanceUnit = sessionExercise.distanceUnit
                exerciseEntity.notes = sessionExercise.notes
                exerciseEntity.orderIndex = Int32(exIndex)
                exerciseEntity.completedModule = moduleEntity
                exerciseEntity.progressionRecommendation = sessionExercise.progressionRecommendation
                exerciseEntity.mobilityTracking = sessionExercise.mobilityTracking
                exerciseEntity.isBodyweight = sessionExercise.isBodyweight
                exerciseEntity.supersetGroupId = sessionExercise.supersetGroupId

                // Add completed set groups
                let setGroupEntities = sessionExercise.completedSetGroups.enumerated().map { sgIndex, completedSetGroup in
                    let sgEntity = CompletedSetGroupEntity(context: viewContext)
                    sgEntity.id = completedSetGroup.id
                    sgEntity.setGroupId = completedSetGroup.setGroupId
                    sgEntity.orderIndex = Int32(sgIndex)
                    sgEntity.restPeriod = Int32(completedSetGroup.restPeriod ?? 0)
                    sgEntity.isInterval = completedSetGroup.isInterval
                    sgEntity.workDuration = Int32(completedSetGroup.workDuration ?? 0)
                    sgEntity.intervalRestDuration = Int32(completedSetGroup.intervalRestDuration ?? 0)
                    sgEntity.sessionExercise = exerciseEntity

                    // Add set data
                    let setEntities = completedSetGroup.sets.map { setData in
                        let setEntity = SetDataEntity(context: viewContext)
                        setEntity.id = setData.id
                        setEntity.setNumber = Int32(setData.setNumber)
                        setEntity.weight = setData.weight ?? 0
                        setEntity.reps = Int32(setData.reps ?? 0)
                        setEntity.rpe = Int32(setData.rpe ?? 0)
                        setEntity.completed = setData.completed
                        setEntity.duration = Int32(setData.duration ?? 0)
                        setEntity.distance = setData.distance ?? 0
                        setEntity.pace = setData.pace ?? 0
                        setEntity.avgHeartRate = Int32(setData.avgHeartRate ?? 0)
                        setEntity.holdTime = Int32(setData.holdTime ?? 0)
                        setEntity.intensity = Int32(setData.intensity ?? 0)
                        setEntity.height = setData.height ?? 0
                        setEntity.quality = Int32(setData.quality ?? 0)
                        setEntity.restAfter = Int32(setData.restAfter ?? 0)
                        setEntity.completedSetGroup = sgEntity
                        return setEntity
                    }
                    sgEntity.sets = NSOrderedSet(array: setEntities)
                    return sgEntity
                }
                exerciseEntity.completedSetGroups = NSOrderedSet(array: setGroupEntities)
                return exerciseEntity
            }
            moduleEntity.completedExercises = NSOrderedSet(array: exerciseEntities)
            return moduleEntity
        }
        entity.completedModules = NSOrderedSet(array: moduleEntities)
    }

    private func convertToSession(_ entity: SessionEntity) -> Session {
        let completedModules = entity.completedModuleArray.map { moduleEntity in
            let completedExercises = moduleEntity.completedExerciseArray.map { exerciseEntity in
                let completedSetGroups = exerciseEntity.completedSetGroupArray.map { sgEntity in
                    let sets = sgEntity.setArray.map { setEntity in
                        SetData(
                            id: setEntity.id,
                            setNumber: Int(setEntity.setNumber),
                            weight: setEntity.weight > 0 ? setEntity.weight : nil,
                            reps: setEntity.reps > 0 ? Int(setEntity.reps) : nil,
                            rpe: setEntity.rpe > 0 ? Int(setEntity.rpe) : nil,
                            completed: setEntity.completed,
                            duration: setEntity.duration > 0 ? Int(setEntity.duration) : nil,
                            distance: setEntity.distance > 0 ? setEntity.distance : nil,
                            pace: setEntity.pace > 0 ? setEntity.pace : nil,
                            avgHeartRate: setEntity.avgHeartRate > 0 ? Int(setEntity.avgHeartRate) : nil,
                            holdTime: setEntity.holdTime > 0 ? Int(setEntity.holdTime) : nil,
                            intensity: setEntity.intensity > 0 ? Int(setEntity.intensity) : nil,
                            height: setEntity.height > 0 ? setEntity.height : nil,
                            quality: setEntity.quality > 0 ? Int(setEntity.quality) : nil,
                            restAfter: setEntity.restAfter > 0 ? Int(setEntity.restAfter) : nil
                        )
                    }
                    return CompletedSetGroup(
                        id: sgEntity.id,
                        setGroupId: sgEntity.setGroupId,
                        restPeriod: sgEntity.restPeriod > 0 ? Int(sgEntity.restPeriod) : nil,
                        sets: sets,
                        isInterval: sgEntity.isInterval,
                        workDuration: sgEntity.workDuration > 0 ? Int(sgEntity.workDuration) : nil,
                        intervalRestDuration: sgEntity.intervalRestDuration > 0 ? Int(sgEntity.intervalRestDuration) : nil
                    )
                }

                return SessionExercise(
                    id: exerciseEntity.id,
                    exerciseId: exerciseEntity.exerciseId,
                    exerciseName: exerciseEntity.exerciseName,
                    exerciseType: exerciseEntity.exerciseType,
                    cardioMetric: exerciseEntity.cardioMetric,
                    mobilityTracking: exerciseEntity.mobilityTracking,
                    distanceUnit: exerciseEntity.distanceUnit,
                    supersetGroupId: exerciseEntity.supersetGroupId,
                    completedSetGroups: completedSetGroups,
                    notes: exerciseEntity.notes,
                    isBodyweight: exerciseEntity.isBodyweight,
                    progressionRecommendation: exerciseEntity.progressionRecommendation
                )
            }

            return CompletedModule(
                id: moduleEntity.id,
                moduleId: moduleEntity.moduleId,
                moduleName: moduleEntity.moduleName,
                moduleType: moduleEntity.moduleType,
                completedExercises: completedExercises,
                skipped: moduleEntity.skipped,
                notes: moduleEntity.notes
            )
        }

        return Session(
            id: entity.id,
            workoutId: entity.workoutId,
            workoutName: entity.workoutName,
            date: entity.date,
            completedModules: completedModules,
            skippedModuleIds: entity.skippedModuleIds,
            duration: entity.duration > 0 ? Int(entity.duration) : nil,
            overallFeeling: entity.overallFeeling > 0 ? Int(entity.overallFeeling) : nil,
            notes: entity.notes,
            createdAt: entity.createdAt ?? entity.date,
            syncStatus: entity.syncStatus
        )
    }

    // MARK: - Program Conversion

    private func findProgramEntity(id: UUID) -> ProgramEntity? {
        let request = NSFetchRequest<ProgramEntity>(entityName: "ProgramEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateProgramEntity(id: UUID) -> ProgramEntity {
        if let existing = findProgramEntity(id: id) {
            return existing
        }
        let entity = ProgramEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateProgramEntity(_ entity: ProgramEntity, from program: Program) {
        entity.name = program.name
        entity.programDescription = program.programDescription
        entity.durationWeeks = Int32(program.durationWeeks)
        entity.startDate = program.startDate
        entity.endDate = program.endDate
        entity.isActive = program.isActive
        entity.createdAt = program.createdAt
        entity.updatedAt = program.updatedAt
        entity.syncStatus = program.syncStatus

        // Clear existing workout slots
        if let existingSlots = entity.workoutSlots {
            for case let slot as ProgramWorkoutSlotEntity in existingSlots {
                viewContext.delete(slot)
            }
        }

        // Add workout slots
        let slotEntities = program.workoutSlots.enumerated().map { index, slot in
            let slotEntity = ProgramWorkoutSlotEntity(context: viewContext)
            slotEntity.id = slot.id
            slotEntity.workoutId = slot.workoutId
            slotEntity.workoutName = slot.workoutName
            slotEntity.scheduleType = slot.scheduleType
            slotEntity.optionalDayOfWeek = slot.dayOfWeek
            slotEntity.optionalWeekNumber = slot.weekNumber
            slotEntity.optionalSpecificDateOffset = slot.specificDateOffset
            slotEntity.orderIndex = Int32(index)
            slotEntity.notes = slot.notes
            slotEntity.program = entity
            return slotEntity
        }
        entity.workoutSlots = NSOrderedSet(array: slotEntities)
    }

    private func convertToProgram(_ entity: ProgramEntity) -> Program {
        let slots = entity.workoutSlotArray.map { slotEntity in
            ProgramWorkoutSlot(
                id: slotEntity.id,
                workoutId: slotEntity.workoutId,
                workoutName: slotEntity.workoutName,
                scheduleType: slotEntity.scheduleType,
                dayOfWeek: slotEntity.optionalDayOfWeek,
                weekNumber: slotEntity.optionalWeekNumber,
                specificDateOffset: slotEntity.optionalSpecificDateOffset,
                order: Int(slotEntity.orderIndex),
                notes: slotEntity.notes
            )
        }

        return Program(
            id: entity.id,
            name: entity.name,
            programDescription: entity.programDescription,
            durationWeeks: Int(entity.durationWeeks),
            startDate: entity.startDate,
            endDate: entity.endDate,
            isActive: entity.isActive,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            syncStatus: entity.syncStatus,
            workoutSlots: slots
        )
    }
}
