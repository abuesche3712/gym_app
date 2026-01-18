//
//  SessionNavigatorTests.swift
//  gym appTests
//
//  Unit tests for SessionNavigator
//  Tests navigation logic in isolation without ViewModel dependencies
//

import XCTest
@testable import gym_app

final class SessionNavigatorTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a simple set group with specified number of sets
    private func makeSetGroup(sets: Int, restPeriod: Int? = 60) -> CompletedSetGroup {
        CompletedSetGroup(
            setGroupId: UUID(),
            restPeriod: restPeriod,
            sets: (1...sets).map { SetData(setNumber: $0, completed: false) }
        )
    }

    /// Creates a simple exercise with one set group
    private func makeExercise(
        name: String,
        sets: Int = 3,
        setGroups: Int = 1,
        supersetGroupId: UUID? = nil
    ) -> SessionExercise {
        SessionExercise(
            exerciseId: UUID(),
            exerciseName: name,
            exerciseType: .strength,
            supersetGroupId: supersetGroupId,
            completedSetGroups: (0..<setGroups).map { _ in makeSetGroup(sets: sets) }
        )
    }

    /// Creates a module with specified exercises
    private func makeModule(name: String, exercises: [SessionExercise]) -> CompletedModule {
        CompletedModule(
            moduleId: UUID(),
            moduleName: name,
            moduleType: .strength,
            completedExercises: exercises
        )
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 3)
            ])
        ]

        let navigator = SessionNavigator(modules: modules)

        XCTAssertEqual(navigator.currentModuleIndex, 0)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentSetGroupIndex, 0)
        XCTAssertEqual(navigator.currentSetIndex, 0)
    }

    func testInitialStateWithCustomPosition() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 3)
            ])
        ]

        let navigator = SessionNavigator(
            modules: modules,
            moduleIndex: 0,
            exerciseIndex: 0,
            setGroupIndex: 0,
            setIndex: 2
        )

        XCTAssertEqual(navigator.currentSetIndex, 2)
    }

    func testEmptyModulesHandling() {
        let navigator = SessionNavigator(modules: [])

        XCTAssertNil(navigator.currentModule)
        XCTAssertNil(navigator.currentExercise)
        XCTAssertNil(navigator.currentSetGroup)
        XCTAssertNil(navigator.currentSet)
        XCTAssertTrue(navigator.isWorkoutComplete)
    }

    // MARK: - Linear Progression Tests

    func testAdvanceThroughSetsInSetGroup() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 3)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Start at set 0
        XCTAssertEqual(navigator.currentSetIndex, 0)

        // Advance to set 1
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.currentSetIndex, 1)
        XCTAssertEqual(navigator.currentSetGroupIndex, 0)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)

        // Advance to set 2
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.currentSetIndex, 2)
    }

    func testAdvanceThroughSetGroups() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 2, setGroups: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Complete first set group (2 sets)
        navigator.advanceToNextSet() // Set 0 -> 1
        navigator.advanceToNextSet() // Set 1 -> SetGroup 1, Set 0

        XCTAssertEqual(navigator.currentSetGroupIndex, 1)
        XCTAssertEqual(navigator.currentSetIndex, 0)
    }

    func testAdvanceThroughExercises() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 2),
                makeExercise(name: "Rows", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Complete first exercise (2 sets)
        navigator.advanceToNextSet() // Set 0 -> 1
        navigator.advanceToNextSet() // Set 1 -> Exercise 1, Set 0

        XCTAssertEqual(navigator.currentExerciseIndex, 1)
        XCTAssertEqual(navigator.currentSetIndex, 0)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Rows")
    }

    func testAdvanceThroughModules() {
        let modules = [
            makeModule(name: "Warmup", exercises: [
                makeExercise(name: "Jumping Jacks", sets: 1)
            ]),
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Squats", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Complete first module (1 set)
        navigator.advanceToNextSet() // Module 0 -> Module 1

        XCTAssertEqual(navigator.currentModuleIndex, 1)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentSetIndex, 0)
        XCTAssertEqual(navigator.currentModule?.moduleName, "Strength")
    }

    // MARK: - Last Set Detection

    func testIsLastSetAtEnd() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        XCTAssertFalse(navigator.isLastSet)

        navigator.advanceToNextSet() // Now at last set

        XCTAssertTrue(navigator.isLastSet)
    }

    func testIsLastSetMultipleModules() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 1)
            ]),
            makeModule(name: "Module 2", exercises: [
                makeExercise(name: "Exercise 2", sets: 1)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        XCTAssertFalse(navigator.isLastSet)

        navigator.advanceToNextSet() // Move to module 2

        XCTAssertTrue(navigator.isLastSet)
    }

    func testEndOfWorkoutStaysAtLastPosition() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Advance to last set
        navigator.advanceToNextSet()
        XCTAssertTrue(navigator.isLastSet)

        // Try to advance past end
        navigator.advanceToNextSet()

        // Should stay at last position
        XCTAssertEqual(navigator.currentModuleIndex, 0)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentSetIndex, 1)
    }

    // MARK: - Superset Tests

    func testSupersetCycling() {
        let supersetId = UUID()
        let modules = [
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Bench Press", sets: 3, supersetGroupId: supersetId),
                makeExercise(name: "Rows", sets: 3, supersetGroupId: supersetId)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Should start at Bench Press (exercise 0)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Bench Press")
        XCTAssertTrue(navigator.isInSuperset)
        XCTAssertEqual(navigator.supersetPosition, 1)
        XCTAssertEqual(navigator.supersetTotal, 2)

        // After first set of Bench, should go to Rows
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.currentExerciseIndex, 1)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Rows")
        XCTAssertEqual(navigator.currentSetIndex, 0) // Same set number
        XCTAssertEqual(navigator.supersetPosition, 2)

        // After first set of Rows, should go back to Bench (set 1)
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Bench Press")
        XCTAssertEqual(navigator.currentSetIndex, 1) // Now on set 2
        XCTAssertEqual(navigator.supersetPosition, 1)
    }

    func testSupersetShouldRestAfterSuperset() {
        let supersetId = UUID()
        let modules = [
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Bench Press", sets: 2, supersetGroupId: supersetId),
                makeExercise(name: "Rows", sets: 2, supersetGroupId: supersetId)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // At first exercise - should not rest yet
        XCTAssertFalse(navigator.shouldRestAfterSuperset)

        // After advancing to second exercise (Rows) - should rest
        navigator.advanceToNextSet()
        XCTAssertTrue(navigator.shouldRestAfterSuperset)

        // After going back to Bench (set 2) - should not rest
        navigator.advanceToNextSet()
        XCTAssertFalse(navigator.shouldRestAfterSuperset)

        // At Rows again (set 2) - should rest
        navigator.advanceToNextSet()
        XCTAssertTrue(navigator.shouldRestAfterSuperset)
    }

    func testSupersetFollowedByNormalExercise() {
        let supersetId = UUID()
        let modules = [
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Bench Press", sets: 1, supersetGroupId: supersetId),
                makeExercise(name: "Rows", sets: 1, supersetGroupId: supersetId),
                makeExercise(name: "Curls", sets: 2) // Not in superset
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Complete superset
        navigator.advanceToNextSet() // Bench -> Rows
        navigator.advanceToNextSet() // Rows -> Should move to Curls

        XCTAssertEqual(navigator.currentExerciseIndex, 2)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Curls")
        XCTAssertFalse(navigator.isInSuperset)
        XCTAssertNil(navigator.supersetPosition)
    }

    func testNonSupersetExerciseHasNoSupersetProperties() {
        let modules = [
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Squats", sets: 3)
            ])
        ]

        let navigator = SessionNavigator(modules: modules)

        XCTAssertFalse(navigator.isInSuperset)
        XCTAssertNil(navigator.currentSupersetExercises)
        XCTAssertNil(navigator.supersetPosition)
        XCTAssertNil(navigator.supersetTotal)
        XCTAssertFalse(navigator.shouldRestAfterSuperset)
    }

    // MARK: - Skip Exercise Tests

    func testSkipExercise() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Bench Press", sets: 3),
                makeExercise(name: "Rows", sets: 3),
                makeExercise(name: "Curls", sets: 3)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Skip first exercise
        navigator.skipExercise()

        XCTAssertEqual(navigator.currentExerciseIndex, 1)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Rows")
        XCTAssertEqual(navigator.currentSetIndex, 0)
    }

    func testSkipExerciseToNextModule() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 2)
            ]),
            makeModule(name: "Module 2", exercises: [
                makeExercise(name: "Exercise 2", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Skip last exercise in module
        navigator.skipExercise()

        XCTAssertEqual(navigator.currentModuleIndex, 1)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentModule?.moduleName, "Module 2")
    }

    func testSkipExerciseAtEndOfWorkout() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Try to skip when at last exercise
        navigator.skipExercise()

        // Should stay at same position (can't skip past end)
        XCTAssertEqual(navigator.currentModuleIndex, 0)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
    }

    // MARK: - Skip Module Tests

    func testSkipModule() {
        let moduleId1 = UUID()
        let moduleId2 = UUID()
        let modules = [
            CompletedModule(
                id: UUID(),
                moduleId: moduleId1,
                moduleName: "Module 1",
                moduleType: .warmup,
                completedExercises: [makeExercise(name: "Exercise 1", sets: 2)]
            ),
            CompletedModule(
                id: UUID(),
                moduleId: moduleId2,
                moduleName: "Module 2",
                moduleType: .strength,
                completedExercises: [makeExercise(name: "Exercise 2", sets: 2)]
            )
        ]

        var navigator = SessionNavigator(modules: modules)

        // Skip first module
        let skippedId = navigator.skipModule()

        XCTAssertEqual(skippedId, moduleId1)
        XCTAssertEqual(navigator.currentModuleIndex, 1)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentSetIndex, 0)
    }

    func testSkipLastModuleStaysAtPosition() {
        let moduleId = UUID()
        let modules = [
            CompletedModule(
                id: UUID(),
                moduleId: moduleId,
                moduleName: "Only Module",
                moduleType: .strength,
                completedExercises: [makeExercise(name: "Exercise 1", sets: 2)]
            )
        ]

        var navigator = SessionNavigator(modules: modules)

        // Try to skip when at last module
        let skippedId = navigator.skipModule()

        // Should return the module ID but stay at same position
        XCTAssertEqual(skippedId, moduleId)
        XCTAssertEqual(navigator.currentModuleIndex, 0)
    }

    // MARK: - Progress Calculation Tests

    func testProgressCalculation() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 2),
                makeExercise(name: "Exercise 2", sets: 2)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Total: 4 sets, at set 0
        XCTAssertEqual(navigator.overallProgress, 0.0, accuracy: 0.01)

        // Complete 1 set
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.overallProgress, 0.25, accuracy: 0.01)

        // Complete 2 sets
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.overallProgress, 0.5, accuracy: 0.01)

        // Complete 3 sets
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.overallProgress, 0.75, accuracy: 0.01)
    }

    func testProgressWithMultipleModules() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 1)
            ]),
            makeModule(name: "Module 2", exercises: [
                makeExercise(name: "Exercise 2", sets: 1)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Total: 2 sets
        XCTAssertEqual(navigator.overallProgress, 0.0, accuracy: 0.01)

        // Complete first module
        navigator.advanceToNextSet()
        XCTAssertEqual(navigator.overallProgress, 0.5, accuracy: 0.01)
    }

    // MARK: - Reset Tests

    func testReset() {
        let modules = [
            makeModule(name: "Module 1", exercises: [
                makeExercise(name: "Exercise 1", sets: 3)
            ])
        ]

        var navigator = SessionNavigator(modules: modules)

        // Advance to middle of workout
        navigator.advanceToNextSet()
        navigator.advanceToNextSet()

        XCTAssertEqual(navigator.currentSetIndex, 2)

        // Reset
        navigator.reset()

        XCTAssertEqual(navigator.currentModuleIndex, 0)
        XCTAssertEqual(navigator.currentExerciseIndex, 0)
        XCTAssertEqual(navigator.currentSetGroupIndex, 0)
        XCTAssertEqual(navigator.currentSetIndex, 0)
    }

    // MARK: - Current Accessors Tests

    func testCurrentAccessors() {
        let modules = [
            makeModule(name: "Strength", exercises: [
                makeExercise(name: "Bench Press", sets: 3)
            ])
        ]

        let navigator = SessionNavigator(modules: modules)

        XCTAssertNotNil(navigator.currentModule)
        XCTAssertEqual(navigator.currentModule?.moduleName, "Strength")

        XCTAssertNotNil(navigator.currentExercise)
        XCTAssertEqual(navigator.currentExercise?.exerciseName, "Bench Press")

        XCTAssertNotNil(navigator.currentSetGroup)
        XCTAssertNotNil(navigator.currentSet)
        XCTAssertEqual(navigator.currentSet?.setNumber, 1)
    }

    // MARK: - Edge Cases

    func testModuleWithNoExercises() {
        let modules = [
            CompletedModule(
                moduleId: UUID(),
                moduleName: "Empty Module",
                moduleType: .warmup,
                completedExercises: []
            )
        ]

        let navigator = SessionNavigator(modules: modules)

        XCTAssertNil(navigator.currentExercise)
        XCTAssertNil(navigator.currentSetGroup)
        XCTAssertNil(navigator.currentSet)
    }

    func testExerciseWithNoSetGroups() {
        let modules = [
            CompletedModule(
                moduleId: UUID(),
                moduleName: "Module",
                moduleType: .strength,
                completedExercises: [
                    SessionExercise(
                        exerciseId: UUID(),
                        exerciseName: "Empty Exercise",
                        exerciseType: .strength,
                        completedSetGroups: []
                    )
                ]
            )
        ]

        let navigator = SessionNavigator(modules: modules)

        XCTAssertNotNil(navigator.currentExercise)
        XCTAssertNil(navigator.currentSetGroup)
        XCTAssertNil(navigator.currentSet)
    }
}
