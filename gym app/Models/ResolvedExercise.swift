//
//  ResolvedExercise.swift
//  gym app
//
//  A hydrated view model that combines ExerciseInstance + ExerciseTemplate.
//  This is what Views consume - they don't need to know about the split.
//

import Foundation

struct ResolvedExercise: Identifiable, Hashable, ExerciseMetrics {
    let instance: ExerciseInstance
    let template: ExerciseTemplate?

    // MARK: - Identity

    var id: UUID { instance.id }
    var templateId: UUID { instance.templateId }

    // MARK: - Resolved Properties

    /// Name: uses instance override if set, otherwise template name
    var name: String {
        instance.nameOverride ?? template?.name ?? "Unknown Exercise"
    }

    // MARK: - Template Properties (pass-through with defaults)

    var exerciseType: ExerciseType {
        template?.exerciseType ?? .strength
    }

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

    /// Total number of sets across all set groups
    var totalSets: Int { instance.totalSets }

    /// Default tracking metrics based on exercise type
    var trackingMetrics: [MetricType] {
        ResolvedExercise.defaultMetrics(for: exerciseType)
    }

    /// Human-readable set scheme (e.g., "3x8 + 3x10")
    var formattedSetScheme: String {
        setGroups.map { group in
            if let reps = group.targetReps {
                return "\(group.sets)x\(reps)"
            } else if let distance = group.targetDistance, isDistanceBased {
                return "\(group.sets)x\(formatDistance(distance, unit: distanceUnit))"
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
