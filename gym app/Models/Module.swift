//
//  Module.swift
//  gym app
//
//  A reusable component of a workout
//

import Foundation

struct Module: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var type: ModuleType
    var exercises: [Exercise]
    var notes: String?
    var estimatedDuration: Int? // minutes
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        name: String,
        type: ModuleType,
        exercises: [Exercise] = [],
        notes: String? = nil,
        estimatedDuration: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.exercises = exercises
        self.notes = notes
        self.estimatedDuration = estimatedDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
        updatedAt = Date()
    }

    mutating func removeExercise(at index: Int) {
        exercises.remove(at: index)
        updatedAt = Date()
    }

    mutating func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            updatedAt = Date()
        }
    }

    /// Groups exercises by superset, maintaining original order
    /// Non-superset exercises are single-item arrays
    var groupedExercises: [[Exercise]] {
        var groups: [[Exercise]] = []
        var processedIds: Set<UUID> = []

        for exercise in exercises {
            guard !processedIds.contains(exercise.id) else { continue }

            if let supersetId = exercise.supersetGroupId {
                // Find all exercises in this superset
                let supersetExercises = exercises.filter { $0.supersetGroupId == supersetId }
                groups.append(supersetExercises)
                supersetExercises.forEach { processedIds.insert($0.id) }
            } else {
                // Single exercise (not in a superset)
                groups.append([exercise])
                processedIds.insert(exercise.id)
            }
        }

        return groups
    }

    /// Link exercises together as a superset
    mutating func createSuperset(exerciseIds: [UUID]) {
        guard exerciseIds.count >= 2 else { return }
        let supersetId = UUID()

        for i in exercises.indices {
            if exerciseIds.contains(exercises[i].id) {
                exercises[i].supersetGroupId = supersetId
            }
        }
        updatedAt = Date()
    }

    /// Remove an exercise from its superset
    mutating func breakSuperset(exerciseId: UUID) {
        if let index = exercises.firstIndex(where: { $0.id == exerciseId }) {
            exercises[index].supersetGroupId = nil
            updatedAt = Date()
        }
    }

    /// Break all exercises in a superset
    mutating func breakSupersetGroup(supersetGroupId: UUID) {
        for i in exercises.indices {
            if exercises[i].supersetGroupId == supersetGroupId {
                exercises[i].supersetGroupId = nil
            }
        }
        updatedAt = Date()
    }
}

// MARK: - Sample Data

extension Module {
    static let sampleWarmup = Module(
        name: "Standard Warmup",
        type: .warmup,
        exercises: [
            Exercise(name: "Light Jog", exerciseType: .cardio, setGroups: [
                SetGroup(sets: 1, targetDuration: 300, notes: "5 minutes easy")
            ]),
            Exercise(name: "Leg Swings", exerciseType: .mobility, setGroups: [
                SetGroup(sets: 1, targetReps: 10, notes: "Each direction")
            ]),
            Exercise(name: "Hip Circles", exerciseType: .mobility, setGroups: [
                SetGroup(sets: 1, targetReps: 10, notes: "Each direction")
            ])
        ],
        estimatedDuration: 10
    )

    static let samplePrehab = Module(
        name: "Knee Care",
        type: .prehab,
        exercises: [
            Exercise(name: "VMO Iso Hold", exerciseType: .isometric, setGroups: [
                SetGroup(sets: 3, targetHoldTime: 30, restPeriod: 30)
            ]),
            Exercise(name: "Terminal Knee Extensions", exerciseType: .strength, setGroups: [
                SetGroup(sets: 2, targetReps: 15, restPeriod: 60, notes: "Banded")
            ])
        ],
        notes: "Do before every lower session",
        estimatedDuration: 10
    )

    static let sampleStrength = Module(
        name: "Lower Body A",
        type: .strength,
        exercises: [
            Exercise(name: "Back Squat", exerciseType: .strength, setGroups: [
                SetGroup(sets: 1, targetReps: 3, targetRPE: 8, restPeriod: 240, notes: "Top set"),
                SetGroup(sets: 3, targetReps: 6, restPeriod: 180, notes: "Back-off sets")
            ]),
            Exercise(name: "Romanian Deadlift", exerciseType: .strength, setGroups: [
                SetGroup(sets: 4, targetReps: 8, restPeriod: 120)
            ]),
            Exercise(name: "Bulgarian Split Squat", exerciseType: .strength, setGroups: [
                SetGroup(sets: 3, targetReps: 10, restPeriod: 90, notes: "Each leg")
            ])
        ],
        estimatedDuration: 60
    )
}
