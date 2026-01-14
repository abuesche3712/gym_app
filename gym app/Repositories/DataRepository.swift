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
    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published var modules: [Module] = []
    @Published var workouts: [Workout] = []
    @Published var sessions: [Session] = []

    init() {
        loadAllData()
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
            exerciseEntity.exerciseType = exercise.exerciseType
            exerciseEntity.trackingMetrics = exercise.trackingMetrics
            exerciseEntity.progressionType = exercise.progressionType
            exerciseEntity.notes = exercise.notes
            exerciseEntity.orderIndex = Int32(index)
            exerciseEntity.createdAt = exercise.createdAt
            exerciseEntity.updatedAt = exercise.updatedAt
            exerciseEntity.module = entity

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
                return sgEntity
            }
            exerciseEntity.setGroups = NSOrderedSet(array: setGroupEntities)
            return exerciseEntity
        }
        entity.exercises = NSOrderedSet(array: exerciseEntities)
    }

    private func convertToModule(_ entity: ModuleEntity) -> Module {
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
                    intervalRestDuration: sgEntity.intervalRestDuration > 0 ? Int(sgEntity.intervalRestDuration) : nil
                )
            }

            return Exercise(
                id: exerciseEntity.id,
                name: exerciseEntity.name,
                exerciseType: exerciseEntity.exerciseType,
                setGroups: setGroups,
                trackingMetrics: exerciseEntity.trackingMetrics,
                progressionType: exerciseEntity.progressionType,
                notes: exerciseEntity.notes,
                createdAt: exerciseEntity.createdAt,
                updatedAt: exerciseEntity.updatedAt
            )
        }

        return Module(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            exercises: exercises,
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
                    distanceUnit: exerciseEntity.distanceUnit,
                    completedSetGroups: completedSetGroups,
                    notes: exerciseEntity.notes
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
