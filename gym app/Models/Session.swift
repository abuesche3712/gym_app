//
//  Session.swift
//  gym app
//
//  A completed workout instance with actual logged data
//

import Foundation

struct Session: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.session

    var id: UUID
    var workoutId: UUID
    var workoutName: String // Denormalized for easy display
    var date: Date
    var completedModules: [CompletedModule]
    var skippedModuleIds: [UUID]
    var duration: Int? // minutes, actual time taken
    var overallFeeling: Int? // 1-5 scale
    var notes: String?
    var createdAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        date: Date = Date(),
        completedModules: [CompletedModule] = [],
        skippedModuleIds: [UUID] = [],
        duration: Int? = nil,
        overallFeeling: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.date = date
        self.completedModules = completedModules
        self.skippedModuleIds = skippedModuleIds
        self.duration = duration
        self.overallFeeling = overallFeeling
        self.notes = notes
        self.createdAt = createdAt
        self.syncStatus = syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.session

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        date = try container.decode(Date.self, forKey: .date)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        syncStatus = try container.decode(SyncStatus.self, forKey: .syncStatus)

        // Optional with defaults
        completedModules = try container.decodeIfPresent([CompletedModule].self, forKey: .completedModules) ?? []
        skippedModuleIds = try container.decodeIfPresent([UUID].self, forKey: .skippedModuleIds) ?? []

        // Truly optional
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        overallFeeling = try container.decodeIfPresent(Int.self, forKey: .overallFeeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, workoutId, workoutName, date, completedModules, skippedModuleIds, duration, overallFeeling, notes, createdAt, syncStatus
    }

    var formattedDate: String {
        formatDate(date)
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        return formatDurationMinutes(duration)
    }

    var totalExercisesCompleted: Int {
        completedModules.reduce(0) { $0 + $1.completedExercises.count }
    }

    var totalSetsCompleted: Int {
        completedModules.reduce(0) { module, completed in
            module + completed.completedExercises.reduce(0) { exercise, completedExercise in
                exercise + completedExercise.completedSetGroups.reduce(0) { setGroup, completed in
                    setGroup + completed.sets.count
                }
            }
        }
    }

    /// Whether this session can still be edited (within 30 days of creation)
    var isEditable: Bool {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return daysSinceCreation <= 30
    }
}

// MARK: - Completed Module

struct CompletedModule: Identifiable, Codable, Hashable {
    var id: UUID
    var moduleId: UUID
    var moduleName: String // Denormalized
    var moduleType: ModuleType
    var completedExercises: [SessionExercise]
    var skipped: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        moduleId: UUID,
        moduleName: String,
        moduleType: ModuleType,
        completedExercises: [SessionExercise] = [],
        skipped: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.moduleType = moduleType
        self.completedExercises = completedExercises
        self.skipped = skipped
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        moduleId = try container.decode(UUID.self, forKey: .moduleId)
        moduleName = try container.decode(String.self, forKey: .moduleName)
        moduleType = try container.decode(ModuleType.self, forKey: .moduleType)

        // Optional with defaults
        completedExercises = try container.decodeIfPresent([SessionExercise].self, forKey: .completedExercises) ?? []
        skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped) ?? false

        // Truly optional
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, moduleId, moduleName, moduleType, completedExercises, skipped, notes
    }
}

