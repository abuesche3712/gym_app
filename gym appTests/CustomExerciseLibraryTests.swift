import XCTest
@testable import gym_app

@MainActor
final class CustomExerciseLibraryTests: XCTestCase {
    private let customLibrary = CustomExerciseLibrary.shared
    private let testPrefix = "Codex CustomLib Test "

    override func tearDown() {
        super.tearDown()
        cleanupExercises()
    }

    func testAddExerciseTemplatePreservesExtendedFields() {
        let templateId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let implementId = UUID()
        let measurable = ImplementMeasurableTarget(
            id: UUID(),
            implementId: implementId,
            measurableName: "Height",
            unit: "in",
            isStringBased: false,
            targetValue: 24
        )
        let setGroup = SetGroup(
            id: UUID(),
            sets: 3,
            targetReps: 8,
            targetWeight: 95,
            targetDuration: 120,
            targetDistance: 1.25,
            targetHoldTime: 30,
            restPeriod: 90,
            isUnilateral: true,
            trackRPE: false,
            implementMeasurables: [measurable]
        )

        let template = ExerciseTemplate(
            id: templateId,
            name: "\(testPrefix)RoundTrip \(UUID().uuidString)",
            category: .legs,
            exerciseType: .cardio,
            cardioMetric: .both,
            mobilityTracking: .durationOnly,
            distanceUnit: .kilometers,
            primary: [.quads, .glutes],
            secondary: [.calves],
            isBodyweight: true,
            isUnilateral: true,
            recoveryActivityType: .coldPlunge,
            implementIds: [implementId],
            defaultSetGroups: [setGroup],
            defaultNotes: "Track split pace",
            isArchived: true,
            isCustom: true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        XCTAssertTrue(customLibrary.addExercise(template))

        guard let saved = customLibrary.exercises.first(where: { $0.id == templateId }) else {
            XCTFail("Failed to find saved custom exercise")
            return
        }

        XCTAssertEqual(saved.name, template.name)
        XCTAssertEqual(saved.category, template.category)
        XCTAssertEqual(saved.exerciseType, template.exerciseType)
        XCTAssertEqual(saved.cardioMetric, template.cardioMetric)
        XCTAssertEqual(saved.mobilityTracking, template.mobilityTracking)
        XCTAssertEqual(saved.distanceUnit, template.distanceUnit)
        XCTAssertEqual(saved.primaryMuscles, template.primaryMuscles)
        XCTAssertEqual(saved.secondaryMuscles, template.secondaryMuscles)
        XCTAssertEqual(saved.isBodyweight, template.isBodyweight)
        XCTAssertEqual(saved.isUnilateral, template.isUnilateral)
        XCTAssertEqual(saved.recoveryActivityType, template.recoveryActivityType)
        XCTAssertEqual(saved.implementIds, template.implementIds)
        XCTAssertEqual(saved.defaultSetGroups, template.defaultSetGroups)
        XCTAssertEqual(saved.defaultNotes, template.defaultNotes)
        XCTAssertEqual(saved.isArchived, template.isArchived)
        XCTAssertEqual(saved.isCustom, template.isCustom)
        XCTAssertEqual(saved.createdAt, createdAt)
        XCTAssertEqual(saved.updatedAt, updatedAt)
    }

    func testUpdateExercisePersistsExtendedFields() {
        let exerciseName = "\(testPrefix)Update \(UUID().uuidString)"
        XCTAssertTrue(customLibrary.addExercise(name: exerciseName, exerciseType: .strength))

        guard let created = customLibrary.exercises.first(where: { $0.name == exerciseName }) else {
            XCTFail("Failed to create custom exercise")
            return
        }

        let implementId = UUID()
        var updated = created
        updated.category = .back
        updated.exerciseType = .mobility
        updated.cardioMetric = .distanceOnly
        updated.mobilityTracking = .both
        updated.distanceUnit = .yards
        updated.primaryMuscles = [.back]
        updated.secondaryMuscles = [.biceps]
        updated.isBodyweight = true
        updated.isUnilateral = true
        updated.recoveryActivityType = .sauna
        updated.implementIds = [implementId]
        updated.defaultSetGroups = [
            SetGroup(
                sets: 2,
                targetReps: 12,
                targetDuration: 45,
                restPeriod: 30,
                implementMeasurables: [
                    ImplementMeasurableTarget(
                        implementId: implementId,
                        measurableName: "Incline",
                        unit: "%",
                        isStringBased: false,
                        targetValue: 10
                    )
                ]
            )
        ]
        updated.defaultNotes = "Tempo focus"
        updated.isArchived = true
        updated.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)

        customLibrary.updateExercise(updated)

        guard let saved = customLibrary.exercises.first(where: { $0.id == created.id }) else {
            XCTFail("Failed to find updated custom exercise")
            return
        }

        XCTAssertEqual(saved.category, updated.category)
        XCTAssertEqual(saved.exerciseType, updated.exerciseType)
        XCTAssertEqual(saved.cardioMetric, updated.cardioMetric)
        XCTAssertEqual(saved.mobilityTracking, updated.mobilityTracking)
        XCTAssertEqual(saved.distanceUnit, updated.distanceUnit)
        XCTAssertEqual(saved.primaryMuscles, updated.primaryMuscles)
        XCTAssertEqual(saved.secondaryMuscles, updated.secondaryMuscles)
        XCTAssertEqual(saved.isBodyweight, updated.isBodyweight)
        XCTAssertEqual(saved.isUnilateral, updated.isUnilateral)
        XCTAssertEqual(saved.recoveryActivityType, updated.recoveryActivityType)
        XCTAssertEqual(saved.implementIds, updated.implementIds)
        XCTAssertEqual(saved.defaultSetGroups, updated.defaultSetGroups)
        XCTAssertEqual(saved.defaultNotes, updated.defaultNotes)
        XCTAssertEqual(saved.isArchived, updated.isArchived)
        XCTAssertEqual(saved.createdAt, created.createdAt)
        XCTAssertEqual(saved.updatedAt, updated.updatedAt)
    }

    private func cleanupExercises() {
        let staleExercises = customLibrary.exercises.filter { template in
            template.name.hasPrefix(testPrefix)
        }
        for exercise in staleExercises {
            customLibrary.deleteExercise(exercise)
        }
    }
}
