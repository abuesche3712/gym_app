//
//  SessionNavigator.swift
//  gym app
//
//  Handles navigation state and logic for workout sessions.
//  Extracted from SessionViewModel for testability and separation of concerns.
//

import Foundation

/// Manages navigation through a workout session's modules, exercises, set groups, and sets.
/// Handles both linear progression and superset cycling patterns.
struct SessionNavigator {
    // MARK: - Navigation State

    private(set) var currentModuleIndex = 0
    private(set) var currentExerciseIndex = 0
    private(set) var currentSetGroupIndex = 0
    private(set) var currentSetIndex = 0

    // MARK: - Session Structure

    /// The modules being navigated (read-only snapshot)
    private let modules: [CompletedModule]

    // MARK: - Initialization

    init(modules: [CompletedModule]) {
        self.modules = modules
    }

    /// Creates a navigator with initial position
    init(modules: [CompletedModule], moduleIndex: Int, exerciseIndex: Int, setGroupIndex: Int, setIndex: Int) {
        self.modules = modules
        self.currentModuleIndex = moduleIndex
        self.currentExerciseIndex = exerciseIndex
        self.currentSetGroupIndex = setGroupIndex
        self.currentSetIndex = setIndex
    }

    // MARK: - Current Position Accessors

    var currentModule: CompletedModule? {
        guard currentModuleIndex < modules.count else { return nil }
        return modules[currentModuleIndex]
    }

    var currentExercise: SessionExercise? {
        guard let module = currentModule,
              currentExerciseIndex < module.completedExercises.count else { return nil }
        return module.completedExercises[currentExerciseIndex]
    }

    var currentSetGroup: CompletedSetGroup? {
        guard let exercise = currentExercise,
              currentSetGroupIndex < exercise.completedSetGroups.count else { return nil }
        return exercise.completedSetGroups[currentSetGroupIndex]
    }

    var currentSet: SetData? {
        guard let setGroup = currentSetGroup,
              currentSetIndex < setGroup.sets.count else { return nil }
        return setGroup.sets[currentSetIndex]
    }

    /// Returns true if currently at the last set of the workout
    var isLastSet: Bool {
        let lastModuleIndex = modules.count - 1
        guard currentModuleIndex == lastModuleIndex, lastModuleIndex >= 0 else { return false }

        let module = modules[currentModuleIndex]
        let lastExerciseIndex = module.completedExercises.count - 1
        guard currentExerciseIndex == lastExerciseIndex, lastExerciseIndex >= 0 else { return false }

        let exercise = module.completedExercises[currentExerciseIndex]
        let lastSetGroupIndex = exercise.completedSetGroups.count - 1
        guard currentSetGroupIndex == lastSetGroupIndex, lastSetGroupIndex >= 0 else { return false }

        let setGroup = exercise.completedSetGroups[currentSetGroupIndex]
        return currentSetIndex == setGroup.sets.count - 1
    }

    /// Returns true if the workout is complete (past the last set)
    var isWorkoutComplete: Bool {
        guard let module = currentModule else { return true }

        // Check if we're past all exercises in the last module
        if currentModuleIndex == modules.count - 1 {
            if currentExerciseIndex >= module.completedExercises.count {
                return true
            }
        }

        return false
    }

    // MARK: - Superset Properties

    /// Returns true if the current exercise is part of a superset
    var isInSuperset: Bool {
        currentExercise?.supersetGroupId != nil
    }

