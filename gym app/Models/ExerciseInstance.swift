//
//  ExerciseInstance.swift
//  gym app
//
//  Self-contained exercise data stored within modules.
//  All exercise properties are stored directly - no template lookup needed.
//

import Foundation

struct ExerciseInstance: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.exerciseInstance

    var id: UUID

    // Optional template reference (for history/analytics, not required for display)
    var templateId: UUID?

    // Exercise data stored directly
    var name: String
    var exerciseType: ExerciseType
    var cardioMetric: CardioTracking
    var distanceUnit: DistanceUnit
    var mobilityTracking: MobilityTracking
    var isBodyweight: Bool
    var recoveryActivityType: RecoveryActivityType?
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]

    // Set configuration
    var setGroups: [SetGroup]
    var supersetGroupId: UUID?
    var order: Int
    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        templateId: UUID? = nil,
        name: String,
        exerciseType: ExerciseType = .strength,
        cardioMetric: CardioTracking = .timeOnly,
        distanceUnit: DistanceUnit = .meters,
        mobilityTracking: MobilityTracking = .repsOnly,
        isBodyweight: Bool = false,
        recoveryActivityType: RecoveryActivityType? = nil,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        setGroups: [SetGroup] = [],
        supersetGroupId: UUID? = nil,
        order: Int = 0,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.exerciseType = exerciseType
        self.cardioMetric = cardioMetric
        self.distanceUnit = distanceUnit
        self.mobilityTracking = mobilityTracking
        self.isBodyweight = isBodyweight
        self.recoveryActivityType = recoveryActivityType
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.setGroups = setGroups
        self.supersetGroupId = supersetGroupId
        self.order = order
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.exerciseInstance

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Template reference (now optional)
        templateId = try container.decodeIfPresent(UUID.self, forKey: .templateId)

        // Direct fields with migration from old override system
        // Try new direct fields first, then fall back to overrides, then defaults
        if let directName = try container.decodeIfPresent(String.self, forKey: .name) {
            name = directName
        } else if let nameOverride = try container.decodeIfPresent(String.self, forKey: .nameOverride) {
            name = nameOverride
        } else {
            // Will need template lookup for migration - use placeholder
            name = "Unknown Exercise"
        }

        if let directType = try container.decodeIfPresent(ExerciseType.self, forKey: .exerciseType) {
            exerciseType = directType
        } else if let typeOverride = try container.decodeIfPresent(ExerciseType.self, forKey: .exerciseTypeOverride) {
            exerciseType = typeOverride
        } else {
            exerciseType = .strength
        }

        if let directCardio = try container.decodeIfPresent(CardioTracking.self, forKey: .cardioMetric) {
            cardioMetric = directCardio
        } else if let cardioOverride = try container.decodeIfPresent(CardioTracking.self, forKey: .cardioMetricOverride) {
            cardioMetric = cardioOverride
        } else {
            cardioMetric = .timeOnly
        }

        if let directDistance = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) {
            distanceUnit = directDistance
        } else if let distanceOverride = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnitOverride) {
            distanceUnit = distanceOverride
        } else {
            distanceUnit = .meters
        }

        if let directMobility = try container.decodeIfPresent(MobilityTracking.self, forKey: .mobilityTracking) {
            mobilityTracking = directMobility
        } else if let mobilityOverride = try container.decodeIfPresent(MobilityTracking.self, forKey: .mobilityTrackingOverride) {
            mobilityTracking = mobilityOverride
        } else {
            mobilityTracking = .repsOnly
        }

        isBodyweight = try container.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        recoveryActivityType = try container.decodeIfPresent(RecoveryActivityType.self, forKey: .recoveryActivityType)
        primaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscles) ?? []

        // Optional with defaults
        setGroups = try container.decodeIfPresent([SetGroup].self, forKey: .setGroups) ?? []
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0

        // Truly optional
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // MARK: - Data Sanitization

        // Ensure name is never empty
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "Unnamed Exercise"
            Logger.warning("Loaded exercise with empty name, using placeholder")
        }

        // Clamp order to non-negative
        if order < 0 {
            order = 0
            Logger.warning("Loaded exercise with negative order, clamped to 0")
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, templateId, name, exerciseType, cardioMetric, distanceUnit, mobilityTracking
        case isBodyweight, recoveryActivityType, primaryMuscles, secondaryMuscles
        case setGroups, supersetGroupId, order, notes
        case createdAt, updatedAt
        // Legacy keys for migration
        case nameOverride, exerciseTypeOverride, cardioMetricOverride, distanceUnitOverride, mobilityTrackingOverride
    }

    // Only encode new fields (not legacy overrides)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(templateId, forKey: .templateId)
        try container.encode(name, forKey: .name)
        try container.encode(exerciseType, forKey: .exerciseType)
        try container.encode(cardioMetric, forKey: .cardioMetric)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(mobilityTracking, forKey: .mobilityTracking)
        try container.encode(isBodyweight, forKey: .isBodyweight)
        try container.encodeIfPresent(recoveryActivityType, forKey: .recoveryActivityType)
        try container.encode(primaryMuscles, forKey: .primaryMuscles)
        try container.encode(secondaryMuscles, forKey: .secondaryMuscles)
        try container.encode(setGroups, forKey: .setGroups)
        try container.encodeIfPresent(supersetGroupId, forKey: .supersetGroupId)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Whether this instance is part of a superset
    var isInSuperset: Bool {
        supersetGroupId != nil
    }

    /// Total number of sets across all set groups
    var totalSets: Int {
        setGroups.reduce(0) { $0 + $1.sets }
    }

    /// Creates an instance from a template, copying all data
    static func from(template: ExerciseTemplate, order: Int = 0) -> ExerciseInstance {
        // Validate inputs - log warning for bad data
        if template.name.isEmpty {
            Logger.warning("Creating instance from template with empty name")
        }
        if order < 0 {
            Logger.warning("Creating instance with negative order \(order), clamping to 0")
        }

        return ExerciseInstance(
            templateId: template.id,
            name: template.name.isEmpty ? "Unknown Exercise" : template.name,  // Fallback just in case
            exerciseType: template.exerciseType,
            cardioMetric: template.cardioMetric,
            distanceUnit: template.distanceUnit,
            mobilityTracking: template.mobilityTracking,
            isBodyweight: template.isBodyweight,
            recoveryActivityType: template.recoveryActivityType,
            primaryMuscles: template.primaryMuscles,
            secondaryMuscles: template.secondaryMuscles,
            setGroups: template.defaultSetGroups,
            order: max(0, order)  // Clamp to non-negative
        )
    }

    // MARK: - Validation

    enum ValidationError: LocalizedError {
        case emptyName
        case invalidSetGroups
        case negativeOrder

        var errorDescription: String? {
            switch self {
            case .emptyName: return "Exercise name cannot be empty"
            case .invalidSetGroups: return "Exercise must have at least one set group"
            case .negativeOrder: return "Order cannot be negative"
            }
        }
    }

    /// Validates the instance and throws if invalid
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyName
        }
        if order < 0 {
            throw ValidationError.negativeOrder
        }
        // Note: empty setGroups is allowed for newly added exercises
    }

    /// Returns true if this instance has valid data for use in a workout
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && order >= 0
    }
}