// MARK: - Session Exercise

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

    // Progression tracking
    var progressionRecommendation: ProgressionRecommendation? // User's recommendation for next session

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
        recoveryActivityType: RecoveryActivityType? = nil,
        implementIds: Set<UUID> = [],
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        isSubstitution: Bool = false,
        originalExerciseName: String? = nil,
        isAdHoc: Bool = false,
        progressionRecommendation: ProgressionRecommendation? = nil
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
        self.recoveryActivityType = recoveryActivityType
        self.implementIds = implementIds
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.isSubstitution = isSubstitution
        self.originalExerciseName = originalExerciseName
        self.isAdHoc = isAdHoc
        self.progressionRecommendation = progressionRecommendation
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
        implementIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .implementIds) ?? []
        primaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscles) ?? []
        isSubstitution = try container.decodeIfPresent(Bool.self, forKey: .isSubstitution) ?? false
        isAdHoc = try container.decodeIfPresent(Bool.self, forKey: .isAdHoc) ?? false

        // Truly optional
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        recoveryActivityType = try container.decodeIfPresent(RecoveryActivityType.self, forKey: .recoveryActivityType)
        originalExerciseName = try container.decodeIfPresent(String.self, forKey: .originalExerciseName)
        progressionRecommendation = try container.decodeIfPresent(ProgressionRecommendation.self, forKey: .progressionRecommendation)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, exerciseType, cardioMetric, mobilityTracking, distanceUnit
        case supersetGroupId, completedSetGroups, notes, isBodyweight, recoveryActivityType, implementIds
        case primaryMuscles, secondaryMuscles
        case isSubstitution, originalExerciseName, isAdHoc, progressionRecommendation
    }

    var totalVolume: Double {
        completedSetGroups.reduce(0) { groupTotal, setGroup in
            groupTotal + setGroup.sets.reduce(0) { setTotal, set in
                setTotal + (set.weight ?? 0) * Double(set.reps ?? 0)
            }
        }
    }

    var topSet: SetData? {
        completedSetGroups
            .flatMap { $0.sets }
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

// MARK: - Completed Set Group

struct CompletedSetGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var setGroupId: UUID
    var restPeriod: Int?  // Target rest period from original SetGroup
    var sets: [SetData]

    // Interval mode fields
    var isInterval: Bool
    var workDuration: Int?  // seconds of work per round
    var intervalRestDuration: Int?  // seconds of rest between rounds

    // AMRAP mode fields
    var isAMRAP: Bool
    var amrapTimeLimit: Int?  // optional time limit in seconds

    // Unilateral mode
    var isUnilateral: Bool  // If true, sets have left/right sides

    // RPE tracking
    var trackRPE: Bool  // Whether to track RPE for this set group

    // Multi-measurable targets from the workout template
    var implementMeasurables: [ImplementMeasurableTarget]

    init(
        id: UUID = UUID(),
        setGroupId: UUID,
        restPeriod: Int? = nil,
        sets: [SetData] = [],
        isInterval: Bool = false,
        workDuration: Int? = nil,
        intervalRestDuration: Int? = nil,
        isAMRAP: Bool = false,
        amrapTimeLimit: Int? = nil,
        isUnilateral: Bool = false,
        trackRPE: Bool = true,
        implementMeasurables: [ImplementMeasurableTarget] = []
    ) {
        self.id = id
        self.setGroupId = setGroupId
        self.restPeriod = restPeriod
        self.sets = sets
        self.isInterval = isInterval
        self.workDuration = workDuration
        self.intervalRestDuration = intervalRestDuration
        self.isAMRAP = isAMRAP
        self.amrapTimeLimit = amrapTimeLimit
        self.isUnilateral = isUnilateral
        self.trackRPE = trackRPE
        self.implementMeasurables = implementMeasurables
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        setGroupId = try container.decode(UUID.self, forKey: .setGroupId)

        // Optional with defaults
        sets = try container.decodeIfPresent([SetData].self, forKey: .sets) ?? []
        isInterval = try container.decodeIfPresent(Bool.self, forKey: .isInterval) ?? false
        isAMRAP = try container.decodeIfPresent(Bool.self, forKey: .isAMRAP) ?? false
        isUnilateral = try container.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        trackRPE = try container.decodeIfPresent(Bool.self, forKey: .trackRPE) ?? true
        implementMeasurables = try container.decodeIfPresent([ImplementMeasurableTarget].self, forKey: .implementMeasurables) ?? []

        // Truly optional
        restPeriod = try container.decodeIfPresent(Int.self, forKey: .restPeriod)
        workDuration = try container.decodeIfPresent(Int.self, forKey: .workDuration)
        intervalRestDuration = try container.decodeIfPresent(Int.self, forKey: .intervalRestDuration)
        amrapTimeLimit = try container.decodeIfPresent(Int.self, forKey: .amrapTimeLimit)
    }

    private enum CodingKeys: String, CodingKey {
        case id, setGroupId, restPeriod, sets, isInterval, workDuration, intervalRestDuration
        case isAMRAP, amrapTimeLimit, isUnilateral, trackRPE, implementMeasurables
    }

    /// Total rounds (for interval mode, equals number of sets)
    var rounds: Int {
        sets.count
    }
}

// MARK: - Set Data

struct SetData: Identifiable, Codable, Hashable {
    var id: UUID
    var setNumber: Int

    // Strength metrics
    var weight: Double?
    var reps: Int?
    var rpe: Int?
    var completed: Bool
    var bandColor: String? // For band exercises (e.g., "Red", "Blue")

    // Cardio metrics
    var duration: Int? // seconds
    var distance: Double?
    var pace: Double? // seconds per unit
    var avgHeartRate: Int?

    // Isometric metrics
    var holdTime: Int? // seconds
    var intensity: Int? // 1-10

    // Explosive metrics
    var height: Double?
    var quality: Int? // 1-5

    // Recovery metrics
    var temperature: Int? // °F for sauna/cold plunge

    // Rest tracking
    var restAfter: Int? // seconds, actual rest taken

    // Unilateral tracking
    var side: Side? // nil = bilateral, .left/.right = unilateral

