//
//  SessionExercise.swift
//  gym app
//
//  An exercise performed during a workout session with logged data
//

import Foundation

struct SessionExercise: Identifiable, Codable, Hashable, ExerciseMetrics {
    var id: UUID
    var exerciseId: UUID
    var exerciseName: String // Denormalized
    var exerciseType: ExerciseType
    var cardioMetric: CardioMetric // Time or distance based
    var mobilityTracking: MobilityTracking // Reps, duration, or both (for mobility)
    var distanceUnit: DistanceUnit // Unit for distance tracking
    var supersetGroupId: UUID? // Links exercises that should alternate sets
    var completedSetGroups: [CompletedSetGroup]
    var notes: String?
    var isBodyweight: Bool // True for bodyweight exercises (pull-ups, dips) - shows "BW + X" format
    var tracksAddedWeight: Bool // For bodyweight exercises - whether to show added weight input
    var recoveryActivityType: RecoveryActivityType? // For recovery exercises

    // Equipment - determines input fields (e.g., band shows color instead of weight)
    var implementIds: Set<UUID>

    // Muscle groups (editable during session)
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]

    // Ad-hoc modifications during session
    var isSubstitution: Bool
    var originalExerciseName: String? // Original name if substituted
    var isAdHoc: Bool // True if added during session

    /// The original ExerciseInstance ID this came from (nil if added mid-session)
    var sourceExerciseInstanceId: UUID?

    // Progression tracking
    var progressionRecommendation: ProgressionRecommendation? // User's recommendation for next session
    var progressionSuggestion: ProgressionSuggestion?         // System-calculated suggestion

    // Sharing context (denormalized for standalone sharing)
    var sessionId: UUID?
    var moduleId: UUID?
    var moduleName: String?
    var workoutId: UUID?
    var workoutName: String?
    var date: Date?

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        exerciseType: ExerciseType,
        cardioMetric: CardioMetric = .timeOnly,
        mobilityTracking: MobilityTracking = .repsOnly,
        distanceUnit: DistanceUnit = .meters,
        supersetGroupId: UUID? = nil,
        completedSetGroups: [CompletedSetGroup] = [],
        notes: String? = nil,
        isBodyweight: Bool = false,
        tracksAddedWeight: Bool = true,
        recoveryActivityType: RecoveryActivityType? = nil,
        implementIds: Set<UUID> = [],
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        isSubstitution: Bool = false,
        originalExerciseName: String? = nil,
        isAdHoc: Bool = false,
        sourceExerciseInstanceId: UUID? = nil,
        progressionRecommendation: ProgressionRecommendation? = nil,
        progressionSuggestion: ProgressionSuggestion? = nil,
        sessionId: UUID? = nil,
        moduleId: UUID? = nil,
        moduleName: String? = nil,
        workoutId: UUID? = nil,
        workoutName: String? = nil,
        date: Date? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType
        self.cardioMetric = cardioMetric
        self.mobilityTracking = mobilityTracking
        self.distanceUnit = distanceUnit
        self.supersetGroupId = supersetGroupId
        self.completedSetGroups = completedSetGroups
        self.notes = notes
        self.isBodyweight = isBodyweight
        self.tracksAddedWeight = tracksAddedWeight
        self.recoveryActivityType = recoveryActivityType
        self.implementIds = implementIds
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.isSubstitution = isSubstitution
        self.originalExerciseName = originalExerciseName
        self.isAdHoc = isAdHoc
        self.sourceExerciseInstanceId = sourceExerciseInstanceId
        self.progressionRecommendation = progressionRecommendation
        self.progressionSuggestion = progressionSuggestion
        self.sessionId = sessionId
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        exerciseType = try container.decode(ExerciseType.self, forKey: .exerciseType)

        // Optional with defaults
        cardioMetric = try container.decodeIfPresent(CardioMetric.self, forKey: .cardioMetric) ?? .timeOnly
        mobilityTracking = try container.decodeIfPresent(MobilityTracking.self, forKey: .mobilityTracking) ?? .repsOnly
        distanceUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .meters
        completedSetGroups = try container.decodeIfPresent([CompletedSetGroup].self, forKey: .completedSetGroups) ?? []
        isBodyweight = try container.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        tracksAddedWeight = try container.decodeIfPresent(Bool.self, forKey: .tracksAddedWeight) ?? true
        implementIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .implementIds) ?? []
        primaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscles) ?? []
        isSubstitution = try container.decodeIfPresent(Bool.self, forKey: .isSubstitution) ?? false
        isAdHoc = try container.decodeIfPresent(Bool.self, forKey: .isAdHoc) ?? false
        sourceExerciseInstanceId = try container.decodeIfPresent(UUID.self, forKey: .sourceExerciseInstanceId)

        // Truly optional
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        recoveryActivityType = try container.decodeIfPresent(RecoveryActivityType.self, forKey: .recoveryActivityType)
        originalExerciseName = try container.decodeIfPresent(String.self, forKey: .originalExerciseName)
        progressionRecommendation = try container.decodeIfPresent(ProgressionRecommendation.self, forKey: .progressionRecommendation)
        progressionSuggestion = try container.decodeIfPresent(ProgressionSuggestion.self, forKey: .progressionSuggestion)

        // Sharing context (optional - populated when needed for sharing)
        sessionId = try container.decodeIfPresent(UUID.self, forKey: .sessionId)
        moduleId = try container.decodeIfPresent(UUID.self, forKey: .moduleId)
        moduleName = try container.decodeIfPresent(String.self, forKey: .moduleName)
        workoutId = try container.decodeIfPresent(UUID.self, forKey: .workoutId)
        workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, exerciseType, cardioMetric, mobilityTracking, distanceUnit
        case supersetGroupId, completedSetGroups, notes, isBodyweight, tracksAddedWeight, recoveryActivityType, implementIds
        case primaryMuscles, secondaryMuscles
        case isSubstitution, originalExerciseName, isAdHoc, sourceExerciseInstanceId, progressionRecommendation, progressionSuggestion
        case sessionId, moduleId, moduleName, workoutId, workoutName, date
    }

    var totalVolume: Double {
        completedSetGroups.reduce(0) { groupTotal, setGroup in
            groupTotal + setGroup.sets.reduce(0) { setTotal, set in
                // Only count completed sets
                if set.completed {
                    return setTotal + (set.weight ?? 0) * Double(set.reps ?? 0)
                }
                return setTotal
            }
        }
    }

    var topSet: SetData? {
        completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed }
            .max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

    /// Returns true if this exercise uses a resistance band (check by implement name)
    var usesBand: Bool {
        guard !implementIds.isEmpty else { return false }
        let library = LibraryService.shared
        return implementIds.contains { id in
            guard let implement = library.getImplement(id: id) else { return false }
            let name = implement.name.lowercased()
            return name.contains("band") || name.contains("resistance")
        }
    }

    /// Returns the primary implement's measurable info if it has a string-based measurable (like band color)
    var implementStringMeasurable: ImplementMeasurableInfo? {
        guard !implementIds.isEmpty else { return nil }
        let library = LibraryService.shared
        for id in implementIds {
            guard let implement = library.getImplement(id: id) else { continue }
            // Find string-based measurable
            if let stringMeasurable = implement.measurableArray.first(where: { $0.isStringBased }) {
                return ImplementMeasurableInfo(
                    implementName: implement.name,
                    measurableName: stringMeasurable.name,
                    unit: stringMeasurable.unit,
                    isStringBased: true
                )
            }
        }
        return nil
    }

    /// Returns true if this exercise uses a box (for height input)
    var usesBox: Bool {
        guard !implementIds.isEmpty else { return false }
        let library = LibraryService.shared
        return implementIds.contains { id in
            guard let implement = library.getImplement(id: id) else { return false }
            return implement.name.lowercased().contains("box")
        }
    }

    /// Returns all implements' names for display
    var implementNames: [String] {
        let library = LibraryService.shared
        return implementIds.compactMap { id in
            library.getImplement(id: id)?.name
        }.sorted()
    }
}

/// Info about an implement's measurable for UI display
struct ImplementMeasurableInfo {
    let implementName: String
    let measurableName: String
    let unit: String
    let isStringBased: Bool
}
