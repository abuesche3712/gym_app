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
    var templateId: UUID?  // Links to ExerciseLibrary for progress tracking
    var exerciseType: ExerciseType
    var cardioMetric: CardioMetric  // Time-based or distance-based (for cardio)
    var mobilityTracking: MobilityTracking  // Reps, duration, or both (for mobility)
    var distanceUnit: DistanceUnit  // Unit for distance tracking
    var setGroups: [SetGroup]
    var trackingMetrics: [MetricType]
    var supersetGroupId: UUID?  // Exercises with same ID are in a superset
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // New library system fields
    var muscleGroupIds: Set<UUID>  // Links to MuscleGroupEntity
    var implementIds: Set<UUID>    // Links to ImplementEntity
    var isBodyweight: Bool  // True for bodyweight exercises (pull-ups, dips) - shows "BW + X" format

    // Recovery-specific fields
    var recoveryActivityType: RecoveryActivityType?  // Type of recovery activity (only for recovery exercises)

    init(
        id: UUID = UUID(),
        name: String,
        templateId: UUID? = nil,
        exerciseType: ExerciseType,
        cardioMetric: CardioMetric = .timeOnly,
        mobilityTracking: MobilityTracking = .repsOnly,
        distanceUnit: DistanceUnit = .meters,
        setGroups: [SetGroup] = [],
        trackingMetrics: [MetricType]? = nil,
        supersetGroupId: UUID? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        muscleGroupIds: Set<UUID> = [],
        implementIds: Set<UUID> = [],
        isBodyweight: Bool = false,
        recoveryActivityType: RecoveryActivityType? = nil
    ) {
        self.id = id
        self.name = name
        self.templateId = templateId
        self.exerciseType = exerciseType
        self.cardioMetric = cardioMetric
        self.mobilityTracking = mobilityTracking
        self.distanceUnit = distanceUnit
        self.setGroups = setGroups
        self.supersetGroupId = supersetGroupId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.muscleGroupIds = muscleGroupIds
        self.implementIds = implementIds
        self.isBodyweight = isBodyweight
        self.recoveryActivityType = recoveryActivityType

        // Set default tracking metrics based on exercise type
        if let metrics = trackingMetrics {
            self.trackingMetrics = metrics
        } else {
            self.trackingMetrics = Exercise.defaultMetrics(for: exerciseType)
        }
    }

    /// Whether this cardio exercise should log time
    var tracksTime: Bool {
        exerciseType == .cardio && cardioMetric.tracksTime
    }

    /// Whether this cardio exercise should log distance
    var tracksDistance: Bool {
        exerciseType == .cardio && cardioMetric.tracksDistance
    }

    /// Legacy: Whether this is primarily distance-based (for target display)
    var isDistanceBased: Bool {
        exerciseType == .cardio && cardioMetric == .distanceOnly
    }

    /// Whether this mobility exercise should log reps
    var mobilityTracksReps: Bool {
        exerciseType == .mobility && mobilityTracking.tracksReps
    }

    /// Whether this mobility exercise should log duration
    var mobilityTracksDuration: Bool {
        exerciseType == .mobility && mobilityTracking.tracksDuration
    }

    var isInSuperset: Bool {
        supersetGroupId != nil
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
        case .recovery:
            return [.duration]  // Recovery is primarily time-based
        }
    }

    var totalSets: Int {
        setGroups.reduce(0) { $0 + $1.sets }
    }

    var formattedSetScheme: String {
        setGroups.map { group in
            if let reps = group.targetReps {
                return "\(group.sets)x\(reps)"
            } else if let distance = group.targetDistance, isDistanceBased {
                return "\(group.sets)x\(formatDistance(distance))"
            } else if let duration = group.targetDuration {
                return "\(group.sets)x\(formatDurationVerbose(duration))"
            } else if let holdTime = group.targetHoldTime {
                return "\(group.sets)x\(formatDurationVerbose(holdTime)) hold"
            }
            return "\(group.sets) sets"
        }.joined(separator: " + ")
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) {
            return "\(Int(distance))\(distanceUnit.abbreviation)"
        }
        return String(format: "%.1f%@", distance, distanceUnit.abbreviation)
    }
}
