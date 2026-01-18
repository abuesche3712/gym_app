//
//  Session.swift
//  gym app
//
//  A completed workout instance with actual logged data
//

import Foundation

struct Session: Identifiable, Codable, Hashable {
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

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName) ?? "Unknown"
        date = try container.decode(Date.self, forKey: .date)
        completedModules = try container.decodeIfPresent([CompletedModule].self, forKey: .completedModules) ?? []
        skippedModuleIds = try container.decodeIfPresent([UUID].self, forKey: .skippedModuleIds) ?? []
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        overallFeeling = try container.decodeIfPresent(Int.self, forKey: .overallFeeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
    }

    private enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, date, completedModules, skippedModuleIds, duration, overallFeeling, notes, createdAt, syncStatus
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        }
        return "\(duration) min"
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

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        moduleId = try container.decode(UUID.self, forKey: .moduleId)
        moduleName = try container.decodeIfPresent(String.self, forKey: .moduleName) ?? "Unknown"
        moduleType = try container.decodeIfPresent(ModuleType.self, forKey: .moduleType) ?? .strength
        completedExercises = try container.decodeIfPresent([SessionExercise].self, forKey: .completedExercises) ?? []
        skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, moduleId, moduleName, moduleType, completedExercises, skipped, notes
    }
}

// MARK: - Session Exercise

struct SessionExercise: Identifiable, Codable, Hashable {
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
        self.isSubstitution = isSubstitution
        self.originalExerciseName = originalExerciseName
        self.isAdHoc = isAdHoc
        self.progressionRecommendation = progressionRecommendation
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Unknown"
        exerciseType = try container.decodeIfPresent(ExerciseType.self, forKey: .exerciseType) ?? .strength
        cardioMetric = try container.decodeIfPresent(CardioMetric.self, forKey: .cardioMetric) ?? .timeOnly
        mobilityTracking = try container.decodeIfPresent(MobilityTracking.self, forKey: .mobilityTracking) ?? .repsOnly
        distanceUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .meters
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        completedSetGroups = try container.decodeIfPresent([CompletedSetGroup].self, forKey: .completedSetGroups) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isBodyweight = try container.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        recoveryActivityType = try container.decodeIfPresent(RecoveryActivityType.self, forKey: .recoveryActivityType)
        isSubstitution = try container.decodeIfPresent(Bool.self, forKey: .isSubstitution) ?? false
        originalExerciseName = try container.decodeIfPresent(String.self, forKey: .originalExerciseName)
        isAdHoc = try container.decodeIfPresent(Bool.self, forKey: .isAdHoc) ?? false
        progressionRecommendation = try container.decodeIfPresent(ProgressionRecommendation.self, forKey: .progressionRecommendation)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, exerciseType, cardioMetric, mobilityTracking, distanceUnit
        case supersetGroupId, completedSetGroups, notes, isBodyweight, recoveryActivityType
        case isSubstitution, originalExerciseName, isAdHoc, progressionRecommendation
    }

    var isInSuperset: Bool {
        supersetGroupId != nil
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

    init(
        id: UUID = UUID(),
        setGroupId: UUID,
        restPeriod: Int? = nil,
        sets: [SetData] = [],
        isInterval: Bool = false,
        workDuration: Int? = nil,
        intervalRestDuration: Int? = nil
    ) {
        self.id = id
        self.setGroupId = setGroupId
        self.restPeriod = restPeriod
        self.sets = sets
        self.isInterval = isInterval
        self.workDuration = workDuration
        self.intervalRestDuration = intervalRestDuration
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setGroupId = try container.decode(UUID.self, forKey: .setGroupId)
        restPeriod = try container.decodeIfPresent(Int.self, forKey: .restPeriod)
        sets = try container.decodeIfPresent([SetData].self, forKey: .sets) ?? []
        isInterval = try container.decodeIfPresent(Bool.self, forKey: .isInterval) ?? false
        workDuration = try container.decodeIfPresent(Int.self, forKey: .workDuration)
        intervalRestDuration = try container.decodeIfPresent(Int.self, forKey: .intervalRestDuration)
    }

    private enum CodingKeys: String, CodingKey {
        case id, setGroupId, restPeriod, sets, isInterval, workDuration, intervalRestDuration
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

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        rpe: Int? = nil,
        completed: Bool = true,
        duration: Int? = nil,
        distance: Double? = nil,
        pace: Double? = nil,
        avgHeartRate: Int? = nil,
        holdTime: Int? = nil,
        intensity: Int? = nil,
        height: Double? = nil,
        quality: Int? = nil,
        temperature: Int? = nil,
        restAfter: Int? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.completed = completed
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
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setNumber = try container.decodeIfPresent(Int.self, forKey: .setNumber) ?? 1
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true
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
    }

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, weight, reps, rpe, completed, duration, distance, pace, avgHeartRate
        case holdTime, intensity, height, quality, temperature, restAfter
    }

    var formattedStrength: String? {
        guard let weight = weight, let reps = reps else { return nil }
        var result = "\(formatWeight(weight)) x \(reps)"
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