    /// Returns true if we just finished the last exercise in a superset round (time to rest)
    var shouldRestAfterSuperset: Bool {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return false
        }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let currentSupersetPosition = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return false
        }

        // We should rest if we're at the last exercise in the superset
        return currentSupersetPosition == supersetIndices.count - 1
    }

    /// Gets all exercises in the current superset (for display purposes)
    var currentSupersetExercises: [SessionExercise]? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return nil
        }

        return module.completedExercises.filter { $0.supersetGroupId == supersetId }
    }

    /// Current position within the superset (1-based for display)
    var supersetPosition: Int? {
        guard let module = currentModule,
              let exercise = currentExercise,
              let supersetId = exercise.supersetGroupId else {
            return nil
        }

        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let position = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            return nil
        }

        return position + 1
    }

    /// Total exercises in current superset
    var supersetTotal: Int? {
        currentSupersetExercises?.count
    }

    // MARK: - Navigation Methods

    /// Advances to the next set, handling superset cycling
    mutating func advanceToNextSet() {
        guard let module = currentModule,
              let exercise = currentExercise,
              let setGroup = currentSetGroup else { return }

        // Check if this exercise is in a superset
        if let supersetId = exercise.supersetGroupId {
            advanceInSuperset(module: module, supersetId: supersetId, setGroup: setGroup)
        } else {
            // Normal (non-superset) flow
            advanceNormally(module: module, exercise: exercise, setGroup: setGroup)
        }
    }

    /// Handles superset navigation (A→B→A→B pattern)
    private mutating func advanceInSuperset(module: CompletedModule, supersetId: UUID, setGroup: CompletedSetGroup) {
        // Find all exercises in this superset
        let supersetIndices = module.completedExercises.enumerated()
            .filter { $0.element.supersetGroupId == supersetId }
            .map { $0.offset }

        guard let currentSupersetPosition = supersetIndices.firstIndex(of: currentExerciseIndex) else {
            // Fallback to normal flow if something is wrong
            if let exercise = currentExercise {
                advanceNormally(module: module, exercise: exercise, setGroup: setGroup)
            }
            return
        }

        let isLastInSuperset = currentSupersetPosition == supersetIndices.count - 1

        if isLastInSuperset {
            // We've done all exercises in the superset for this set
            // Check if there are more sets
            if currentSetIndex < setGroup.sets.count - 1 {
                // Go back to first exercise in superset, next set number
                currentExerciseIndex = supersetIndices[0]
                currentSetIndex += 1
            } else {
                // Superset round complete, move to next set group or next non-superset exercise
                moveToNextAfterSuperset(module: module, supersetIndices: supersetIndices)
            }
        } else {
            // Move to next exercise in superset, same set number
            currentExerciseIndex = supersetIndices[currentSupersetPosition + 1]
            // Keep same setGroupIndex and setIndex
        }
    }

    /// Normal (non-superset) advancement through the workout
    private mutating func advanceNormally(module: CompletedModule, exercise: SessionExercise, setGroup: CompletedSetGroup) {
        if currentSetIndex < setGroup.sets.count - 1 {
            // Next set in current set group
            currentSetIndex += 1
        } else if currentSetGroupIndex < exercise.completedSetGroups.count - 1 {
            // Next set group
            currentSetGroupIndex += 1
            currentSetIndex = 0
        } else if currentExerciseIndex < module.completedExercises.count - 1 {
            // Next exercise
            currentExerciseIndex += 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < modules.count - 1 {
            // Next module
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: end of workout (stay at current position)
    }

    /// Moves to the next exercise/module after completing a superset
    private mutating func moveToNextAfterSuperset(module: CompletedModule, supersetIndices: [Int]) {
        // Find the first exercise index after the superset
        let maxSupersetIndex = supersetIndices.max() ?? currentExerciseIndex

        if maxSupersetIndex < module.completedExercises.count - 1 {
            // Move to next exercise after superset
            currentExerciseIndex = maxSupersetIndex + 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < modules.count - 1 {
            // Move to next module
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: end of workout (stay at current position)
    }

    /// Skips the current exercise and moves to the next one
    mutating func skipExercise() {
        guard let module = currentModule else { return }

        if currentExerciseIndex < module.completedExercises.count - 1 {
            currentExerciseIndex += 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < modules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: at end of workout, can't skip further
    }

    /// Skips the current module and moves to the next one
    /// Returns the module ID that was skipped (for tracking)
    mutating func skipModule() -> UUID? {
        guard let module = currentModule else { return nil }

        let skippedModuleId = module.moduleId

        if currentModuleIndex < modules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
        // else: at last module, can't skip further

        return skippedModuleId
    }

    /// Resets navigation to the beginning
    mutating func reset() {
        currentModuleIndex = 0
        currentExerciseIndex = 0
        currentSetGroupIndex = 0
        currentSetIndex = 0
    }

    // MARK: - Direct Navigation (for UI controls)

    /// Sets the current position directly (for jumping to specific locations)
    mutating func setPosition(
        moduleIndex: Int? = nil,
        exerciseIndex: Int? = nil,
        setGroupIndex: Int? = nil,
        setIndex: Int? = nil
    ) {
        if let moduleIndex = moduleIndex {
            currentModuleIndex = max(0, min(moduleIndex, modules.count - 1))
        }
        if let exerciseIndex = exerciseIndex, let module = currentModule {
            currentExerciseIndex = max(0, min(exerciseIndex, module.completedExercises.count - 1))
        }
        if let setGroupIndex = setGroupIndex, let exercise = currentExercise {
            currentSetGroupIndex = max(0, min(setGroupIndex, exercise.completedSetGroups.count - 1))
        }
        if let setIndex = setIndex, let setGroup = currentSetGroup {
            currentSetIndex = max(0, min(setIndex, setGroup.sets.count - 1))
        }
    }

    /// Goes to the previous exercise (for "back" navigation)
    mutating func goToPreviousExercise() {
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex > 0 {
            // Go to last exercise of previous module
            currentModuleIndex -= 1
            if let module = currentModule {
                currentExerciseIndex = max(0, module.completedExercises.count - 1)
                currentSetGroupIndex = 0
                currentSetIndex = 0
            }
        }
    }

    /// Goes to the next exercise (skipping remaining sets)
    mutating func goToNextExercise() {
        guard let module = currentModule else { return }

        if currentExerciseIndex < module.completedExercises.count - 1 {
            currentExerciseIndex += 1
            currentSetGroupIndex = 0
            currentSetIndex = 0
        } else if currentModuleIndex < modules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
    }

    /// Goes to the next module (skipping remaining exercises)
    mutating func goToNextModule() {
        if currentModuleIndex < modules.count - 1 {
            currentModuleIndex += 1
            currentExerciseIndex = 0
            currentSetGroupIndex = 0
            currentSetIndex = 0
        }
    }

    /// Moves to a specific exercise within the current module
    mutating func moveToExercise(_ index: Int) {
        guard let module = currentModule else { return }
        currentExerciseIndex = max(0, min(index, module.completedExercises.count - 1))
        currentSetGroupIndex = 0
        currentSetIndex = 0
    }

    /// Jumps to a specific set within the current exercise
    mutating func jumpToSet(setGroupIndex: Int, setIndex: Int) {
        guard let exercise = currentExercise else { return }
        currentSetGroupIndex = max(0, min(setGroupIndex, exercise.completedSetGroups.count - 1))
        if let setGroup = currentSetGroup {
            currentSetIndex = max(0, min(setIndex, setGroup.sets.count - 1))
        }
    }

    // MARK: - Progress Tracking

    /// Calculates overall progress as a percentage (0.0 to 1.0)
    var overallProgress: Double {
        let totalSets = modules.reduce(0) { moduleSum, module in
            moduleSum + module.completedExercises.reduce(0) { exerciseSum, exercise in
                exerciseSum + exercise.completedSetGroups.reduce(0) { setGroupSum, setGroup in
                    setGroupSum + setGroup.sets.count
                }
            }
        }

        guard totalSets > 0 else { return 0 }

        var completedSets = 0

        // Count sets in completed modules
        for i in 0..<currentModuleIndex {
            for exercise in modules[i].completedExercises {
                for setGroup in exercise.completedSetGroups {
                    completedSets += setGroup.sets.count
                }
            }
        }

        // Count sets in current module up to current exercise
        if let module = currentModule {
            for i in 0..<currentExerciseIndex {
                for setGroup in module.completedExercises[i].completedSetGroups {
                    completedSets += setGroup.sets.count
                }
            }

            // Count sets in current exercise up to current set group
            if let exercise = currentExercise {
                for i in 0..<currentSetGroupIndex {
                    completedSets += exercise.completedSetGroups[i].sets.count
                }

                // Count sets in current set group up to current set
                completedSets += currentSetIndex
            }
        }

        return Double(completedSets) / Double(totalSets)
    }
}
