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

    private struct OutcomeDecision {
        let outcome: ProgressionRecommendation
        let rationale: String
        let confidence: Double
        let code: String
        let factors: [String]
    }

    private struct RepGateDecision {
        let outcome: ProgressionRecommendation
        let targetReps: Int
        let achievedReps: Int
        let setsAtTarget: Int
        let totalSets: Int
    }

    private struct DecisionSignals {
        let completion: Double
        let performance: Double
        let effort: Double
        let confidence: Double
        let streak: Double
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
            guard isProgressionSupported(exercise) else { continue }

            // Get the exercise instance ID for this session exercise
            guard let exerciseInstanceId = exerciseInstanceIds[exercise.id] else {
                continue
            }

            // Check if this specific exercise has progression enabled
            guard program.isProgressionEnabled(for: exerciseInstanceId) else {
                continue
            }

            // Get the progression rule for this exercise (override or default)
            guard let baseRule = program.progressionRuleForExercise(exerciseInstanceId) else {
                continue
            }

            let profile = program.progressionProfileForExercise(
                exerciseInstanceId,
                exerciseType: exercise.exerciseType
            )
            let rule = normalizedRule(
                from: baseRule,
                for: exercise,
                profile: profile
            )
            let progressionState = program.progressionState(for: exerciseInstanceId)

            // Find last session data for this exercise within this workout
            guard let lastExerciseData = findLastSessionData(
                exerciseInstanceId: exerciseInstanceId,
                exerciseName: exercise.exerciseName,
                exerciseType: exercise.exerciseType,
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
                mode: .adaptive,
                progressionState: progressionState,
                profile: profile
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
            guard isProgressionSupported(exercise) else { continue }

            // Get the default progression rule
            guard let baseRule = program.defaultProgressionRule else {
                continue
            }
            let profile = program.defaultProgressionProfile ?? defaultProfile(for: exercise.exerciseType)
            let rule = normalizedRule(from: baseRule, for: exercise, profile: profile)

            // Find last session data for this exercise within this workout
            guard let lastExerciseData = findLastSessionData(
                exerciseName: exercise.exerciseName,
                exerciseType: exercise.exerciseType,
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
                mode: .legacy,
                progressionState: nil,
                profile: profile
            ) {
                suggestions[exercise.id] = suggestion
            }
        }

        return suggestions
    }

    /// Infer a progression outcome for a completed exercise.
    /// Priority: explicit user recommendation -> suggestion/performance comparison.
    func inferProgressionOutcome(
        for exercise: SessionExercise,
        suggestion: ProgressionSuggestion?
    ) -> ProgressionRecommendation? {
        if let explicit = exercise.progressionRecommendation {
            return explicit
        }

        guard let suggestion else { return nil }

        switch suggestion.metric {
        case .weight:
            guard let maxWeight = maximumCompletedWeight(in: exercise) else { return nil }
            if maxWeight >= suggestion.suggestedValue - 0.01 {
                return .progress
            }
            if maxWeight <= suggestion.baseValue * 0.9 {
                return .regress
            }
            return .stay

        case .reps:
            guard let maxReps = maximumCompletedReps(in: exercise) else { return nil }
            let suggestedReps = Int(round(suggestion.suggestedValue))
            let baseReps = Int(round(suggestion.baseValue))
            if maxReps >= suggestedReps {
                return .progress
            }
            if maxReps < max(1, baseReps - 1) {
                return .regress
            }
            return .stay
        case .duration:
            guard let maxDuration = maximumCompletedDuration(in: exercise) else { return nil }
            if Double(maxDuration) >= suggestion.suggestedValue - 0.5 {
                return .progress
            }
            if Double(maxDuration) <= suggestion.baseValue * 0.9 {
                return .regress
            }
            return .stay
        case .distance:
            guard let maxDistance = maximumCompletedDistance(in: exercise) else { return nil }
            if maxDistance >= suggestion.suggestedValue - 0.01 {
                return .progress
            }
            if maxDistance <= suggestion.baseValue * 0.9 {
                return .regress
            }
            return .stay
        }
    }

    /// Update stateful progression context after a completed session.
    func updateProgressionState(
        current: ExerciseProgressionState?,
        exercise: SessionExercise,
        outcome: ProgressionRecommendation,
        suggestion: ProgressionSuggestion? = nil,
        at date: Date = Date()
    ) -> ExerciseProgressionState {
        var state = current ?? ExerciseProgressionState()

        if let maxWeight = maximumCompletedWeight(in: exercise) {
            state.lastPrescribedWeight = maxWeight
        }
        if let maxReps = maximumCompletedReps(in: exercise) {
            state.lastPrescribedReps = maxReps
        }
        if let maxDuration = maximumCompletedDuration(in: exercise) {
            state.lastPrescribedDuration = maxDuration
        }
        if let maxDistance = maximumCompletedDistance(in: exercise) {
            state.lastPrescribedDistance = maxDistance
        }

        switch outcome {
        case .progress:
            state.successStreak += 1
            state.failStreak = 0
            state.confidence = min(1, state.confidence + 0.08)
        case .stay:
            state.successStreak = max(0, state.successStreak - 1)
            state.failStreak = max(0, state.failStreak - 1)
            state.confidence += (0.5 - state.confidence) * 0.05
        case .regress:
            state.failStreak += 1
            state.successStreak = 0
            state.confidence = max(0, state.confidence - 0.12)
        }

        state.recentOutcomes.insert(outcome, at: 0)
        state.recentOutcomes = Array(state.recentOutcomes.prefix(3))
        state.lastUpdatedAt = date

        if let suggestion, let suggestedOutcome = preferredOutcome(from: suggestion) {
            state.suggestionsPresented += 1
            if outcome == suggestedOutcome {
                state.suggestionsAccepted += 1
            } else {
                state.suggestionsDismissed += 1
            }
        }

        return state
    }

    // MARK: - Private Helpers

    /// Find the most recent completed exercise data for an exercise name within a specific workout
    private func findLastSessionData(
        exerciseInstanceId: UUID? = nil,
        exerciseName: String,
        exerciseType: ExerciseType,
        workoutId: UUID,
        history: [Session]
    ) -> SessionExercise? {
        // Find the most recent session with this workout that has the exercise
        for session in history where session.workoutId == workoutId {
            for module in session.completedModules where !module.skipped {
                if let exerciseInstanceId,
                   let exercise = module.completedExercises.first(where: {
                       $0.sourceExerciseInstanceId == exerciseInstanceId && hasCompletedData($0, exerciseType: exerciseType)
                   }) {
                    return exercise
                }

                if let exercise = module.completedExercises.first(where: {
                    $0.exerciseName == exerciseName && hasCompletedData($0, exerciseType: exerciseType)
                }) {
                    return exercise
                }
            }
        }
        return nil
    }

    /// Check if an exercise has completed sets with progression-relevant data.
    private func hasCompletedData(_ exercise: SessionExercise, exerciseType: ExerciseType) -> Bool {
        exercise.completedSetGroups.contains { group in
            group.sets.contains { set in
                guard set.completed else { return false }
                switch exerciseType {
                case .strength:
                    return set.weight != nil && set.reps != nil
                case .cardio:
                    return set.duration != nil || set.distance != nil
                default:
                    return false
                }
            }
        }
    }

    /// Calculate a progression suggestion based on the last exercise data and rule
    private func calculateSuggestion(
        from lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        rule: ProgressionRule,
        mode: SuggestionMode,
        progressionState: ExerciseProgressionState?,
        profile: ProgressionProfile
    ) -> ProgressionSuggestion? {

        let linearSuggestion: ProgressionSuggestion?
        switch rule.targetMetric {
        case .weight:
            linearSuggestion = calculateWeightSuggestion(from: lastExercise, rule: rule)
        case .reps:
            linearSuggestion = calculateRepsSuggestion(from: lastExercise, rule: rule)
        case .duration:
            linearSuggestion = calculateDurationSuggestion(from: lastExercise, rule: rule)
        case .distance:
            linearSuggestion = calculateDistanceSuggestion(from: lastExercise, rule: rule)
        }

        guard let linearSuggestion else { return nil }
        guard mode == .adaptive else { return linearSuggestion }

        let repGateDecision = automaticOutcomeIfNeeded(
            lastExercise: lastExercise,
            currentExercise: currentExercise,
            rule: rule
        )
        let referenceDate = currentExercise.date ?? Date()
        let staleState = progressionState.map {
            isProgressionStateStale(
                $0,
                referenceDate: referenceDate,
                staleAfterDays: profile.readinessGate.staleAfterDays
            )
        } ?? false
        let weightedDecision = weightedOutcomeDecision(
            state: progressionState,
            staleState: staleState,
            lastExercise: lastExercise,
            currentExercise: currentExercise,
            suggestion: linearSuggestion,
            profile: profile
        )

        let manualDecision = lastExercise.progressionRecommendation.map { recommendation in
            OutcomeDecision(
                outcome: recommendation,
                rationale: "Using your previous session choice (\(recommendation.displayName.lowercased())).",
                confidence: 0.95,
                code: "MANUAL_OVERRIDE",
                factors: ["Previous manual choice", "Highest priority input"]
            )
        }

        let automaticDecision = repGateDecision.map { decision in
            OutcomeDecision(
                outcome: decision.outcome,
                rationale: "Rep gate: \(decision.setsAtTarget)/\(decision.totalSets) sets hit \(decision.targetReps) reps last session.",
                confidence: 0.78,
                code: "DOUBLE_PROGRESSION_GATE",
                factors: [
                    "Rep gate \(decision.setsAtTarget)/\(decision.totalSets)",
                    "Target reps \(decision.targetReps)"
                ]
            )
        }

        if let decision = manualDecision ?? automaticDecision ?? weightedDecision {
            return applyOutcome(
                decision,
                to: linearSuggestion,
                rule: rule,
                profile: profile
            )
        }

        if staleState {
            return attachMetadata(
                to: linearSuggestion,
                rationale: "Using baseline progression because learned state is stale.",
                confidence: 0.5,
                decisionCode: "STATE_STALE_BASELINE",
                decisionFactors: ["State freshness exceeded", "Fallback to baseline rule"]
            )
        }

        return attachMetadata(
            to: linearSuggestion,
            rationale: "No recent outcome override; using baseline progression.",
            confidence: 0.56,
            decisionCode: "BASELINE_RULE",
            decisionFactors: ["No override available", "Rule-based default suggestion"]
        )
    }

    private func weightedOutcomeDecision(
        state: ExerciseProgressionState?,
        staleState: Bool,
        lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        suggestion: ProgressionSuggestion,
        profile: ProgressionProfile
    ) -> OutcomeDecision? {
        let observedValues = metricValues(for: suggestion.metric, in: lastExercise)
        guard !observedValues.isEmpty else {
            return nil
        }

        let expectedSetCount = targetSetCount(for: suggestion.metric, in: currentExercise)
        let completionRatio = expectedSetCount > 0
            ? min(1, Double(observedValues.count) / Double(expectedSetCount))
            : 1

        if observedValues.count < ruleBasedMinimumSetCount(for: suggestion.metric, profile: profile) ||
            completionRatio < profile.readinessGate.minimumCompletedSetRatio {
            return OutcomeDecision(
                outcome: .stay,
                rationale: "Holding steady: completion gate not met (\(observedValues.count)/\(max(expectedSetCount, 1)) sets).",
                confidence: 0.72,
                code: "READINESS_GATE_STAY",
                factors: [
                    "Completed sets \(observedValues.count)/\(max(expectedSetCount, 1))",
                    "Completion ratio \(Int((completionRatio * 100).rounded()))%"
                ]
            )
        }

        let signals = buildSignals(
            completionRatio: completionRatio,
            lastExercise: lastExercise,
            currentExercise: currentExercise,
            suggestion: suggestion,
            state: staleState ? nil : state
        )

        let weights = normalizedWeights(from: profile.decisionPolicy)
        let score =
            (signals.completion * weights.completionWeight) +
            (signals.performance * weights.performanceWeight) +
            (signals.effort * weights.effortWeight) +
            (signals.confidence * weights.confidenceWeight) +
            (signals.streak * weights.streakWeight)

        if score >= profile.decisionPolicy.progressThreshold {
            let factors = topFactors(
                for: signals,
                weights: weights,
                limit: 2
            )
            return OutcomeDecision(
                outcome: .progress,
                rationale: "Progress score \(Int((score * 100).rounded())): strong completion and readiness signals.",
                confidence: min(0.9, 0.55 + (score - profile.decisionPolicy.progressThreshold)),
                code: "WEIGHTED_PROGRESS",
                factors: factors
            )
        }

        if score <= profile.decisionPolicy.regressThreshold {
            let factors = topFactors(
                for: signals,
                weights: weights,
                limit: 2
            )
            return OutcomeDecision(
                outcome: .regress,
                rationale: "Regress score \(Int((score * 100).rounded())): fatigue/readiness signals are below threshold.",
                confidence: min(0.9, 0.55 + (profile.decisionPolicy.regressThreshold - score)),
                code: "WEIGHTED_REGRESS",
                factors: factors
            )
        }

        let factors = topFactors(
            for: signals,
            weights: weights,
            limit: 2
        )
        return OutcomeDecision(
            outcome: .stay,
            rationale: "Stay score \(Int((score * 100).rounded())): hold load until signals are clearer.",
            confidence: 0.58,
            code: "WEIGHTED_STAY",
            factors: factors
        )
    }

    private func automaticOutcomeIfNeeded(
        lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        rule: ProgressionRule
    ) -> RepGateDecision? {
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

        let completedSets = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && ($0.weight ?? 0) > 0 }
            .compactMap(\.reps)

        guard !completedSets.isEmpty else {
            return nil
        }

        let totalSets = completedSets.count
        let setsAtTarget = completedSets.filter { $0 >= targetReps }.count
        let achievedReps = completedSets.max() ?? 0

        return RepGateDecision(
            outcome: setsAtTarget == totalSets ? .progress : .stay,
            targetReps: targetReps,
            achievedReps: achievedReps,
            setsAtTarget: setsAtTarget,
            totalSets: totalSets
        )
    }

    private func isProgressionStateStale(
        _ state: ExerciseProgressionState,
        referenceDate: Date,
        staleAfterDays: Int
    ) -> Bool {
        guard let lastUpdatedAt = state.lastUpdatedAt else { return false }

        let days = Calendar.current.dateComponents([.day], from: lastUpdatedAt, to: referenceDate).day ?? 0
        return days >= staleAfterDays
    }

    private func applyOutcome(
        _ decision: OutcomeDecision,
        to suggestion: ProgressionSuggestion,
        rule: ProgressionRule,
        profile: ProgressionProfile
    ) -> ProgressionSuggestion {
        let outcome = decision.outcome
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

            let clamped = applyGuardrails(
                adjusted,
                base: base,
                metric: .weight,
                outcome: outcome,
                guardrails: profile.guardrails
            )
            let percent = base > 0 ? ((adjusted - base) / base) * 100.0 : 0
            return ProgressionSuggestion(
                baseValue: base,
                suggestedValue: clamped,
                metric: .weight,
                percentageApplied: base > 0 ? ((clamped - base) / base) * 100.0 : percent,
                appliedOutcome: outcome,
                isOutcomeAdjusted: true,
                rationale: decision.rationale,
                confidence: decision.confidence,
                decisionCode: decision.code,
                decisionFactors: decision.factors
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

            let clamped = applyGuardrails(
                adjusted,
                base: base,
                metric: .reps,
                outcome: outcome,
                guardrails: profile.guardrails
            )
            let percent = base > 0 ? ((adjusted - base) / base) * 100.0 : 0
            return ProgressionSuggestion(
                baseValue: base,
                suggestedValue: clamped,
                metric: .reps,
                percentageApplied: base > 0 ? ((clamped - base) / base) * 100.0 : percent,
                appliedOutcome: outcome,
                isOutcomeAdjusted: true,
                rationale: decision.rationale,
                confidence: decision.confidence,
                decisionCode: decision.code,
                decisionFactors: decision.factors
            )
        case .duration, .distance:
            let minimumStep = rule.minimumIncrease ?? rule.roundingIncrement
            let delta = max(progressed - base, minimumStep)
            let adjusted: Double
            switch outcome {
            case .progress:
                adjusted = progressed
            case .stay:
                adjusted = base
            case .regress:
                adjusted = max(0, base - delta)
            }

            let clamped = applyGuardrails(
                adjusted,
                base: base,
                metric: suggestion.metric,
                outcome: outcome,
                guardrails: profile.guardrails
            )
            let percent = base > 0 ? ((clamped - base) / base) * 100.0 : 0
            return ProgressionSuggestion(
                baseValue: base,
                suggestedValue: clamped,
                metric: suggestion.metric,
                percentageApplied: percent,
                appliedOutcome: outcome,
                isOutcomeAdjusted: true,
                rationale: decision.rationale,
                confidence: decision.confidence,
                decisionCode: decision.code,
                decisionFactors: decision.factors
            )
        }
    }

    private func attachMetadata(
        to suggestion: ProgressionSuggestion,
        rationale: String,
        confidence: Double,
        decisionCode: String? = nil,
        decisionFactors: [String]? = nil
    ) -> ProgressionSuggestion {
        ProgressionSuggestion(
            baseValue: suggestion.baseValue,
            suggestedValue: suggestion.suggestedValue,
            metric: suggestion.metric,
            percentageApplied: suggestion.percentageApplied,
            appliedOutcome: suggestion.appliedOutcome,
            isOutcomeAdjusted: suggestion.isOutcomeAdjusted,
            rationale: rationale,
            confidence: confidence,
            decisionCode: decisionCode,
            decisionFactors: decisionFactors
        )
    }

    private func isProgressionSupported(_ exercise: SessionExercise) -> Bool {
        exercise.exerciseType == .strength || exercise.exerciseType == .cardio
    }

    private func defaultProfile(for exerciseType: ExerciseType) -> ProgressionProfile {
        switch exerciseType {
        case .cardio:
            return .cardioDefault
        default:
            return .strengthDefault
        }
    }

    private func normalizedRule(
        from baseRule: ProgressionRule,
        for exercise: SessionExercise,
        profile: ProgressionProfile
    ) -> ProgressionRule {
        var rule = baseRule

        if let preferredMetric = profile.preferredMetric {
            rule.targetMetric = preferredMetric
        }

        if exercise.exerciseType == .cardio {
            let cardioMetric: ProgressionMetric
            if rule.targetMetric == .duration || rule.targetMetric == .distance {
                cardioMetric = rule.targetMetric
            } else if exercise.cardioMetric.tracksDistance {
                cardioMetric = .distance
            } else {
                cardioMetric = .duration
            }

            rule.targetMetric = cardioMetric
            rule.strategy = .linear

            if baseRule.targetMetric == .weight || baseRule.targetMetric == .reps {
                switch cardioMetric {
                case .duration:
                    rule.roundingIncrement = 30
                    rule.minimumIncrease = 30
                case .distance:
                    rule.roundingIncrement = 0.05
                    rule.minimumIncrease = 0.05
                default:
                    break
                }
            }
        }

        return rule
    }

    private func metricValues(
        for metric: ProgressionMetric,
        in exercise: SessionExercise
    ) -> [Double] {
        let completedSets = exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter(\.completed)

        switch metric {
        case .weight:
            return completedSets.compactMap(\.weight)
        case .reps:
            return completedSets.compactMap(\.reps).map(Double.init)
        case .duration:
            return completedSets.compactMap(\.duration).map(Double.init)
        case .distance:
            return completedSets.compactMap(\.distance)
        }
    }

    private func targetSetCount(
        for metric: ProgressionMetric,
        in exercise: SessionExercise
    ) -> Int {
        let sets = exercise.completedSetGroups.flatMap { $0.sets }
        switch metric {
        case .weight:
            return sets.filter { $0.weight != nil }.count
        case .reps:
            return sets.filter { $0.reps != nil }.count
        case .duration:
            return sets.filter { $0.duration != nil }.count
        case .distance:
            return sets.filter { $0.distance != nil }.count
        }
    }

    private func ruleBasedMinimumSetCount(
        for metric: ProgressionMetric,
        profile: ProgressionProfile
    ) -> Int {
        switch metric {
        case .duration, .distance:
            return max(1, profile.readinessGate.minimumCompletedSets)
        default:
            return max(1, profile.readinessGate.minimumCompletedSets)
        }
    }

    private func normalizedWeights(
        from policy: ProgressionDecisionPolicy
    ) -> ProgressionDecisionPolicy {
        let total =
            policy.completionWeight +
            policy.performanceWeight +
            policy.effortWeight +
            policy.confidenceWeight +
            policy.streakWeight

        guard total > 0 else { return policy }

        return ProgressionDecisionPolicy(
            progressThreshold: policy.progressThreshold,
            regressThreshold: policy.regressThreshold,
            completionWeight: policy.completionWeight / total,
            performanceWeight: policy.performanceWeight / total,
            effortWeight: policy.effortWeight / total,
            confidenceWeight: policy.confidenceWeight / total,
            streakWeight: policy.streakWeight / total
        )
    }

    private func buildSignals(
        completionRatio: Double,
        lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        suggestion: ProgressionSuggestion,
        state: ExerciseProgressionState?
    ) -> DecisionSignals {
        let performance = metricPerformanceSignal(
            metric: suggestion.metric,
            lastExercise: lastExercise,
            currentExercise: currentExercise,
            baseValue: suggestion.baseValue
        )
        let effort = effortSignal(for: suggestion.metric, in: lastExercise)
        let confidence = state?.confidence ?? 0.5

        let streakSignal: Double
        if let state {
            let streakDelta = Double(state.successStreak - state.failStreak)
            streakSignal = min(max(0.5 + (streakDelta * 0.1), 0), 1)
        } else {
            streakSignal = 0.5
        }

        return DecisionSignals(
            completion: min(max(completionRatio, 0), 1),
            performance: performance,
            effort: effort,
            confidence: min(max(confidence, 0), 1),
            streak: streakSignal
        )
    }

    private func topFactors(
        for signals: DecisionSignals,
        weights: ProgressionDecisionPolicy,
        limit: Int
    ) -> [String] {
        let weightedSignals: [(label: String, score: Double)] = [
            ("Completion \(Int((signals.completion * 100).rounded()))%", signals.completion * weights.completionWeight),
            ("Performance \(Int((signals.performance * 100).rounded()))%", signals.performance * weights.performanceWeight),
            ("Effort \(Int((signals.effort * 100).rounded()))%", signals.effort * weights.effortWeight),
            ("Confidence \(Int((signals.confidence * 100).rounded()))%", signals.confidence * weights.confidenceWeight),
            ("Streak \(Int((signals.streak * 100).rounded()))%", signals.streak * weights.streakWeight)
        ]

        return weightedSignals
            .sorted { $0.score > $1.score }
            .prefix(max(1, limit))
            .map(\.label)
    }

    private func metricPerformanceSignal(
        metric: ProgressionMetric,
        lastExercise: SessionExercise,
        currentExercise: SessionExercise,
        baseValue: Double
    ) -> Double {
        let safeBase = max(baseValue, 1)
        switch metric {
        case .weight:
            let targetReps = currentExercise.completedSetGroups
                .flatMap { $0.sets }
                .compactMap(\.reps)
                .max()
            let achievedReps = maximumCompletedReps(in: lastExercise)
            if let targetReps, let achievedReps, targetReps > 0 {
                return min(max(Double(achievedReps) / Double(targetReps), 0), 1)
            }
            let achievedWeight = maximumCompletedWeight(in: lastExercise) ?? 0
            return min(max(achievedWeight / safeBase, 0), 1)
        case .reps:
            let targetReps = currentExercise.completedSetGroups
                .flatMap { $0.sets }
                .compactMap(\.reps)
                .max()
            let achievedReps = maximumCompletedReps(in: lastExercise) ?? 0
            if let targetReps, targetReps > 0 {
                return min(max(Double(achievedReps) / Double(targetReps), 0), 1)
            }
            return min(max(Double(achievedReps) / safeBase, 0), 1)
        case .duration:
            let targetDuration = currentExercise.completedSetGroups
                .flatMap { $0.sets }
                .compactMap(\.duration)
                .max()
            let achievedDuration = maximumCompletedDuration(in: lastExercise) ?? 0
            if let targetDuration, targetDuration > 0 {
                return min(max(Double(achievedDuration) / Double(targetDuration), 0), 1)
            }
            return min(max(Double(achievedDuration) / safeBase, 0), 1)
        case .distance:
            let targetDistance = currentExercise.completedSetGroups
                .flatMap { $0.sets }
                .compactMap(\.distance)
                .max()
            let achievedDistance = maximumCompletedDistance(in: lastExercise) ?? 0
            if let targetDistance, targetDistance > 0 {
                return min(max(achievedDistance / targetDistance, 0), 1)
            }
            return min(max(achievedDistance / safeBase, 0), 1)
        }
    }

    private func preferredOutcome(from suggestion: ProgressionSuggestion) -> ProgressionRecommendation? {
        if let outcome = suggestion.appliedOutcome {
            return outcome
        }

        if suggestion.suggestedValue > suggestion.baseValue + 0.0001 {
            return .progress
        }
        if suggestion.suggestedValue < suggestion.baseValue - 0.0001 {
            return .regress
        }
        return .stay
    }

    private func effortSignal(for metric: ProgressionMetric, in exercise: SessionExercise) -> Double {
        switch metric {
        case .weight, .reps:
            guard let averageRPE = averageCompletedRPE(in: exercise) else { return 0.6 }
            return min(max((10.0 - averageRPE) / 3.0, 0), 1)
        case .duration, .distance:
            guard let averageHeartRate = averageCompletedHeartRate(in: exercise) else { return 0.55 }
            switch averageHeartRate {
            case ..<145: return 0.75
            case 145..<165: return 0.6
            case 165..<180: return 0.4
            default: return 0.25
            }
        }
    }

    private func applyGuardrails(
        _ proposed: Double,
        base: Double,
        metric: ProgressionMetric,
        outcome: ProgressionRecommendation,
        guardrails: ProgressionGuardrails
    ) -> Double {
        var adjusted = proposed

        if let floor = guardrails.floorValue {
            adjusted = max(adjusted, floor)
        }
        if let ceiling = guardrails.ceilingValue {
            adjusted = min(adjusted, ceiling)
        }

        if base > 0 {
            if outcome == .progress, let maxProgressPercent = guardrails.maxProgressPercent {
                adjusted = min(adjusted, base * (1 + (maxProgressPercent / 100)))
            }
            if outcome == .regress, let maxRegressPercent = guardrails.maxRegressPercent {
                adjusted = max(adjusted, base * (1 - (maxRegressPercent / 100)))
            }
        }

        if let minimumStep = guardrails.minimumAbsoluteStep, outcome != .stay {
            switch outcome {
            case .progress:
                adjusted = max(adjusted, base + minimumStep)
            case .regress:
                adjusted = min(adjusted, max(0, base - minimumStep))
            case .stay:
                break
            }
        }

        // Re-apply percent guardrails so minimum step cannot override hard caps.
        if base > 0 {
            if outcome == .progress, let maxProgressPercent = guardrails.maxProgressPercent {
                adjusted = min(adjusted, base * (1 + (maxProgressPercent / 100)))
            }
            if outcome == .regress, let maxRegressPercent = guardrails.maxRegressPercent {
                adjusted = max(adjusted, base * (1 - (maxRegressPercent / 100)))
            }
        }

        switch metric {
        case .reps:
            return max(1, round(adjusted))
        case .duration:
            return max(1, round(adjusted))
        case .weight:
            return max(0, adjusted)
        case .distance:
            return max(0, adjusted)
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

    private func calculateDurationSuggestion(
        from lastExercise: SessionExercise,
        rule: ProgressionRule
    ) -> ProgressionSuggestion? {
        let allCompletedSets = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && $0.duration != nil }

        guard let maxDuration = allCompletedSets.compactMap({ $0.duration }).max(),
              maxDuration > 0 else {
            return nil
        }

        let baseValue = Double(maxDuration)
        var increase = baseValue * (rule.percentageIncrease / 100.0)
        if let minIncrease = rule.minimumIncrease {
            increase = max(increase, minIncrease)
        }

        let rawSuggested = baseValue + increase
        let rounded = round(rawSuggested / rule.roundingIncrement) * rule.roundingIncrement
        let finalSuggested = max(rounded, baseValue + rule.roundingIncrement)
        let actualPercent = ((finalSuggested - baseValue) / baseValue) * 100.0

        return ProgressionSuggestion(
            baseValue: baseValue,
            suggestedValue: finalSuggested,
            metric: .duration,
            percentageApplied: actualPercent
        )
    }

    private func calculateDistanceSuggestion(
        from lastExercise: SessionExercise,
        rule: ProgressionRule
    ) -> ProgressionSuggestion? {
        let allCompletedSets = lastExercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && $0.distance != nil }

        guard let maxDistance = allCompletedSets.compactMap({ $0.distance }).max(),
              maxDistance > 0 else {
            return nil
        }

        var increase = maxDistance * (rule.percentageIncrease / 100.0)
        if let minIncrease = rule.minimumIncrease {
            increase = max(increase, minIncrease)
        }

        let rawSuggested = maxDistance + increase
        let rounded = round(rawSuggested / rule.roundingIncrement) * rule.roundingIncrement
        let finalSuggested = max(rounded, maxDistance + rule.roundingIncrement)
        let actualPercent = ((finalSuggested - maxDistance) / maxDistance) * 100.0

        return ProgressionSuggestion(
            baseValue: maxDistance,
            suggestedValue: finalSuggested,
            metric: .distance,
            percentageApplied: actualPercent
        )
    }

    private func maximumCompletedWeight(in exercise: SessionExercise) -> Double? {
        exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.weight)
            .max()
    }

    private func maximumCompletedReps(in exercise: SessionExercise) -> Int? {
        exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.reps)
            .max()
    }

    private func maximumCompletedDuration(in exercise: SessionExercise) -> Int? {
        exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.duration)
            .max()
    }

    private func maximumCompletedDistance(in exercise: SessionExercise) -> Double? {
        exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.distance)
            .max()
    }

    private func averageCompletedRPE(in exercise: SessionExercise) -> Double? {
        let values = exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.rpe)
            .map(Double.init)

        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }

    private func averageCompletedHeartRate(in exercise: SessionExercise) -> Double? {
        let values = exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .compactMap(\.avgHeartRate)
            .map(Double.init)

        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }
}
