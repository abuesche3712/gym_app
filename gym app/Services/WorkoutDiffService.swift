//
//  WorkoutDiffService.swift
//  gym app
//
//  Detects and applies structural changes between workout sessions and module templates
//

import Foundation

class WorkoutDiffService {

    static let shared = WorkoutDiffService()

    private init() {}

    // MARK: - Change Detection

    /// Detect structural changes between completed session and original templates
    func detectChanges(
        session: Session,
        originalModules: [Module]
    ) -> [StructuralChange] {
        var changes: [StructuralChange] = []

        for completedModule in session.completedModules {
            // Skip if module was skipped entirely
            guard !completedModule.skipped else { continue }

            guard let originalModule = originalModules.first(where: { $0.id == completedModule.moduleId }) else {
                continue
            }

            let originalExercises = originalModule.exercises
            let sessionExercises = completedModule.completedExercises

            // 1. Detect ADDED exercises (no sourceExerciseInstanceId or isAdHoc)
            for (index, sessionEx) in sessionExercises.enumerated() {
                if sessionEx.sourceExerciseInstanceId == nil || sessionEx.isAdHoc {
                    changes.append(.exerciseAdded(
                        sessionExercise: sessionEx,
                        moduleId: originalModule.id,
                        moduleName: originalModule.name,
                        atIndex: index
                    ))
                }
            }

            // 2. Detect REMOVED exercises (in template but not in session)
            for originalEx in originalExercises {
                let existsInSession = sessionExercises.contains {
                    $0.sourceExerciseInstanceId == originalEx.id
                }
                if !existsInSession {
                    changes.append(.exerciseRemoved(
                        exerciseInstanceId: originalEx.id,
                        exerciseName: originalEx.name,
                        moduleId: originalModule.id,
                        moduleName: originalModule.name
                    ))
                }
            }

            // 3. Detect SET COUNT changes
            for sessionEx in sessionExercises {
                guard let sourceId = sessionEx.sourceExerciseInstanceId,
                      let originalEx = originalExercises.first(where: { $0.id == sourceId }) else {
                    continue
                }

                let originalSetCount = totalSetCount(for: originalEx)
                let sessionSetCount = totalSetCount(for: sessionEx)

                if originalSetCount != sessionSetCount {
                    changes.append(.setCountChanged(
                        exerciseInstanceId: sourceId,
                        exerciseName: sessionEx.exerciseName,
                        moduleId: originalModule.id,
                        moduleName: originalModule.name,
                        from: originalSetCount,
                        to: sessionSetCount
                    ))
                }
            }

            // 4. Detect SUBSTITUTIONS (name changed for matched exercises)
            for sessionEx in sessionExercises {
                guard let sourceId = sessionEx.sourceExerciseInstanceId,
                      let originalEx = originalExercises.first(where: { $0.id == sourceId }) else {
                    continue
                }

                if sessionEx.exerciseName != originalEx.name {
                    changes.append(.exerciseSubstituted(
                        sourceExerciseInstanceId: sourceId,
                        originalName: originalEx.name,
                        newName: sessionEx.exerciseName,
                        moduleId: originalModule.id,
                        moduleName: originalModule.name
                    ))
                }
            }

            // 5. Detect REORDERING
            let reorderChanges = detectReordering(
                originalExercises: originalExercises,
                sessionExercises: sessionExercises,
                moduleId: originalModule.id,
                moduleName: originalModule.name
            )
            changes.append(contentsOf: reorderChanges)
        }

        return changes
    }

    // MARK: - Change Application

    /// Apply selected changes to module templates
    func commitChanges(
        _ selectedChanges: [StructuralChange],
        to modules: [Module],
        repository: DataRepository
    ) {
        var updatedModules = modules

        for change in selectedChanges {
            switch change {
            case .setCountChanged(let exerciseId, _, let moduleId, _, _, let newCount):
                applySetCountChange(
                    exerciseId: exerciseId,
                    moduleId: moduleId,
                    newCount: newCount,
                    modules: &updatedModules
                )

            case .exerciseAdded(let sessionExercise, let moduleId, _, let atIndex):
                applyExerciseAdded(
                    sessionExercise: sessionExercise,
                    moduleId: moduleId,
                    atIndex: atIndex,
                    modules: &updatedModules
                )

            case .exerciseRemoved(let exerciseId, _, let moduleId, _):
                applyExerciseRemoved(
                    exerciseId: exerciseId,
                    moduleId: moduleId,
                    modules: &updatedModules
                )

            case .exerciseReordered(let exerciseId, _, let moduleId, _, _, let toIndex):
                applyExerciseReordered(
                    exerciseId: exerciseId,
                    moduleId: moduleId,
                    toIndex: toIndex,
                    modules: &updatedModules
                )

            case .exerciseSubstituted(let exerciseId, _, let newName, let moduleId, _):
                applyExerciseSubstituted(
                    exerciseId: exerciseId,
                    moduleId: moduleId,
                    newName: newName,
                    modules: &updatedModules
                )
            }
        }

        // Save updated modules
        for module in updatedModules {
            if selectedChanges.contains(where: { $0.moduleId == module.id }) {
                var updatedModule = module
                updatedModule.updatedAt = Date()
                updatedModule.syncStatus = .pendingSync
                repository.saveModule(updatedModule)
            }
        }
    }

