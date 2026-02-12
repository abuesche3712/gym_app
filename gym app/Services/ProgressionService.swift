//
//  ProgressionService.swift
//  gym app
//
//  Calculates progression suggestions for exercises based on previous session data
//

import Foundation

struct ProgressionService {

    private enum SuggestionMode {
        case legacy
        case adaptive
    }

    // MARK: - Public API

    /// Calculate progression suggestions for all exercises in a workout
    /// - Parameters:
    ///   - exercises: SessionExercises being started
    ///   - exerciseInstanceIds: Map of SessionExercise.id to ExerciseInstance.id (for progression lookup)
    ///   - workoutId: Current workout ID for history lookup
    ///   - program: Optional program with progression rules
    ///   - sessionHistory: Historical sessions (sorted by date descending)
    /// - Returns: Dictionary mapping exercise ID to suggestion
    func calculateSuggestions(
        for exercises: [SessionExercise],
        exerciseInstanceIds: [UUID: UUID],  // SessionExercise.id -> ExerciseInstance.id
        workoutId: UUID,
        program: Program?,
        sessionHistory: [Session]
    ) -> [UUID: ProgressionSuggestion] {

        var suggestions: [UUID: ProgressionSuggestion] = [:]
        guard let program else { return suggestions }

        // Check if progression is enabled globally
        guard program.progressionEnabled else {
            return suggestions
        }

        if program.progressionPolicy == .legacy {
            return calculateSuggestions(
                for: exercises,
                workoutId: workoutId,
                program: program,
                sessionHistory: sessionHistory
            )
        }

        for exercise in exercises {
            // Only strength exercises get progression suggestions
            guard exercise.exerciseType == .strength else { continue }

            // Get the exercise instance ID for this session exercise
            guard let exerciseInstanceId = exerciseInstanceIds[exercise.id] else {
                continue
            }

            // Check if this specific exercise has progression enabled
            guard program.isProgressionEnabled(for: exerciseInstanceId) else {
                continue
            }

            // Get the progression rule for this exercise (override or default)
            guard let rule = program.progressionRuleForExercise(exerciseInstanceId) else {
                continue
            }

            // Find last session data for this exercise within this workout
            guard let lastExerciseData = findLastSessionData(
                exerciseInstanceId: exerciseInstanceId,
                exerciseName: exercise.exerciseName,
                workoutId: workoutId,
                history: sessionHistory
            ) else {
                // No history = baseline session, no suggestion
                continue
            }

            // Calculate suggestion based on rule
            if let suggestion = calculateSuggestion(
                from: lastExerciseData,
                currentExercise: exercise,
                rule: rule,
                mode: .adaptive
            ) {
                suggestions[exercise.id] = suggestion
            }
        }

        return suggestions
    }

    /// Legacy method for backward compatibility - applies default rule to all exercises
    func calculateSuggestions(
        for exercises: [SessionExercise],
        workoutId: UUID,
        program: Program?,
        sessionHistory: [Session]
    ) -> [UUID: ProgressionSuggestion] {

        var suggestions: [UUID: ProgressionSuggestion] = [:]

        // Check if progression is enabled
        guard let program, program.progressionEnabled else {
            return suggestions
        }

        for exercise in exercises {
            // Only strength exercises get progression suggestions
            guard exercise.exerciseType == .strength else { continue }

            // Get the default progression rule
            guard let rule = program.defaultProgressionRule else {
                continue
            }

            // Find last session data for this exercise within this workout
            guard let lastExerciseData = findLastSessionData(
                exerciseName: exercise.exerciseName,
                workoutId: workoutId,
                history: sessionHistory
            ) else {
                // No history = baseline session, no suggestion
                continue
            }

            // Calculate suggestion based on rule
            if let suggestion = calculateSuggestion(
                from: lastExerciseData,
                currentExercise: exercise,
                rule: rule,
                mode: .legacy
            ) {
                suggestions[exercise.id] = suggestion
            }
        }

        return suggestions
    }

    // MARK: - Private Helpers

    /// Find the most recent completed exercise data for an exercise name within a specific workout
    private func findLastSessionData(
        exerciseInstanceId: UUID? = nil,
        exerciseName: String,
        workoutId: UUID,
        history: [Session]
    ) -> SessionExercise? {
        // Find the most recent session with this workout that has the exercise
        for session in history where session.workoutId == workoutId {
            for module in session.completedModules where !module.skipped {
                if let exerciseInstanceId,
                   let exercise = module.completedExercises.first(where: {
                       $0.sourceExerciseInstanceId == exerciseInstanceId && hasCompletedStrengthData($0)
                   }) {
                    return exercise
                }

                if let exercise = module.completedExercises.first(where: {
                    $0.exerciseName == exerciseName && hasCompletedStrengthData($0)
                }) {
                    return exercise
                }
            }
        }
        return nil
    }

    /// Check if an exercise has completed sets with actual strength data
    private func hasCompletedStrengthData(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.contains { group in
            group.sets.contains { set in
                set.completed && set.weight != nil && set.reps != nil
            }
        }
    }

