//
//  ExerciseInstanceTests.swift
//  gym appTests
//
//  Unit tests for ExerciseInstance validation
//

import XCTest
@testable import gym_app

final class ExerciseInstanceTests: XCTestCase {

    // MARK: - isValid Tests

    func testValidInstance() {
        let instance = ExerciseInstance(name: "Bench Press", order: 0)
        XCTAssertTrue(instance.isValid)
    }

    func testEmptyNameIsInvalid() {
        let instance = ExerciseInstance(name: "", order: 0)
        XCTAssertFalse(instance.isValid)
    }

    func testWhitespaceNameIsInvalid() {
        let instance = ExerciseInstance(name: "   ", order: 0)
        XCTAssertFalse(instance.isValid)
    }

    func testNewlineNameIsInvalid() {
        let instance = ExerciseInstance(name: "\n\t", order: 0)
        XCTAssertFalse(instance.isValid)
    }

    func testNegativeOrderIsInvalid() {
        let instance = ExerciseInstance(name: "Squat", order: -1)
        XCTAssertFalse(instance.isValid)
    }

    func testValidInstanceWithAllFields() {
        let instance = ExerciseInstance(
            name: "Deadlift",
            exerciseType: .strength,
            primaryMuscles: [.hamstrings, .glutes],
            secondaryMuscles: [.back],
            setGroups: [SetGroup(sets: 3, targetReps: 5, targetWeight: 100)],
            order: 2
        )
        XCTAssertTrue(instance.isValid)
    }

    // MARK: - validate() Tests

    func testValidateThrowsForEmptyName() {
        let instance = ExerciseInstance(name: "", order: 0)
        XCTAssertThrowsError(try instance.validate()) { error in
            XCTAssertEqual(error as? ExerciseInstance.ValidationError, .emptyName)
        }
    }

    func testValidateThrowsForNegativeOrder() {
        let instance = ExerciseInstance(name: "Curl", order: -5)
        XCTAssertThrowsError(try instance.validate()) { error in
            XCTAssertEqual(error as? ExerciseInstance.ValidationError, .negativeOrder)
        }
    }

    func testValidateDoesNotThrowForValidInstance() {
        let instance = ExerciseInstance(name: "Press", order: 0)
        XCTAssertNoThrow(try instance.validate())
    }

    // MARK: - Factory Method Tests

    func testFromTemplateCreatesValidInstance() {
        let template = ExerciseTemplate(
            id: UUID(),
            name: "Squat",
            category: .legs,
            exerciseType: .strength,
            primary: [.quads],
            secondary: [.glutes]
        )
        let instance = ExerciseInstance.from(template: template, order: 0)
        XCTAssertEqual(instance.name, "Squat")
        XCTAssertTrue(instance.isValid)
        XCTAssertEqual(instance.templateId, template.id)
    }

    func testFromTemplateWithNegativeOrderClampsToZero() {
        let template = ExerciseTemplate(
            id: UUID(),
            name: "Deadlift",
            category: .back,
            exerciseType: .strength,
            primary: [.hamstrings]
        )
        let instance = ExerciseInstance.from(template: template, order: -5)
        XCTAssertEqual(instance.order, 0)
        XCTAssertTrue(instance.isValid)
    }

    func testFromTemplatePreservesExerciseType() {
        let template = ExerciseTemplate(
            id: UUID(),
            name: "Running",
            category: .fullBody,
            exerciseType: .cardio,
            primary: []
        )
        let instance = ExerciseInstance.from(template: template, order: 0)
        XCTAssertEqual(instance.exerciseType, .cardio)
    }

    func testFromTemplatePreservesMuscleGroups() {
        let primary: [MuscleGroup] = [.chest, .triceps]
        let secondary: [MuscleGroup] = [.shoulders]
        let template = ExerciseTemplate(
            id: UUID(),
            name: "Bench Press",
            category: .chest,
            exerciseType: .strength,
            primary: primary,
            secondary: secondary
        )
        let instance = ExerciseInstance.from(template: template, order: 0)
        XCTAssertEqual(instance.primaryMuscles, primary)
        XCTAssertEqual(instance.secondaryMuscles, secondary)
    }

    // MARK: - Error Description Tests

    func testValidationErrorDescriptions() {
        XCTAssertEqual(ExerciseInstance.ValidationError.emptyName.errorDescription, "Exercise name cannot be empty")
        XCTAssertEqual(ExerciseInstance.ValidationError.invalidSetGroups.errorDescription, "Exercise must have at least one set group")
        XCTAssertEqual(ExerciseInstance.ValidationError.negativeOrder.errorDescription, "Order cannot be negative")
    }
}