    // MARK: - Private Helpers

    private func totalSetCount(for exercise: ExerciseInstance) -> Int {
        // For unilateral exercises, each "set" in the UI is actually 2 SetData (L + R)
        // But the template stores the logical set count
        exercise.setGroups.reduce(0) { $0 + $1.sets }
    }

    private func totalSetCount(for sessionExercise: SessionExercise) -> Int {
        // For session exercises, we need to count the actual logged sets
        // For unilateral, divide by 2 since L and R are separate entries
        let rawCount = sessionExercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }

        // Check if any set group is unilateral
        let isUnilateral = sessionExercise.completedSetGroups.first?.isUnilateral ?? false
        return isUnilateral ? rawCount / 2 : rawCount
    }

    private func detectReordering(
        originalExercises: [ExerciseInstance],
        sessionExercises: [SessionExercise],
        moduleId: UUID,
        moduleName: String
    ) -> [StructuralChange] {
        var changes: [StructuralChange] = []

        // Build mapping of original exercise IDs to their indices
        var originalIndices: [UUID: Int] = [:]
        for (index, ex) in originalExercises.enumerated() {
            originalIndices[ex.id] = index
        }

        // Find session exercises that exist in original and check their order
        var matchedExercises: [(sourceId: UUID, name: String, originalIndex: Int, sessionIndex: Int)] = []

        for (sessionIndex, sessionEx) in sessionExercises.enumerated() {
            guard let sourceId = sessionEx.sourceExerciseInstanceId,
                  let originalIndex = originalIndices[sourceId] else {
                continue
            }
            matchedExercises.append((sourceId, sessionEx.exerciseName, originalIndex, sessionIndex))
        }

        // Check if relative order has changed
        // We look for exercises that moved significantly (not just shifted due to additions/removals)
        for matched in matchedExercises {
            // Find where this exercise is in the session relative to other matched exercises
            let sessionOrder = matchedExercises.filter { $0.sessionIndex < matched.sessionIndex }.count
            let originalOrder = matchedExercises.filter { $0.originalIndex < matched.originalIndex }.count

            if sessionOrder != originalOrder {
                // This exercise has moved relative to others
                changes.append(.exerciseReordered(
                    exerciseInstanceId: matched.sourceId,
                    exerciseName: matched.name,
                    moduleId: moduleId,
                    moduleName: moduleName,
                    fromIndex: matched.originalIndex,
                    toIndex: matched.sessionIndex
                ))
            }
        }

        return changes
    }

    // MARK: - Apply Changes

    private func applySetCountChange(
        exerciseId: UUID,
        moduleId: UUID,
        newCount: Int,
        modules: inout [Module]
    ) {
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }),
              let exerciseIndex = modules[moduleIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return
        }

        var exercise = modules[moduleIndex].exercises[exerciseIndex]
        adjustSetCount(for: &exercise, to: newCount)
        modules[moduleIndex].exercises[exerciseIndex] = exercise
    }

    private func applyExerciseAdded(
        sessionExercise: SessionExercise,
        moduleId: UUID,
        atIndex: Int,
        modules: inout [Module]
    ) {
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }) else {
            return
        }

        let newExerciseInstance = convertToExerciseInstance(from: sessionExercise)
        let safeIndex = min(atIndex, modules[moduleIndex].exercises.count)
        modules[moduleIndex].exercises.insert(newExerciseInstance, at: safeIndex)

        // Update order for all exercises
        for i in 0..<modules[moduleIndex].exercises.count {
            modules[moduleIndex].exercises[i].order = i
        }
    }

    private func applyExerciseRemoved(
        exerciseId: UUID,
        moduleId: UUID,
        modules: inout [Module]
    ) {
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }) else {
            return
        }

        modules[moduleIndex].exercises.removeAll { $0.id == exerciseId }

        // Update order for remaining exercises
        for i in 0..<modules[moduleIndex].exercises.count {
            modules[moduleIndex].exercises[i].order = i
        }
    }

    private func applyExerciseReordered(
        exerciseId: UUID,
        moduleId: UUID,
        toIndex: Int,
        modules: inout [Module]
    ) {
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }),
              let fromIndex = modules[moduleIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return
        }

        let exercise = modules[moduleIndex].exercises.remove(at: fromIndex)
        let safeIndex = min(toIndex, modules[moduleIndex].exercises.count)
        modules[moduleIndex].exercises.insert(exercise, at: safeIndex)

        // Update order for all exercises
        for i in 0..<modules[moduleIndex].exercises.count {
            modules[moduleIndex].exercises[i].order = i
        }
    }

    private func applyExerciseSubstituted(
        exerciseId: UUID,
        moduleId: UUID,
        newName: String,
        modules: inout [Module]
    ) {
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }),
              let exerciseIndex = modules[moduleIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return
        }

        modules[moduleIndex].exercises[exerciseIndex].name = newName
    }

    private func adjustSetCount(for exercise: inout ExerciseInstance, to targetCount: Int) {
        // Get current total sets across all set groups
        let currentCount = exercise.setGroups.reduce(0) { $0 + $1.sets }

        guard currentCount != targetCount, !exercise.setGroups.isEmpty else { return }

        if targetCount > currentCount {
            // ADD sets - add to last set group
            let setsToAdd = targetCount - currentCount
            let lastIndex = exercise.setGroups.count - 1
            exercise.setGroups[lastIndex].sets += setsToAdd

        } else {
            // REMOVE sets - remove from end
            var setsToRemove = currentCount - targetCount
            while setsToRemove > 0 && !exercise.setGroups.isEmpty {
                let lastIndex = exercise.setGroups.count - 1
                if exercise.setGroups[lastIndex].sets <= setsToRemove {
                    setsToRemove -= exercise.setGroups[lastIndex].sets
                    exercise.setGroups.removeLast()
                } else {
                    exercise.setGroups[lastIndex].sets -= setsToRemove
                    setsToRemove = 0
                }
            }
        }
    }

    private func convertToExerciseInstance(from sessionExercise: SessionExercise) -> ExerciseInstance {
        // Convert SessionExercise back to ExerciseInstance template
        // Use structure but not actual logged values (weight, reps logged are session variance)

        // Convert CompletedSetGroups to SetGroups
        let setGroups: [SetGroup] = sessionExercise.completedSetGroups.map { completedGroup in
            // Determine set count (for unilateral, divide by 2)
            let setCount = completedGroup.isUnilateral
                ? completedGroup.sets.count / 2
                : completedGroup.sets.count

            return SetGroup(
                id: UUID(),
                sets: max(1, setCount),
                targetReps: completedGroup.sets.first?.reps,
                targetWeight: completedGroup.sets.first?.weight,
                targetRPE: nil,
                targetDuration: completedGroup.sets.first?.duration,
                targetDistance: completedGroup.sets.first?.distance,
                targetDistanceUnit: nil,
                targetHoldTime: completedGroup.sets.first?.holdTime,
                restPeriod: completedGroup.restPeriod,
                notes: nil,
                isInterval: completedGroup.isInterval,
                workDuration: completedGroup.workDuration,
                intervalRestDuration: completedGroup.intervalRestDuration,
                isAMRAP: completedGroup.isAMRAP,
                amrapTimeLimit: completedGroup.amrapTimeLimit,
                trackRPE: completedGroup.trackRPE,
                implementMeasurables: completedGroup.implementMeasurables
            )
        }

        return ExerciseInstance(
            id: UUID(),
            templateId: nil, // Could try to match a template by name if needed
            name: sessionExercise.exerciseName,
            exerciseType: sessionExercise.exerciseType,
            cardioMetric: CardioTracking(rawValue: sessionExercise.cardioMetric.rawValue) ?? .timeOnly,
            distanceUnit: sessionExercise.distanceUnit,
            mobilityTracking: sessionExercise.mobilityTracking,
            isBodyweight: sessionExercise.isBodyweight,
            tracksAddedWeight: sessionExercise.tracksAddedWeight,
            isUnilateral: sessionExercise.completedSetGroups.first?.isUnilateral ?? false,
            recoveryActivityType: sessionExercise.recoveryActivityType,
            primaryMuscles: sessionExercise.primaryMuscles,
            secondaryMuscles: sessionExercise.secondaryMuscles,
            implementIds: sessionExercise.implementIds,
            setGroups: setGroups.isEmpty ? [SetGroup(id: UUID(), sets: 3)] : setGroups,
            supersetGroupId: sessionExercise.supersetGroupId,
            order: 0, // Will be updated when inserted
            notes: sessionExercise.notes
        )
    }
}
