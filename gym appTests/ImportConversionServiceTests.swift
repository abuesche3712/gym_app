//
//  ImportConversionServiceTests.swift
//  gym appTests
//
//  Verifies session-to-workout conversion matching behavior.
//

import XCTest
@testable import gym_app

@MainActor
final class ImportConversionServiceTests: XCTestCase {
    private let service = ImportConversionService.shared
    private let customLibrary = CustomExerciseLibrary.shared

    override func tearDown() {
        super.tearDown()
        cleanupExercises(withPrefix: "Codex Conversion Test ")
    }

    func testConvertSessionToWorkoutReusesExactTemplateMatch() {
        let suffix = UUID().uuidString
        let exerciseName = "Codex Conversion Test Bench \(suffix)"
        customLibrary.addExercise(name: exerciseName, exerciseType: .strength)

        let session = makeSession(
            workoutName: "Codex Conversion Test Workout \(suffix)",
            exerciseName: exerciseName
        )

        let result = service.convertSessionToWorkout(session)

        XCTAssertEqual(result.workout.standaloneExercises.count, 1)
        XCTAssertTrue(result.createdExercises.isEmpty)
        XCTAssertEqual(result.matchedExercises, [exerciseName])
    }

    func testConvertSessionToWorkoutCreatesCustomExerciseForNonExactName() {
        let suffix = UUID().uuidString
        let existingExerciseName = "Codex Conversion Test Row \(suffix)"
        let importedExerciseName = "Codex Conversion Test Row \(suffix) (Machine)"
        customLibrary.addExercise(name: existingExerciseName, exerciseType: .strength)

        let session = makeSession(
            workoutName: "Codex Conversion Test Imported \(suffix)",
            exerciseName: importedExerciseName
        )

        let result = service.convertSessionToWorkout(session)

        XCTAssertEqual(result.workout.standaloneExercises.count, 1)
        XCTAssertTrue(result.matchedExercises.isEmpty)
        XCTAssertEqual(result.createdExercises, [importedExerciseName])
        XCTAssertTrue(customLibrary.contains(name: importedExerciseName))
    }

    private func makeSession(workoutName: String, exerciseName: String) -> Session {
        let set = SetData(setNumber: 1, weight: 135, reps: 8, completed: true)
        let setGroup = CompletedSetGroup(setGroupId: UUID(), sets: [set])
        let exercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: exerciseName,
            exerciseType: .strength,
            completedSetGroups: [setGroup]
        )
        let module = CompletedModule(
            moduleId: UUID(),
            moduleName: "Imported",
            moduleType: .strength,
            completedExercises: [exercise]
        )
        return Session(
            workoutId: UUID(),
            workoutName: workoutName,
            completedModules: [module],
            isImported: true
        )
    }

    private func cleanupExercises(withPrefix prefix: String) {
        let staleExercises = customLibrary.exercises.filter { template in
            template.name.hasPrefix(prefix)
        }
        for exercise in staleExercises {
            customLibrary.deleteExercise(exercise)
        }
    }
}
