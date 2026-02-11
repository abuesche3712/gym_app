//
//  ImportConversionService.swift
//  gym app
//
//  Converts imported sessions (e.g., from Strong CSV) into reusable Workout templates
//

import Foundation

class ImportConversionService {
    static let shared = ImportConversionService()

    struct ConversionResult {
        let workout: Workout
        let createdExercises: [String]   // Names of newly created custom exercises
        let matchedExercises: [String]   // Names matched to existing library
    }

    /// Convert an imported Session into a Workout template with standalone exercises
    @MainActor
    func convertSessionToWorkout(_ session: Session) -> ConversionResult {
        var createdExercises: [String] = []
        var matchedExercises: [String] = []
        var workoutExercises: [WorkoutExercise] = []
        var orderIndex = 0

        // Flatten all exercises across all modules, preserving order
        let allSessionExercises = session.completedModules.flatMap { $0.completedExercises }

        for sessionExercise in allSessionExercises {
            let exerciseName = sessionExercise.exerciseName

            // Try to find an existing template by name
            var template = ExerciseResolver.shared.findTemplate(named: exerciseName)

            if let t = template {
                matchedExercises.append(t.name)
            } else {
                // Create a new custom exercise
                CustomExerciseLibrary.shared.addExercise(
                    name: exerciseName,
                    exerciseType: sessionExercise.exerciseType
                )
                // Refresh the resolver cache and look it up
                ExerciseResolver.shared.refreshCache()
                template = ExerciseResolver.shared.findTemplate(named: exerciseName)
                createdExercises.append(exerciseName)
            }

            // Build ExerciseInstance from the template
            var instance: ExerciseInstance
            if let t = template {
                instance = ExerciseInstance.from(template: t, order: orderIndex)
            } else {
                // Fallback: create instance directly (should not happen, but be safe)
                instance = ExerciseInstance(
                    name: exerciseName,
                    exerciseType: sessionExercise.exerciseType,
                    cardioMetric: sessionExercise.cardioMetric,
                    distanceUnit: sessionExercise.distanceUnit,
                    order: orderIndex
                )
            }

            // Override setGroups with data from the session
            instance.setGroups = convertSetGroups(from: sessionExercise.completedSetGroups)

            let workoutExercise = WorkoutExercise(exercise: instance, order: orderIndex)
            workoutExercises.append(workoutExercise)
            orderIndex += 1
        }

        let workout = Workout(
            name: session.workoutName,
            moduleReferences: [],
            standaloneExercises: workoutExercises
        )

        return ConversionResult(
            workout: workout,
            createdExercises: createdExercises,
            matchedExercises: matchedExercises
        )
    }

    // MARK: - Private Helpers

    /// Convert CompletedSetGroups into SetGroups for a workout template
    private func convertSetGroups(from completedGroups: [CompletedSetGroup]) -> [SetGroup] {
        return completedGroups.map { completed in
            let sets = completed.sets
            let setCount: Int
            if completed.isUnilateral {
                // Unilateral: left+right count as one set
                setCount = max(1, sets.count / 2)
            } else {
                setCount = max(1, sets.count)
            }

            // Use the first set's data as the target
            let firstSet = sets.first

            return SetGroup(
                sets: setCount,
                targetReps: firstSet?.reps,
                targetWeight: firstSet?.weight,
                targetDuration: firstSet?.duration,
                targetDistance: firstSet?.distance,
                targetHoldTime: firstSet?.holdTime,
                restPeriod: completed.restPeriod,
                isInterval: completed.isInterval,
                workDuration: completed.workDuration,
                intervalRestDuration: completed.intervalRestDuration,
                isAMRAP: completed.isAMRAP,
                amrapTimeLimit: completed.amrapTimeLimit,
                isUnilateral: completed.isUnilateral,
                trackRPE: completed.trackRPE
            )
        }
    }
}
