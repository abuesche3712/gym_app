//
//  SessionRepository.swift
//  gym app
//
//  Handles Session CRUD operations, pagination, history queries, and in-progress recovery
//

import CoreData

@MainActor
class SessionRepository: CoreDataRepository {
    typealias DomainModel = Session
    typealias CDEntity = SessionEntity

    let persistence: PersistenceController

    var entityName: String { "SessionEntity" }

    var defaultSortDescriptors: [NSSortDescriptor] {
        [NSSortDescriptor(keyPath: \SessionEntity.date, ascending: false)]
    }

    // Pagination state
    private(set) var oldestLoadedDate: Date?
    private(set) var hasMore: Bool = true
    let initialLoadDays = 90
    let pageSize = 30

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Entity-Specific Conversion

    func toDomain(_ entity: SessionEntity) -> Session {
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

    func updateEntity(_ entity: SessionEntity, from session: Session) {
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

    // MARK: - Session-Specific Load Methods

    func loadRecent() -> [Session] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -initialLoadDays, to: Date()) ?? Date()

        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        request.predicate = NSPredicate(format: "date >= %@", cutoffDate as NSDate)

        do {
            let entities = try viewContext.fetch(request)
            let sessions = entities.map { toDomain($0) }

            oldestLoadedDate = sessions.last?.date
            hasMore = checkForOlderSessions(before: cutoffDate)

            Logger.debug("Loaded \(sessions.count) recent sessions (last \(initialLoadDays) days)")
            return sessions
        } catch {
            Logger.error(error, context: "SessionRepository.loadRecent")
            return []
        }
    }

    func loadMore(currentSessions: inout [Session]) -> Bool {
        guard hasMore else { return false }

        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        request.fetchLimit = pageSize

        if let oldest = oldestLoadedDate {
            request.predicate = NSPredicate(format: "date < %@", oldest as NSDate)
        }

        do {
            let entities = try viewContext.fetch(request)
            let olderSessions = entities.map { toDomain($0) }

            if olderSessions.isEmpty {
                hasMore = false
            } else {
                currentSessions.append(contentsOf: olderSessions)
                oldestLoadedDate = olderSessions.last?.date
                hasMore = olderSessions.count == pageSize
            }

            Logger.debug("Loaded \(olderSessions.count) more sessions, total: \(currentSessions.count)")
            return !olderSessions.isEmpty
        } catch {
            Logger.error(error, context: "SessionRepository.loadMore")
            return false
        }
    }

    /// Override to load ALL sessions (ignoring pagination) and reset pagination state
    func loadAll() -> [Session] {
        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors

        do {
            let entities = try viewContext.fetch(request)
            let sessions = entities.map { toDomain($0) }
            oldestLoadedDate = sessions.last?.date
            hasMore = false
            Logger.debug("Loaded all \(sessions.count) sessions")
            return sessions
        } catch {
            Logger.error(error, context: "SessionRepository.loadAll")
            return []
        }
    }

    // MARK: - Query Operations

    func getTotalCount() -> Int {
        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        do {
            return try viewContext.count(for: request)
        } catch {
            Logger.error(error, context: "SessionRepository.getTotalCount")
            return 0
        }
    }

    func getForWorkout(id workoutId: UUID, from sessions: [Session]) -> [Session] {
        sessions.filter { $0.workoutId == workoutId }
    }

    func getExerciseHistory(exerciseName: String, limit: Int? = nil) -> [SessionExercise] {
        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        if let limit = limit {
            request.fetchLimit = limit * 5
        }

        do {
            let entities = try viewContext.fetch(request)
            var results: [SessionExercise] = []

            for entity in entities {
                let session = toDomain(entity)
                for module in session.completedModules {
                    for exercise in module.completedExercises where exercise.exerciseName == exerciseName {
                        results.append(exercise)
                        if let limit = limit, results.count >= limit {
                            return results
                        }
                    }
                }
            }
            return results
        } catch {
            Logger.error(error, context: "SessionRepository.getExerciseHistory")
            return []
        }
    }

    func getLastProgressionRecommendation(
        exerciseName: String,
        loadedSessions: [Session]
    ) -> (recommendation: ProgressionRecommendation, date: Date)? {
        // First check loaded sessions
        for session in loadedSessions {
            for module in session.completedModules {
                if let exercise = module.completedExercises.first(where: { $0.exerciseName == exerciseName }),
                   let recommendation = exercise.progressionRecommendation {
                    return (recommendation, session.date)
                }
            }
        }

        // If not found and there are more, search CoreData
        guard hasMore else { return nil }

        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        if let oldest = oldestLoadedDate {
            request.predicate = NSPredicate(format: "date < %@", oldest as NSDate)
        }

        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                let session = toDomain(entity)
                for module in session.completedModules {
                    if let exercise = module.completedExercises.first(where: { $0.exerciseName == exerciseName }),
                       let recommendation = exercise.progressionRecommendation {
                        return (recommendation, session.date)
                    }
                }
            }
        } catch {
            Logger.error(error, context: "SessionRepository.getLastProgressionRecommendation")
        }

        return nil
    }

    // MARK: - In-Progress Session Recovery

    func saveInProgress(_ session: Session) {
        let request = NSFetchRequest<InProgressSessionEntity>(entityName: "InProgressSessionEntity")

        do {
            if let existing = try viewContext.fetch(request).first {
                existing.update(from: session)
            } else {
                let entity = InProgressSessionEntity(context: viewContext)
                entity.id = UUID()
                entity.update(from: session)
            }

            try viewContext.save()
            Logger.debug("Saved in-progress session for crash recovery")
        } catch {
            Logger.error(error, context: "SessionRepository.saveInProgress")
        }
    }

    func loadInProgress() -> Session? {
        let request = NSFetchRequest<InProgressSessionEntity>(entityName: "InProgressSessionEntity")

        guard let entity = try? viewContext.fetch(request).first else {
            return nil
        }

        return entity.toSession()
    }

    func getInProgressInfo() -> (workoutName: String, startTime: Date, lastUpdated: Date)? {
        let request = NSFetchRequest<InProgressSessionEntity>(entityName: "InProgressSessionEntity")

        guard let entity = try? viewContext.fetch(request).first,
              let workoutName = entity.workoutName,
              let startTime = entity.startTime else {
            return nil
        }

        return (workoutName, startTime, entity.lastUpdated)
    }

    func clearInProgress() {
        let request = NSFetchRequest<InProgressSessionEntity>(entityName: "InProgressSessionEntity")

        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                viewContext.delete(entity)
            }
            try viewContext.save()
            Logger.debug("Cleared in-progress session")
        } catch {
            Logger.error(error, context: "SessionRepository.clearInProgress")
        }
    }

    // MARK: - Private Helpers

    private func checkForOlderSessions(before date: Date) -> Bool {
        let request = NSFetchRequest<SessionEntity>(entityName: entityName)
        request.predicate = NSPredicate(format: "date < %@", date as NSDate)
        request.fetchLimit = 1

        do {
            return try viewContext.count(for: request) > 0
        } catch {
            return false
        }
    }
}