    // Multi-measurable values (e.g., {"Height": 24.0, "Incline": 5.0})
    var implementMeasurableValues: [String: MeasurableValue]

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        rpe: Int? = nil,
        completed: Bool = true,
        bandColor: String? = nil,
        duration: Int? = nil,
        distance: Double? = nil,
        pace: Double? = nil,
        avgHeartRate: Int? = nil,
        holdTime: Int? = nil,
        intensity: Int? = nil,
        height: Double? = nil,
        quality: Int? = nil,
        temperature: Int? = nil,
        restAfter: Int? = nil,
        side: Side? = nil,
        implementMeasurableValues: [String: MeasurableValue] = [:]
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.completed = completed
        self.bandColor = bandColor
        self.duration = duration
        self.distance = distance
        self.pace = pace
        self.avgHeartRate = avgHeartRate
        self.holdTime = holdTime
        self.intensity = intensity
        self.height = height
        self.quality = quality
        self.temperature = temperature
        self.restAfter = restAfter
        self.side = side
        self.implementMeasurableValues = implementMeasurableValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        setNumber = try container.decode(Int.self, forKey: .setNumber)

        // Optional with defaults
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true

        // Truly optional (metric data)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
        bandColor = try container.decodeIfPresent(String.self, forKey: .bandColor)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        pace = try container.decodeIfPresent(Double.self, forKey: .pace)
        avgHeartRate = try container.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        holdTime = try container.decodeIfPresent(Int.self, forKey: .holdTime)
        intensity = try container.decodeIfPresent(Int.self, forKey: .intensity)
        height = try container.decodeIfPresent(Double.self, forKey: .height)
        quality = try container.decodeIfPresent(Int.self, forKey: .quality)
        temperature = try container.decodeIfPresent(Int.self, forKey: .temperature)
        restAfter = try container.decodeIfPresent(Int.self, forKey: .restAfter)
        side = try container.decodeIfPresent(Side.self, forKey: .side)

        // Multi-measurable values with backward compatibility migration
        if let values = try container.decodeIfPresent([String: MeasurableValue].self, forKey: .implementMeasurableValues) {
            implementMeasurableValues = values
        } else {
            // Migrate legacy fields to new dictionary format
            implementMeasurableValues = [:]

            // Migrate height (from box jumps)
            if let legacyHeight = try container.decodeIfPresent(Double.self, forKey: .height) {
                implementMeasurableValues["Height"] = MeasurableValue(numericValue: legacyHeight)
            }

            // Migrate bandColor (from resistance bands)
            if let legacyBandColor = try container.decodeIfPresent(String.self, forKey: .bandColor),
               !legacyBandColor.isEmpty {
                implementMeasurableValues["Color"] = MeasurableValue(stringValue: legacyBandColor)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, weight, reps, rpe, completed, bandColor, duration, distance, pace, avgHeartRate
        case holdTime, intensity, height, quality, temperature, restAfter, side, implementMeasurableValues
    }

    var formattedStrength: String? {
        guard let reps = reps else { return nil }
        var result: String
        if let band = bandColor, !band.isEmpty {
            result = "\(band) x \(reps)"
        } else if let weight = weight {
            result = "\(formatWeight(weight)) x \(reps)"
        } else {
            result = "\(reps) reps"
        }
        if let rpe = rpe {
            result += " @ RPE \(rpe)"
        }
        return result
    }

    var formattedBand: String? {
        guard let band = bandColor, !band.isEmpty, let reps = reps else { return nil }
        var result = "\(band) band x \(reps)"
        if let rpe = rpe {
            result += " @ RPE \(rpe)"
        }
        return result
    }

    var formattedCardio: String? {
        var parts: [String] = []
        if let duration = duration {
            parts.append(formatDuration(duration))
        }
        if let distance = distance {
            parts.append(String(format: "%.2f mi", distance))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    var formattedIsometric: String? {
        guard let holdTime = holdTime else { return nil }
        var result = formatDuration(holdTime) + " hold"
        if let intensity = intensity {
            result += " @ \(intensity)/10"
        }
        return result
    }

    var formattedRecovery: String? {
        guard let duration = duration else { return nil }
        var result = formatDuration(duration)
        if let temp = temperature {
            result += " @ \(temp)°F"
        }
        return result
    }
}

// MARK: - Measurable Value

/// Represents a logged value for an implement measurable
/// Supports both numeric (24.0 for height) and string ("Red" for band color) values
struct MeasurableValue: Codable, Hashable {
    var numericValue: Double?
    var stringValue: String?

    init(numericValue: Double? = nil, stringValue: String? = nil) {
        self.numericValue = numericValue
        self.stringValue = stringValue
    }
}
