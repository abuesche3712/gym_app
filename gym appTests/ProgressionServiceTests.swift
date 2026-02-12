//
//  ProgressionServiceTests.swift
//  gym appTests
//
//  Unit tests for ProgressionService
//  Tests progression calculation logic in isolation
//

import XCTest
@testable import gym_app

final class ProgressionServiceTests: XCTestCase {

    private var service: ProgressionService!

    override func setUp() {
        super.setUp()
        service = ProgressionService()
    }

    // MARK: - Test Helpers

    /// Creates a session exercise with completed sets at the given weight
    private func makeExercise(
        name: String,
        weights: [Double],
        reps: Int = 5,
        recommendation: ProgressionRecommendation? = nil,
        sourceExerciseInstanceId: UUID? = nil
    ) -> SessionExercise {
        let sets = weights.enumerated().map { index, weight in
            SetData(
                setNumber: index + 1,
                completed: true,
                weight: weight,
                reps: reps
            )
        }

        return SessionExercise(
            exerciseId: UUID(),
            exerciseName: name,
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: sets
                )
            ],
            sourceExerciseInstanceId: sourceExerciseInstanceId,
            progressionRecommendation: recommendation
        )
    }

    /// Creates a session with the given exercises
    private func makeSession(
        workoutId: UUID,
        exercises: [SessionExercise]
    ) -> Session {
        Session(
            workoutId: workoutId,
            workoutName: "Test Workout",
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Test Module",
                    moduleType: .strength,
                    completedExercises: exercises
                )
            ]
        )
    }

    /// Creates a program with progression enabled
    private func makeProgram(
        progressionEnabled: Bool = true,
        rule: ProgressionRule = .conservative
    ) -> Program {
        Program(
            name: "Test Program",
            progressionEnabled: progressionEnabled,
            defaultProgressionRule: rule
        )
    }

    // MARK: - Basic Progression Tests

    func testWeightProgression_appliesPercentage() {
        // Given: Last session had 100 lbs, using 5% progression
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Bench Press", weights: [100, 100, 100])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])
        let program = makeProgram(rule: .moderate) // 5% increase

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: 100 + 5% = 105
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 105.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 100.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.metric, .weight)
    }

    func testWeightProgression_roundsToIncrement() {
        // Given: Last session had 103 lbs, using 5% progression with 5 lb rounding
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Bench Press", weights: [103])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])
        let program = makeProgram(rule: .moderate) // 5% increase, 5 lb rounding

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: 103 + 5% = 108.15, rounds to 110
        // But minimum increase of 5 lbs means at least 108, so rounds to 110
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 110.0)
    }

    func testWeightProgression_respectsMinimumIncrease() {
        // Given: Small weight (20 lbs), 2.5% would be only 0.5 lbs
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Lateral Raise", weights: [20])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Lateral Raise", weights: [])

        // Using conservative: 2.5% increase, 5 lb rounding, 5 lb minimum
        let program = makeProgram(rule: .conservative)

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: 2.5% of 20 = 0.5, but minimum is 5 lbs, so 20 + 5 = 25
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 25.0)
    }

    func testWeightProgression_usesMaxWeightFromSets() {
        // Given: Sets with varying weights - should use max (135)
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Squat", weights: [125, 135, 135, 130])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Squat", weights: [])
        let program = makeProgram(rule: .moderate) // 5% increase

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: Max is 135, 135 + 5% = 141.75, rounds to 140 (or 145 due to minimum)
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 135.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 145.0) // 135 + 5 min = 140, round to 145
    }

    // MARK: - No History Tests

    func testNoHistory_returnsNil() {
        // Given: No prior sessions for this workout
        let workoutId = UUID()
        let currentExercise = makeExercise(name: "Deadlift", weights: [])
        let program = makeProgram()

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: [] // No history
        )

        // Then: No suggestion for first-time exercise
        XCTAssertNil(suggestions[currentExercise.id])
    }

    func testDifferentWorkout_returnsNil() {
        // Given: History exists but for a different workout
        let workoutId1 = UUID()
        let workoutId2 = UUID()

        let lastExercise = makeExercise(name: "Bench Press", weights: [100])
        let history = [makeSession(workoutId: workoutId1, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])
        let program = makeProgram()

        // When: Querying for different workout
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId2, // Different workout!
            program: program,
            sessionHistory: history
        )

        // Then: No suggestion because history is from different workout
        XCTAssertNil(suggestions[currentExercise.id])
    }

    // MARK: - Non-Strength Exercise Tests

    func testNonStrengthExercise_skipped() {
        // Given: Cardio exercise
        let workoutId = UUID()

        let cardioExercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: "Running",
            exerciseType: .cardio,
            completedSetGroups: []
        )

        // Even with history
        let lastCardio = SessionExercise(
            exerciseId: UUID(),
            exerciseName: "Running",
            exerciseType: .cardio,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: [SetData(setNumber: 1, completed: true, duration: 1800)]
                )
            ]
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastCardio])]

        let program = makeProgram()

        // When
        let suggestions = service.calculateSuggestions(
            for: [cardioExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: No suggestion for non-strength
        XCTAssertNil(suggestions[cardioExercise.id])
    }

    // MARK: - Progression Disabled Tests

    func testProgressionDisabled_returnsEmpty() {
        // Given: Program with progression disabled
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Bench Press", weights: [100])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])
        let program = makeProgram(progressionEnabled: false) // Disabled!

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: No suggestions when disabled
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testNoProgram_returnsEmpty() {
        // Given: No program (ad-hoc workout)
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Bench Press", weights: [100])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])

        // When: No program provided
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: nil, // No program
            sessionHistory: history
        )

        // Then: No suggestions without program
        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Edge Cases

    func testIncompleteSets_ignored() {
        // Given: Last session had incomplete sets
        let workoutId = UUID()

        let incompleteSets = [
            SetData(setNumber: 1, completed: false, weight: 200, reps: 5), // Not completed
            SetData(setNumber: 2, completed: true, weight: 100, reps: 5)   // Completed
        ]

        let lastExercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: "Bench Press",
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(setGroupId: UUID(), sets: incompleteSets)
            ]
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Bench Press", weights: [])
        let program = makeProgram(rule: .moderate)

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: Should use only completed set (100 lbs), not the incomplete 200
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 100.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 105.0) // 100 + 5%
    }

    func testFineGrainedProgression() {
        // Given: Using fine-grained rule (2.5 lb increments)
        let workoutId = UUID()
        let lastExercise = makeExercise(name: "Curl", weights: [25])
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        let currentExercise = makeExercise(name: "Curl", weights: [])
        let program = makeProgram(rule: .fineGrained) // 2.5% increase, 2.5 lb rounding, 2.5 lb min

        // When
        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        // Then: 25 + 2.5 (minimum) = 27.5
        XCTAssertNotNil(suggestions[currentExercise.id])
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 27.5)
    }

    // MARK: - Adaptive Mode Tests

    func testAdaptiveMode_onlyEnabledExercisesGetSuggestions() {
        let workoutId = UUID()
        let enabledInstanceId = UUID()
        let disabledInstanceId = UUID()

        let lastEnabled = makeExercise(
            name: "Bench Press",
            weights: [100],
            sourceExerciseInstanceId: enabledInstanceId
        )
        let lastDisabled = makeExercise(
            name: "Incline DB Press",
            weights: [80],
            sourceExerciseInstanceId: disabledInstanceId
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastEnabled, lastDisabled])]

        let currentEnabled = makeExercise(name: "Bench Press", weights: [])
        let currentDisabled = makeExercise(name: "Incline DB Press", weights: [])

        let program = Program(
            name: "Adaptive Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            progressionEnabledExercises: Set([enabledInstanceId]),
            exerciseProgressionOverrides: [enabledInstanceId: .moderate]
        )

        let suggestions = service.calculateSuggestions(
            for: [currentEnabled, currentDisabled],
            exerciseInstanceIds: [
                currentEnabled.id: enabledInstanceId,
                currentDisabled.id: disabledInstanceId
            ],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        XCTAssertNotNil(suggestions[currentEnabled.id])
        XCTAssertNil(suggestions[currentDisabled.id])
    }

    func testAdaptiveMode_appliesPreviousOutcomeRecommendation() {
        let workoutId = UUID()
        let instanceId = UUID()
        let lastExercise = makeExercise(
            name: "Squat",
            weights: [200],
            recommendation: .stay,
            sourceExerciseInstanceId: instanceId
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]
        let currentExercise = makeExercise(name: "Squat", weights: [])

        let program = Program(
            name: "Adaptive Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            defaultProgressionRule: .moderate,
            progressionEnabledExercises: Set([instanceId])
        )

        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            exerciseInstanceIds: [currentExercise.id: instanceId],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 200.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 200.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.appliedOutcome, .stay)
        XCTAssertEqual(suggestions[currentExercise.id]?.isOutcomeAdjusted, true)
    }

    func testAdaptiveMode_doubleProgressionStaysUntilRepGoal() {
        let workoutId = UUID()
        let instanceId = UUID()
        let lastExercise = makeExercise(
            name: "Bench Press",
            weights: [135, 135, 135],
            reps: 6,
            sourceExerciseInstanceId: instanceId
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]

        // Current session starts with an 8-rep target.
        let currentExercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: "Bench Press",
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: [SetData(setNumber: 1, completed: false, weight: 135, reps: 8)]
                )
            ]
        )

        let rule = ProgressionRule(
            targetMetric: .weight,
            strategy: .doubleProgression,
            percentageIncrease: 5.0,
            roundingIncrement: 5.0,
            minimumIncrease: 5.0
        )

        let program = Program(
            name: "Adaptive Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            defaultProgressionRule: rule,
            progressionEnabledExercises: Set([instanceId])
        )

        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            exerciseInstanceIds: [currentExercise.id: instanceId],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 135.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 135.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.appliedOutcome, .stay)
    }

    func testAdaptiveMode_stateFailStreakRegresses() {
        let workoutId = UUID()
        let instanceId = UUID()

        let lastExercise = makeExercise(
            name: "Squat",
            weights: [200],
            sourceExerciseInstanceId: instanceId
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]
        let currentExercise = makeExercise(name: "Squat", weights: [])

        let state = ExerciseProgressionState(
            successStreak: 0,
            failStreak: 2,
            confidence: 0.4
        )

        let program = Program(
            name: "Adaptive Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            defaultProgressionRule: .moderate,
            progressionEnabledExercises: Set([instanceId]),
            exerciseProgressionStates: [instanceId: state]
        )

        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            exerciseInstanceIds: [currentExercise.id: instanceId],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        XCTAssertEqual(suggestions[currentExercise.id]?.baseValue, 200.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 190.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.appliedOutcome, .regress)
        XCTAssertEqual(suggestions[currentExercise.id]?.isOutcomeAdjusted, true)
    }

    func testAdaptiveMode_stateSuccessStreakForcesProgressOutcome() {
        let workoutId = UUID()
        let instanceId = UUID()

        let lastExercise = makeExercise(
            name: "Bench Press",
            weights: [100],
            sourceExerciseInstanceId: instanceId
        )
        let history = [makeSession(workoutId: workoutId, exercises: [lastExercise])]
        let currentExercise = makeExercise(name: "Bench Press", weights: [])

        let state = ExerciseProgressionState(
            successStreak: 2,
            failStreak: 0,
            confidence: 0.7
        )

        let program = Program(
            name: "Adaptive Program",
            progressionEnabled: true,
            progressionPolicy: .adaptive,
            defaultProgressionRule: .moderate,
            progressionEnabledExercises: Set([instanceId]),
            exerciseProgressionStates: [instanceId: state]
        )

        let suggestions = service.calculateSuggestions(
            for: [currentExercise],
            exerciseInstanceIds: [currentExercise.id: instanceId],
            workoutId: workoutId,
            program: program,
            sessionHistory: history
        )

        XCTAssertEqual(suggestions[currentExercise.id]?.suggestedValue, 105.0)
        XCTAssertEqual(suggestions[currentExercise.id]?.appliedOutcome, .progress)
        XCTAssertEqual(suggestions[currentExercise.id]?.isOutcomeAdjusted, true)
    }

    func testInferProgressionOutcome_usesCompletedPerformance() {
        let exercise = makeExercise(name: "Bench Press", weights: [105], reps: 5)
        let suggestion = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5
        )

        let outcome = service.inferProgressionOutcome(for: exercise, suggestion: suggestion)
        XCTAssertEqual(outcome, .progress)
    }

    func testUpdateProgressionState_tracksStreaksConfidenceAndHistory() {
        let exercise = makeExercise(name: "Bench Press", weights: [100], reps: 5)
        let initial = ExerciseProgressionState(confidence: 0.5)

        let updated = service.updateProgressionState(
            current: initial,
            exercise: exercise,
            outcome: .progress,
            at: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(updated.successStreak, 1)
        XCTAssertEqual(updated.failStreak, 0)
        XCTAssertEqual(updated.recentOutcomes.first, .progress)
        XCTAssertEqual(updated.lastPrescribedWeight, 100)
        XCTAssertEqual(updated.lastPrescribedReps, 5)
        XCTAssertNotNil(updated.lastUpdatedAt)
        XCTAssertTrue(updated.confidence > 0.5)
    }
}
