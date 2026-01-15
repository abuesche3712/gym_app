//
//  ResolvedExercise.swift
//  gym app
//
//  A hydrated view model that combines ExerciseInstance + ExerciseTemplate.
//  This is what Views consume - they don't need to know about the split.
//

import Foundation

struct ResolvedExercise: Identifiable, Hashable {
    let instance: ExerciseInstance
    let template: ExerciseTemplate?

    // MARK: - Identity

    var id: UUID { instance.id }
    var templateId: UUID { instance.templateId }

    // MARK: - Resolved Properties (instance override ?? template ?? default)

    var name: String {
        instance.nameOverride ?? template?.name ?? "Unknown Exercise"
    }

    var exerciseType: ExerciseType {
        instance.exerciseTypeOverride ?? template?.exerciseType ?? .strength
    }

    // MARK: - Template Properties (pass-through)

    var category: ExerciseCategory {
        template?.category ?? .fullBody
    }

    var cardioMetric: CardioMetric {
        template?.cardioMetric ?? .timeOnly
    }

    var mobilityTracking: MobilityTracking {
        template?.mobilityTracking ?? .repsOnly
    }

    var distanceUnit: DistanceUnit {
        template?.distanceUnit ?? .meters
    }

    var muscleGroupIds: Set<UUID> {
        template?.muscleGroupIds ?? []
    }

    var implementIds: Set<UUID> {
        template?.implementIds ?? []
    }

    var isBodyweight: Bool {
        template?.isBodyweight ?? false
    }

    var recoveryActivityType: RecoveryActivityType? {
        template?.recoveryActivityType
    }

    var primaryMuscles: [MuscleGroup] {
        template?.primaryMuscles ?? []
    }

    var secondaryMuscles: [MuscleGroup] {
        template?.secondaryMuscles ?? []
    }

    // MARK: - Instance Properties

    var setGroups: [SetGroup] { instance.setGroups }
    var supersetGroupId: UUID? { instance.supersetGroupId }
    var order: Int { instance.order }

    /// Notes from instance, falling back to template default notes
    var notes: String? {
        instance.notes ?? template?.defaultNotes
    }

    var createdAt: Date { instance.createdAt }
    var updatedAt: Date { instance.updatedAt }

    // MARK: - Computed Properties

    /// Whether the template is missing (orphaned instance)
    var isOrphan: Bool { template == nil }

    /// Whether the template is archived
    var isTemplateArchived: Bool { template?.isArchived ?? false }

    /// Whether this instance is part of a superset
    var isInSuperset: Bool { instance.isInSuperset }

    /// Total number of sets across all set groups
    var totalSets: Int { instance.totalSets }

    /// Default tracking metrics based on exercise type
    var trackingMetrics: [MetricType] {
        ResolvedExercise.defaultMetrics(for: exerciseType)
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

    /// Human-readable set scheme (e.g., "3x8 + 3x10")
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

    // MARK: - Static Methods

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
            return [.duration]
        }
    }

    // MARK: - Private Helpers

    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) {
            return "\(Int(distance))\(distanceUnit.abbreviation)"
        }
        return String(format: "%.1f%@", distance, distanceUnit.abbreviation)
    }
}

// MARK: - Convenience Initializers

extension ResolvedExercise {
    /// Creates a placeholder for an orphaned instance
    static func orphan(from instance: ExerciseInstance) -> ResolvedExercise {
        ResolvedExercise(instance: instance, template: nil)
    }
}

// MARK: - ExerciseInstance Extension

extension ExerciseInstance {
    /// Resolves this instance with the given template
    func resolved(with template: ExerciseTemplate?) -> ResolvedExercise {
        ResolvedExercise(instance: self, template: template)
    }
}
