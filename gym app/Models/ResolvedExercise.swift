//
//  ResolvedExercise.swift
//  gym app
//
//  A view model wrapper around ExerciseInstance.
//  Since ExerciseInstance now stores all data directly, this is mostly a pass-through.
//  Kept for API compatibility and minor template-only lookups (like category).
//

import Foundation

struct ResolvedExercise: Identifiable, Hashable, ExerciseMetrics {
    let instance: ExerciseInstance
    let template: ExerciseTemplate?

    // MARK: - Identity

    var id: UUID { instance.id }
    var templateId: UUID? { instance.templateId }

    // MARK: - Direct Properties (from instance)

    var name: String { instance.name }
    var exerciseType: ExerciseType { instance.exerciseType }
    var cardioMetric: CardioMetric { instance.cardioMetric }
    var mobilityTracking: MobilityTracking { instance.mobilityTracking }
    var distanceUnit: DistanceUnit { instance.distanceUnit }
    var isBodyweight: Bool { instance.isBodyweight }
    var recoveryActivityType: RecoveryActivityType? { instance.recoveryActivityType }
    var primaryMuscles: [MuscleGroup] { instance.primaryMuscles }
    var secondaryMuscles: [MuscleGroup] { instance.secondaryMuscles }
    var implementIds: Set<UUID> { instance.implementIds }

    // Category is only on template (not critical for display)
    var category: ExerciseCategory {
        template?.category ?? .fullBody
    }

    // MARK: - Instance Properties

    var setGroups: [SetGroup] { instance.setGroups }
    var supersetGroupId: UUID? { instance.supersetGroupId }
    var order: Int { instance.order }
    var notes: String? { instance.notes }
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
    /// Creates a ResolvedExercise without template lookup (instance has all data)
    init(instance: ExerciseInstance) {
        self.instance = instance
        self.template = nil
    }

    /// Creates a placeholder for an orphaned instance
    static func orphan(from instance: ExerciseInstance) -> ResolvedExercise {
        ResolvedExercise(instance: instance, template: nil)
    }
}

// MARK: - ExerciseInstance Extension

extension ExerciseInstance {
    /// Resolves this instance (template lookup is optional now)
    func resolved(with template: ExerciseTemplate? = nil) -> ResolvedExercise {
        ResolvedExercise(instance: self, template: template)
    }

    /// Resolves without template lookup
    func resolved() -> ResolvedExercise {
        ResolvedExercise(instance: self)
    }
}
