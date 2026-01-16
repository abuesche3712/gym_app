//
//  DataRepository.swift
//  gym app
//
//  Main repository for data access - handles conversion between CoreData and Swift models
//

import CoreData
import Combine

@MainActor
class DataRepository: ObservableObject {
    static let shared = DataRepository()

    private let persistence = PersistenceController.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published var modules: [Module] = []
    @Published var workouts: [Workout] = []
    @Published var sessions: [Session] = []
    @Published var isSyncing = false

    init() {
        loadAllData()
    }

    // MARK: - Cloud Sync

    /// Sync data from Firestore on app launch (if authenticated)
    func syncFromCloud() async {
        guard authService.isAuthenticated else {
            print("syncFromCloud: Not authenticated, skipping")
            return
        }

        print("syncFromCloud: Starting sync...")
        isSyncing = true

        do {
            let cloudData = try await firestoreService.fetchAllUserData()
            print("syncFromCloud: Fetched \(cloudData.modules.count) modules, \(cloudData.workouts.count) workouts, \(cloudData.sessions.count) sessions, \(cloudData.exercises.count) exercises")

            // Merge cloud modules (last-write-wins based on updatedAt)
            for cloudModule in cloudData.modules {
                if let local = modules.first(where: { $0.id == cloudModule.id }) {
                    // If cloud is newer, update local
                    if cloudModule.updatedAt > local.updatedAt {
                        saveModuleLocally(cloudModule)
                    }
                } else {
                    // New from cloud, save locally
                    saveModuleLocally(cloudModule)
                }
            }

            // Merge cloud workouts
            for cloudWorkout in cloudData.workouts {
                if let local = workouts.first(where: { $0.id == cloudWorkout.id }) {
                    if cloudWorkout.updatedAt > local.updatedAt {
                        saveWorkoutLocally(cloudWorkout)
                    }
                } else {
                    saveWorkoutLocally(cloudWorkout)
                }
            }

            // Merge cloud sessions
            for cloudSession in cloudData.sessions {
                if !sessions.contains(where: { $0.id == cloudSession.id }) {
                    saveSessionLocally(cloudSession)
                }
            }

            // Merge custom exercises
            let customLibrary = CustomExerciseLibrary.shared
            for cloudExercise in cloudData.exercises {
                if !customLibrary.exercises.contains(where: { $0.id == cloudExercise.id }) {
                    customLibrary.addExercise(cloudExercise)
                }
            }

            // Reload all data after merge
            loadAllData()

            print("syncFromCloud: Completed successfully")
        } catch {
            print("syncFromCloud: Failed with error: \(error)")
        }

        isSyncing = false
        print("syncFromCloud: isSyncing set to false")
    }

    /// Push all local data to cloud (useful for initial sync after sign-in)
    func pushAllToCloud() async {
        guard authService.isAuthenticated else {
            print("pushAllToCloud: Not authenticated, skipping")
            return
        }

        print("pushAllToCloud: Starting push...")
        print("pushAllToCloud: \(modules.count) modules, \(workouts.count) workouts, \(sessions.count) sessions")
        isSyncing = true

        do {
            // Push all modules
            for module in modules {
                print("pushAllToCloud: Saving module \(module.name)")
                try await firestoreService.saveModule(module)
            }

            // Push all workouts
            for workout in workouts {
                print("pushAllToCloud: Saving workout \(workout.name)")
                try await firestoreService.saveWorkout(workout)
            }

            // Push all sessions
            for session in sessions {
                print("pushAllToCloud: Saving session \(session.id)")
                try await firestoreService.saveSession(session)
            }

            // Push custom exercises
            let customLibrary = CustomExerciseLibrary.shared
            for exercise in customLibrary.exercises {
                print("pushAllToCloud: Saving custom exercise \(exercise.name)")
                try await firestoreService.saveCustomExercise(exercise)
            }

            print("pushAllToCloud: Completed successfully")
        } catch {
            print("pushAllToCloud: Failed with error: \(error)")
        }

        isSyncing = false
        print("pushAllToCloud: isSyncing set to false")
    }

    // MARK: - Load All Data

    func loadAllData() {
        loadModules()
        loadWorkouts()
        loadSessions()
    }

    // MARK: - Module Operations

    func loadModules() {
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ModuleEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            modules = entities.map { convertToModule($0) }
        } catch {
            print("Error loading modules: \(error)")
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
                    print("Failed to sync module to cloud: \(error)")
                }
            }
        }
    }

    /// Save module to CoreData only (used during cloud sync to avoid loops)
    private func saveModuleLocally(_ module: Module) {
        let entity = findOrCreateModuleEntity(id: module.id)
        updateModuleEntity(entity, from: module)
        save()
        loadModules()
    }

    func deleteModule(_ module: Module) {
        if let entity = findModuleEntity(id: module.id) {
            viewContext.delete(entity)
            save()
            loadModules()

            // Delete from cloud if authenticated
            if authService.isAuthenticated {
                Task {
                    do {
                        try await firestoreService.deleteModule(module.id)
                    } catch {
                        print("Failed to delete module from cloud: \(error)")
                    }
                }
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
            print("Error loading workouts: \(error)")
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
                    print("Failed to sync workout to cloud: \(error)")
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

            // Delete from cloud if authenticated
            if authService.isAuthenticated {
                Task {
                    do {
                        try await firestoreService.deleteWorkout(workout.id)
                    } catch {
                        print("Failed to delete workout from cloud: \(error)")
                    }
                }
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
            print("Error loading sessions: \(error)")
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
                    print("Failed to sync session to cloud: \(error)")
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

            // Delete from cloud if authenticated
            if authService.isAuthenticated {
                Task {
                    do {
                        try await firestoreService.deleteSession(session.id)
                    } catch {
                        print("Failed to delete session from cloud: \(error)")
                    }
                }
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
                createdAt: instanceEntity.createdAt,
                updatedAt: instanceEntity.updatedAt
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
                createdAt: exerciseEntity.createdAt,
                updatedAt: exerciseEntity.updatedAt,
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
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
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
            estimatedDuration: entity.estimatedDuration > 0 ? Int(entity.estimatedDuration) : nil,
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
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
            createdAt: entity.createdAt,
            syncStatus: entity.syncStatus
        )
    }
}
