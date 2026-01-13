//
//  Exercise.swift
//  gym app
//
//  A specific movement or activity within a module
//

import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var exerciseType: ExerciseType
    var setGroups: [SetGroup]
    var trackingMetrics: [MetricType]
    var progressionType: ProgressionType
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        exerciseType: ExerciseType,
        setGroups: [SetGroup] = [],
        trackingMetrics: [MetricType]? = nil,
        progressionType: ProgressionType = .none,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exerciseType = exerciseType
        self.setGroups = setGroups
        self.progressionType = progressionType
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Set default tracking metrics based on exercise type
        if let metrics = trackingMetrics {
            self.trackingMetrics = metrics
        } else {
            self.trackingMetrics = Exercise.defaultMetrics(for: exerciseType)
        }
    }

    static func defaultMetrics(for type: ExerciseType) -> [MetricType] {
        switch type {
        case .strength:
            return [.weight, .reps, .rpe]
        case .cardio:
            return [.duration, .distance, .pace]
        case .mobility:
            return [.reps, .duration]
        case .isometric:
            return [.holdTime, .rpe]
        case .explosive:
            return [.reps, .height]
        }
    }

    var totalSets: Int {
        setGroups.reduce(0) { $0 + $1.sets }
    }

    var formattedSetScheme: String {
        setGroups.map { group in
            if let reps = group.targetReps {
                return "\(group.sets)x\(reps)"
            } else if let duration = group.targetDuration {
                return "\(group.sets)x\(duration)s"
            } else if let holdTime = group.targetHoldTime {
                return "\(group.sets)x\(holdTime)s hold"
            }
            return "\(group.sets) sets"
        }.joined(separator: " + ")
    }
}