    /// Calculate a progression suggestion based on the last exercise data and rule
    private func calculateSuggestion(
        from lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        rule: ProgressionRule,
        mode: SuggestionMode
    ) -> ProgressionSuggestion? {

        let linearSuggestion: ProgressionSuggestion?
        switch rule.targetMetric {
        case .weight:
            linearSuggestion = calculateWeightSuggestion(from: lastExercise, rule: rule)
        case .reps:
            linearSuggestion = calculateRepsSuggestion(from: lastExercise, rule: rule)
        }

        guard let linearSuggestion else { return nil }
        guard mode == .adaptive else { return linearSuggestion }

        let strategyOutcome = automaticOutcomeIfNeeded(
            lastExercise: lastExercise,
            currentExercise: currentExercise,
            rule: rule
        )
        let outcome = lastExercise.progressionRecommendation ?? strategyOutcome
        guard let outcome else { return linearSuggestion }

        return applyOutcome(
            outcome,
            to: linearSuggestion,
            rule: rule
        )
    }

    private func automaticOutcomeIfNeeded(
        lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        rule: ProgressionRule
    ) -> ProgressionRecommendation? {
        guard rule.targetMetric == .weight, rule.strategy == .doubleProgression else {
            return nil
        }

        // Pull target reps from the current template-driven session setup.
        let targetReps = currentExercise.completedSetGroups
            .flatMap { $0.sets }
            .compactMap(\.reps)
            .max()

        guard let targetReps, targetReps > 0 else {
            return nil
        }

        let achievedReps = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && ($0.weight ?? 0) > 0 }
            .compactMap(\.reps)
            .max() ?? 0

        return achievedReps >= targetReps ? .progress : .stay
    }

    private func applyOutcome(
        _ outcome: ProgressionRecommendation,
        to suggestion: ProgressionSuggestion,
        rule: ProgressionRule
    ) -> ProgressionSuggestion {
        let base = suggestion.baseValue
        let progressed = suggestion.suggestedValue

        switch suggestion.metric {
        case .weight:
            let delta = max(progressed - base, rule.roundingIncrement)
            let adjusted: Double
            switch outcome {
            case .progress:
                adjusted = progressed
            case .stay:
                adjusted = base
            case .regress:
                adjusted = max(0, base - delta)
            }

            let percent = base > 0 ? ((adjusted - base) / base) * 100.0 : 0
            return ProgressionSuggestion(
                baseValue: base,
                suggestedValue: adjusted,
                metric: .weight,
                percentageApplied: percent,
                appliedOutcome: outcome,
                isOutcomeAdjusted: true
            )
        case .reps:
            let delta = max(progressed - base, 1)
            let adjusted: Double
            switch outcome {
            case .progress:
                adjusted = progressed
            case .stay:
                adjusted = base
            case .regress:
                adjusted = max(1, base - delta)
            }

            let percent = base > 0 ? ((adjusted - base) / base) * 100.0 : 0
            return ProgressionSuggestion(
                baseValue: base,
                suggestedValue: adjusted,
                metric: .reps,
                percentageApplied: percent,
                appliedOutcome: outcome,
                isOutcomeAdjusted: true
            )
        }
    }

    /// Calculate weight progression suggestion
    private func calculateWeightSuggestion(
        from lastExercise: SessionExercise,
        rule: ProgressionRule
    ) -> ProgressionSuggestion? {

        // Get all completed sets with weight data
        let allCompletedSets = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && $0.weight != nil }

        // Use the maximum weight as the base (the "working weight")
        guard let maxWeight = allCompletedSets.compactMap({ $0.weight }).max(),
              maxWeight > 0 else {
            return nil
        }

        // Calculate the raw increase based on percentage
        var increase = maxWeight * (rule.percentageIncrease / 100.0)

        // Apply minimum increase if specified
        if let minIncrease = rule.minimumIncrease {
            increase = max(increase, minIncrease)
        }

        // Calculate raw suggested value
        let rawSuggested = maxWeight + increase

        // Round to the specified increment
        let rounded = round(rawSuggested / rule.roundingIncrement) * rule.roundingIncrement

        // Ensure we don't suggest the same weight (always progress by at least one increment)
        let finalSuggested = max(rounded, maxWeight + rule.roundingIncrement)

        // Calculate the actual percentage applied after rounding
        let actualPercent = ((finalSuggested - maxWeight) / maxWeight) * 100.0

        return ProgressionSuggestion(
            baseValue: maxWeight,
            suggestedValue: finalSuggested,
            metric: .weight,
            percentageApplied: actualPercent
        )
    }

    /// Calculate reps progression suggestion
    private func calculateRepsSuggestion(
        from lastExercise: SessionExercise,
        rule: ProgressionRule
    ) -> ProgressionSuggestion? {

        // Get all completed sets with reps data
        let allCompletedSets = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && $0.reps != nil }

        // Use the maximum reps as the base
        guard let maxReps = allCompletedSets.compactMap({ $0.reps }).max(),
              maxReps > 0 else {
            return nil
        }

        let baseValue = Double(maxReps)

        // Calculate the raw increase based on percentage
        var increase = baseValue * (rule.percentageIncrease / 100.0)

        // Apply minimum increase if specified
        if let minIncrease = rule.minimumIncrease {
            increase = max(increase, minIncrease)
        }

        // Calculate raw suggested value
        let rawSuggested = baseValue + increase

        // Round to the specified increment (for reps, usually 1)
        let rounded = round(rawSuggested / rule.roundingIncrement) * rule.roundingIncrement

        // Ensure we progress by at least one rep
        let finalSuggested = max(rounded, baseValue + 1)

        // Calculate the actual percentage applied after rounding
        let actualPercent = ((finalSuggested - baseValue) / baseValue) * 100.0

        return ProgressionSuggestion(
            baseValue: baseValue,
            suggestedValue: finalSuggested,
            metric: .reps,
            percentageApplied: actualPercent
        )
    }
}
