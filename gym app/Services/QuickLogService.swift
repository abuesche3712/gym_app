//
//  QuickLogService.swift
//  gym app
//
//  Service for creating Sessions from quick log inputs without requiring templates
//

import Foundation

class QuickLogService {
    static let shared = QuickLogService()

    /// Sentinel UUID for identifying quick log sessions
    static let quickLogWorkoutId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Sentinel UUID for identifying freestyle sessions
    static let freestyleWorkoutId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private init() {}

    /// Creates a complete Session from quick log inputs
    func createQuickLog(
        exerciseName: String,
        exerciseType: ExerciseType,
        metrics: SetData,
        notes: String?,
        date: Date = Date()
    ) -> Session {
        let sessionId = UUID()
        let moduleId = UUID()
        let exerciseId = UUID()
        let setGroupId = UUID()

        // 1. Build SetData with sharing context
        var setData = metrics
        setData.sessionId = sessionId
        setData.exerciseId = exerciseId
        setData.exerciseName = exerciseName
        setData.workoutName = "Quick Log"
        setData.date = date

        // 2. Build CompletedSetGroup
        let setGroup = CompletedSetGroup(
            setGroupId: setGroupId,
            sets: [setData]
        )

        // 3. Build SessionExercise
        let exercise = SessionExercise(
            id: exerciseId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            exerciseType: exerciseType,
            cardioMetric: exerciseType == .cardio ? .both : .timeOnly,
            completedSetGroups: [setGroup],
            notes: notes,
            isAdHoc: true,
            sessionId: sessionId,
            moduleId: moduleId,
            moduleName: moduleTypeForExercise(exerciseType).displayName,
            workoutId: Self.quickLogWorkoutId,
            workoutName: "Quick Log",
            date: date
        )

        // 4. Build CompletedModule
        let moduleType = moduleTypeForExercise(exerciseType)
        let module = CompletedModule(
            id: moduleId,
            moduleId: moduleId,
            moduleName: moduleType.displayName,
            moduleType: moduleType,
            completedExercises: [exercise],
            sessionId: sessionId,
            workoutId: Self.quickLogWorkoutId,
            workoutName: "Quick Log",
            date: date
        )

        // 5. Build Session
        let session = Session(
            id: sessionId,
            workoutId: Self.quickLogWorkoutId,
            workoutName: "Quick Log",
            date: date,
            completedModules: [module],
            isQuickLog: true
        )

        return session
    }

    /// Maps exercise type to appropriate module type
    func moduleTypeForExercise(_ type: ExerciseType) -> ModuleType {
        switch type {
        case .strength:
            return .strength
        case .cardio:
            return .cardioLong
        case .explosive:
            return .explosive
        case .isometric, .mobility:
            return .prehab
        case .recovery:
            return .recovery
        }
    }

    // MARK: - Freestyle Session Support

    /// Creates an empty freestyle session ready for exercises to be added
    func createFreestyleSession() -> Session {
        return Session(
            workoutId: Self.freestyleWorkoutId,
            workoutName: "Freestyle",
            completedModules: [],
            isFreestyle: true
        )
    }

    /// Add an exercise to an active freestyle session
    func addExercise(
        to session: inout Session,
        exerciseName: String,
        exerciseType: ExerciseType,
        implementIds: Set<UUID> = [],
        isBodyweight: Bool = false,
        distanceUnit: DistanceUnit = .miles
    ) {
        let exerciseId = UUID()
        let setGroupId = UUID()

        // Create first empty set
        var setData = SetData(setNumber: 1, completed: false)
        setData.sessionId = session.id
        setData.exerciseId = exerciseId
        setData.exerciseName = exerciseName
        setData.workoutName = "Freestyle"
        setData.date = session.date

        // Create set group with one empty set
        let setGroup = CompletedSetGroup(
            setGroupId: setGroupId,
            sets: [setData]
        )

        // Get module type for this exercise
        let moduleType = moduleTypeForExercise(exerciseType)

        // Create the exercise
        let exercise = SessionExercise(
            id: exerciseId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            exerciseType: exerciseType,
            cardioMetric: exerciseType == .cardio ? .both : .timeOnly,
            distanceUnit: distanceUnit,
            completedSetGroups: [setGroup],
            isBodyweight: isBodyweight,
            implementIds: implementIds,
            isAdHoc: true,
            sessionId: session.id,
            moduleId: UUID(), // Will be replaced when added to module
            moduleName: moduleType.displayName,
            workoutId: Self.freestyleWorkoutId,
            workoutName: "Freestyle",
            date: session.date
        )

        // Find or create module of the appropriate type
        if let moduleIndex = session.completedModules.firstIndex(where: { $0.moduleType == moduleType }) {
            // Add to existing module
            var updatedExercise = exercise
            updatedExercise.moduleId = session.completedModules[moduleIndex].id
            session.completedModules[moduleIndex].completedExercises.append(updatedExercise)
        } else {
            // Create new module
            let moduleId = UUID()
            var updatedExercise = exercise
            updatedExercise.moduleId = moduleId

            let module = CompletedModule(
                id: moduleId,
                moduleId: moduleId,
                moduleName: moduleType.displayName,
                moduleType: moduleType,
                completedExercises: [updatedExercise],
                sessionId: session.id,
                workoutId: Self.freestyleWorkoutId,
                workoutName: "Freestyle",
                date: session.date
            )
            session.completedModules.append(module)
        }
    }

    /// Remove an exercise from a freestyle session
    func removeExercise(from session: inout Session, moduleId: UUID, exerciseId: UUID) {
        guard let moduleIndex = session.completedModules.firstIndex(where: { $0.id == moduleId }) else {
            return
        }

        session.completedModules[moduleIndex].completedExercises.removeAll { $0.id == exerciseId }

        // Remove empty modules
        if session.completedModules[moduleIndex].completedExercises.isEmpty {
            session.completedModules.remove(at: moduleIndex)
        }
    }
}
