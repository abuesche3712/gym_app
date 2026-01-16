//
//  CoreDataEntities.swift
//  gym app
//
//  NSManagedObject subclasses for CoreData entities
//

import CoreData

// MARK: - Module Entity

@objc(ModuleEntity)
public class ModuleEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var typeRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var estimatedDuration: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var exercises: NSOrderedSet?
    @NSManaged public var exerciseInstances: NSOrderedSet?  // New normalized model

    var type: ModuleType {
        get { ModuleType(rawValue: typeRaw) ?? .strength }
        set { typeRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingSync }
        set { syncStatusRaw = newValue.rawValue }
    }

    var exerciseArray: [ExerciseEntity] {
        exercises?.array as? [ExerciseEntity] ?? []
    }

    var exerciseInstanceArray: [ExerciseInstanceEntity] {
        exerciseInstances?.array as? [ExerciseInstanceEntity] ?? []
    }
}

// MARK: - Exercise Entity

@objc(ExerciseEntity)
public class ExerciseEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var trackingMetricsRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var module: ModuleEntity?
    @NSManaged public var setGroups: NSOrderedSet?

    // Library system reference (optional for backward compatibility)
    @NSManaged public var exerciseLibraryId: UUID?
    @NSManaged public var exerciseLibrary: ExerciseLibraryEntity?

    // Library system fields (direct storage for muscle groups and implements)
    @NSManaged public var muscleGroupIdsRaw: String?
    @NSManaged public var implementIdsRaw: String?

    // Additional exercise fields
    @NSManaged public var templateId: UUID?
    @NSManaged public var cardioMetricRaw: String?
    @NSManaged public var distanceUnitRaw: String?

    var cardioMetric: CardioMetric {
        get { CardioMetric(rawValue: cardioMetricRaw ?? "") ?? .timeOnly }
        set { cardioMetricRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw ?? "") ?? .meters }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var muscleGroupIds: Set<UUID> {
        get {
            guard let raw = muscleGroupIdsRaw else { return [] }
            return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            muscleGroupIdsRaw = newValue.isEmpty ? nil : newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var implementIds: Set<UUID> {
        get {
            guard let raw = implementIdsRaw else { return [] }
            return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            implementIdsRaw = newValue.isEmpty ? nil : newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var trackingMetrics: [MetricType] {
        get {
            trackingMetricsRaw.split(separator: ",").compactMap { MetricType(rawValue: String($0)) }
        }
        set {
            trackingMetricsRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    var setGroupArray: [SetGroupEntity] {
        setGroups?.array as? [SetGroupEntity] ?? []
    }

    /// All available measurables from the linked library exercise
    /// Combines intrinsic measurables + all measurables from implements
    var availableMeasurables: [MeasurableEntity] {
        guard let library = exerciseLibrary else { return [] }

        var measurables: [MeasurableEntity] = []

        // Add intrinsic measurables (for cardio exercises)
        measurables.append(contentsOf: library.intrinsicMeasurableArray)

        // Add measurables from all implements
        for implement in library.implementArray {
            measurables.append(contentsOf: implement.measurableArray)
        }

        return measurables
    }

    /// Whether this exercise has a library reference
    var hasLibraryReference: Bool {
        exerciseLibrary != nil || exerciseLibraryId != nil
    }
}

// MARK: - Exercise Instance Entity (New normalized model)

@objc(ExerciseInstanceEntity)
public class ExerciseInstanceEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var templateId: UUID  // Required - links to ExerciseTemplate
    @NSManaged public var supersetGroupIdRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var module: ModuleEntity?
    @NSManaged public var setGroups: NSOrderedSet?

    // Optional overrides (rarely used)
    @NSManaged public var nameOverride: String?
    @NSManaged public var exerciseTypeOverrideRaw: String?

    var supersetGroupId: UUID? {
        get {
            guard let raw = supersetGroupIdRaw else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            supersetGroupIdRaw = newValue?.uuidString
        }
    }

    var exerciseTypeOverride: ExerciseType? {
        get {
            guard let raw = exerciseTypeOverrideRaw else { return nil }
            return ExerciseType(rawValue: raw)
        }
        set {
            exerciseTypeOverrideRaw = newValue?.rawValue
        }
    }

    var setGroupArray: [SetGroupEntity] {
        setGroups?.array as? [SetGroupEntity] ?? []
    }

    var isInSuperset: Bool {
        supersetGroupId != nil
    }
}

// MARK: - SetGroup Entity

@objc(SetGroupEntity)
public class SetGroupEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var sets: Int32
    @NSManaged public var restPeriod: Int32
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var exercise: ExerciseEntity?
    @NSManaged public var exerciseInstance: ExerciseInstanceEntity?  // New normalized model

    // Interval mode fields
    @NSManaged public var isInterval: Bool
    @NSManaged public var workDuration: Int32
    @NSManaged public var intervalRestDuration: Int32

    // Dynamic measurable targets (new system)
    @NSManaged public var targetValues: NSSet?

    // DEPRECATED: Flat fields kept for backward compatibility with existing workouts
    // New workouts should use targetValues instead
    @NSManaged public var targetReps: Int32
    @NSManaged public var targetWeight: Double
    @NSManaged public var targetRPE: Int32
    @NSManaged public var targetDuration: Int32
    @NSManaged public var targetDistance: Double
    @NSManaged public var targetHoldTime: Int32

    // Implement-specific measurable fields
    @NSManaged public var implementMeasurableLabel: String?
    @NSManaged public var implementMeasurableUnit: String?
    @NSManaged public var implementMeasurableValue: Double
    @NSManaged public var implementMeasurableStringValue: String?

    var targetValueArray: [TargetValueEntity] {
        targetValues?.allObjects as? [TargetValueEntity] ?? []
    }

    /// Get target value for a specific measurable by name
    func targetValue(for measurableName: String) -> Double? {
        targetValueArray.first { $0.measurableName == measurableName }?.targetValue
    }

    /// Check if this set group uses the dynamic measurable system
    var usesDynamicMeasurables: Bool {
        !targetValueArray.isEmpty
    }
}

// MARK: - Target Value Entity (Dynamic Measurable Targets)

@objc(TargetValueEntity)
public class TargetValueEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var measurableName: String  // Matches MeasurableEntity.name
    @NSManaged public var measurableUnit: String  // Copied from MeasurableEntity.unit for display
    @NSManaged public var targetValue: Double     // For numeric measurables
    @NSManaged public var stringValue: String?    // For text-based measurables (e.g., band color)
    @NSManaged public var setGroup: SetGroupEntity?

    /// Whether this target uses string value (for text-based measurables like band color)
    var isStringBased: Bool {
        stringValue != nil
    }

    /// Display value - returns string value if present, otherwise formatted numeric value
    var displayValue: String {
        if let str = stringValue {
            return str
        }
        return "\(targetValue) \(measurableUnit)"
    }
}

// MARK: - Workout Entity

@objc(WorkoutEntity)
public class WorkoutEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var estimatedDuration: Int32
    @NSManaged public var notes: String?
    @NSManaged public var archived: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var moduleReferences: NSOrderedSet?

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingSync }
        set { syncStatusRaw = newValue.rawValue }
    }

    var moduleReferenceArray: [ModuleReferenceEntity] {
        moduleReferences?.array as? [ModuleReferenceEntity] ?? []
    }
}

// MARK: - Module Reference Entity

@objc(ModuleReferenceEntity)
public class ModuleReferenceEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var moduleId: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var isRequired: Bool
    @NSManaged public var notes: String?
    @NSManaged public var workout: WorkoutEntity?
}

// MARK: - Session Entity

@objc(SessionEntity)
public class SessionEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var workoutId: UUID
    @NSManaged public var workoutName: String
    @NSManaged public var date: Date
    @NSManaged public var skippedModuleIdsRaw: String?
    @NSManaged public var duration: Int32
    @NSManaged public var overallFeeling: Int32
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var completedModules: NSOrderedSet?

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingSync }
        set { syncStatusRaw = newValue.rawValue }
    }

    var skippedModuleIds: [UUID] {
        get {
            guard let raw = skippedModuleIdsRaw else { return [] }
            return raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        }
        set {
            skippedModuleIdsRaw = newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var completedModuleArray: [CompletedModuleEntity] {
        completedModules?.array as? [CompletedModuleEntity] ?? []
    }
}

// MARK: - Completed Module Entity

@objc(CompletedModuleEntity)
public class CompletedModuleEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var moduleId: UUID
    @NSManaged public var moduleName: String
    @NSManaged public var moduleTypeRaw: String
    @NSManaged public var skipped: Bool
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var session: SessionEntity?
    @NSManaged public var completedExercises: NSOrderedSet?

    var moduleType: ModuleType {
        get { ModuleType(rawValue: moduleTypeRaw) ?? .strength }
        set { moduleTypeRaw = newValue.rawValue }
    }

    var completedExerciseArray: [SessionExerciseEntity] {
        completedExercises?.array as? [SessionExerciseEntity] ?? []
    }
}

// MARK: - Session Exercise Entity

@objc(SessionExerciseEntity)
public class SessionExerciseEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var exerciseId: UUID
    @NSManaged public var exerciseName: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var cardioMetricRaw: String?
    @NSManaged public var distanceUnitRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var completedModule: CompletedModuleEntity?
    @NSManaged public var completedSetGroups: NSOrderedSet?
    @NSManaged public var progressionRecommendationRaw: String?
    @NSManaged public var mobilityTrackingRaw: String?
    @NSManaged public var isBodyweight: Bool
    @NSManaged public var supersetGroupIdRaw: String?

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var cardioMetric: CardioMetric {
        get { CardioMetric(rawValue: cardioMetricRaw ?? "time") ?? .timeOnly }
        set { cardioMetricRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw ?? "meters") ?? .meters }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var progressionRecommendation: ProgressionRecommendation? {
        get { progressionRecommendationRaw.flatMap { ProgressionRecommendation(rawValue: $0) } }
        set { progressionRecommendationRaw = newValue?.rawValue }
    }

    var mobilityTracking: MobilityTracking {
        get { MobilityTracking(rawValue: mobilityTrackingRaw ?? "reps") ?? .repsOnly }
        set { mobilityTrackingRaw = newValue.rawValue }
    }

    var supersetGroupId: UUID? {
        get { supersetGroupIdRaw.flatMap { UUID(uuidString: $0) } }
        set { supersetGroupIdRaw = newValue?.uuidString }
    }

    var completedSetGroupArray: [CompletedSetGroupEntity] {
        completedSetGroups?.array as? [CompletedSetGroupEntity] ?? []
    }
}

// MARK: - Completed Set Group Entity

@objc(CompletedSetGroupEntity)
public class CompletedSetGroupEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var setGroupId: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var sessionExercise: SessionExerciseEntity?
    @NSManaged public var sets: NSOrderedSet?

    // Interval mode fields
    @NSManaged public var isInterval: Bool
    @NSManaged public var workDuration: Int32
    @NSManaged public var intervalRestDuration: Int32
    @NSManaged public var restPeriod: Int32

    var setArray: [SetDataEntity] {
        sets?.array as? [SetDataEntity] ?? []
    }
}

// MARK: - Set Data Entity

@objc(SetDataEntity)
public class SetDataEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var setNumber: Int32
    @NSManaged public var completed: Bool
    @NSManaged public var restAfter: Int32
    @NSManaged public var completedSetGroup: CompletedSetGroupEntity?

    // Dynamic measurable actuals (new system)
    @NSManaged public var actualValues: NSSet?

    // DEPRECATED: Flat fields kept for backward compatibility with existing workouts
    // New workouts should use actualValues instead
    @NSManaged public var weight: Double
    @NSManaged public var reps: Int32
    @NSManaged public var rpe: Int32
    @NSManaged public var duration: Int32
    @NSManaged public var distance: Double
    @NSManaged public var pace: Double
    @NSManaged public var avgHeartRate: Int32
    @NSManaged public var holdTime: Int32
    @NSManaged public var intensity: Int32
    @NSManaged public var height: Double
    @NSManaged public var quality: Int32

    var actualValueArray: [ActualValueEntity] {
        actualValues?.allObjects as? [ActualValueEntity] ?? []
    }

    /// Get actual value for a specific measurable by name
    func actualValue(for measurableName: String) -> Double? {
        actualValueArray.first { $0.measurableName == measurableName }?.actualValue
    }

    /// Check if this set data uses the dynamic measurable system
    var usesDynamicMeasurables: Bool {
        !actualValueArray.isEmpty
    }
}

// MARK: - Actual Value Entity (Dynamic Measurable Actuals)

@objc(ActualValueEntity)
public class ActualValueEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var measurableName: String  // Matches MeasurableEntity.name
    @NSManaged public var measurableUnit: String  // Copied from MeasurableEntity.unit for display
    @NSManaged public var actualValue: Double     // For numeric measurables
    @NSManaged public var stringValue: String?    // For text-based measurables (e.g., band color)
    @NSManaged public var setData: SetDataEntity?

    /// Whether this actual uses string value (for text-based measurables like band color)
    var isStringBased: Bool {
        stringValue != nil
    }

    /// Display value - returns string value if present, otherwise formatted numeric value
    var displayValue: String {
        if let str = stringValue {
            return str
        }
        return "\(actualValue) \(measurableUnit)"
    }
}

// MARK: - Sync Queue Entity

@objc(SyncQueueEntity)
public class SyncQueueEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var operationRaw: String
    @NSManaged public var entityTypeRaw: String
    @NSManaged public var entityId: UUID
    @NSManaged public var payload: Data
    @NSManaged public var attempts: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var lastAttemptAt: Date?

    var operation: SyncOperation {
        get { SyncOperation(rawValue: operationRaw) ?? .create }
        set { operationRaw = newValue.rawValue }
    }
}

// MARK: - Custom Exercise Template Entity (Enhanced for normalized model)

@objc(CustomExerciseTemplateEntity)
public class CustomExerciseTemplateEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var primaryMusclesRaw: String?
    @NSManaged public var secondaryMusclesRaw: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

    // Library system fields
    @NSManaged public var muscleGroupIdsRaw: String?
    @NSManaged public var implementIdsRaw: String?

    // Tracking configuration
    @NSManaged public var cardioMetricRaw: String?
    @NSManaged public var mobilityTrackingRaw: String?
    @NSManaged public var distanceUnitRaw: String?

    // Physical attributes
    @NSManaged public var isBodyweight: Bool
    @NSManaged public var recoveryActivityTypeRaw: String?

    // Defaults for new instances
    @NSManaged public var defaultSetGroupsData: Data?  // Serialized [SetGroup]
    @NSManaged public var defaultNotes: String?

    // Library management
    @NSManaged public var isArchived: Bool
    @NSManaged public var isCustom: Bool

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .fullBody }
        set { categoryRaw = newValue.rawValue }
    }

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var cardioMetric: CardioMetric {
        get { CardioMetric(rawValue: cardioMetricRaw ?? "") ?? .timeOnly }
        set { cardioMetricRaw = newValue.rawValue }
    }

    var mobilityTracking: MobilityTracking {
        get { MobilityTracking(rawValue: mobilityTrackingRaw ?? "") ?? .repsOnly }
        set { mobilityTrackingRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw ?? "") ?? .meters }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var recoveryActivityType: RecoveryActivityType? {
        get {
            guard let raw = recoveryActivityTypeRaw else { return nil }
            return RecoveryActivityType(rawValue: raw)
        }
        set {
            recoveryActivityTypeRaw = newValue?.rawValue
        }
    }

    var primaryMuscles: [MuscleGroup] {
        get {
            guard let raw = primaryMusclesRaw else { return [] }
            return raw.split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) }
        }
        set {
            primaryMusclesRaw = newValue.isEmpty ? nil : newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    var secondaryMuscles: [MuscleGroup] {
        get {
            guard let raw = secondaryMusclesRaw else { return [] }
            return raw.split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) }
        }
        set {
            secondaryMusclesRaw = newValue.isEmpty ? nil : newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    var muscleGroupIds: Set<UUID> {
        get {
            guard let raw = muscleGroupIdsRaw else { return [] }
            return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            muscleGroupIdsRaw = newValue.isEmpty ? nil : newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var implementIds: Set<UUID> {
        get {
            guard let raw = implementIdsRaw else { return [] }
            return Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            implementIdsRaw = newValue.isEmpty ? nil : newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var defaultSetGroups: [SetGroup] {
        get {
            guard let data = defaultSetGroupsData else { return [] }
            return (try? JSONDecoder().decode([SetGroup].self, from: data)) ?? []
        }
        set {
            defaultSetGroupsData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Implement Entity

@objc(ImplementEntity)
public class ImplementEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var isCustom: Bool
    @NSManaged public var measurables: NSSet?
    @NSManaged public var exercises: NSSet?  // Inverse of ExerciseLibraryEntity.implements

    var measurableArray: [MeasurableEntity] {
        measurables?.allObjects as? [MeasurableEntity] ?? []
    }

    var exerciseArray: [ExerciseLibraryEntity] {
        exercises?.allObjects as? [ExerciseLibraryEntity] ?? []
    }
}

// MARK: - Measurable Entity

@objc(MeasurableEntity)
public class MeasurableEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var unit: String
    @NSManaged public var defaultValue: Double
    @NSManaged public var hasDefaultValue: Bool  // Track if defaultValue is set (since Double can't be nil)
    @NSManaged public var isStringBased: Bool    // True for text-based measurables (e.g., band color)
    @NSManaged public var implement: ImplementEntity?  // Optional - nil if intrinsic
    @NSManaged public var exerciseLibrary: ExerciseLibraryEntity?  // Optional - for intrinsic measurables

    var optionalDefaultValue: Double? {
        get { hasDefaultValue ? defaultValue : nil }
        set {
            if let value = newValue {
                defaultValue = value
                hasDefaultValue = true
            } else {
                defaultValue = 0
                hasDefaultValue = false
            }
        }
    }
}

// MARK: - Muscle Group Entity

@objc(MuscleGroupEntity)
public class MuscleGroupEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var exercises: NSSet?

    var exerciseArray: [ExerciseLibraryEntity] {
        exercises?.allObjects as? [ExerciseLibraryEntity] ?? []
    }
}

// MARK: - Exercise Library Entity

@objc(ExerciseLibraryEntity)
public class ExerciseLibraryEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var muscleGroups: NSSet?
    @NSManaged public var intrinsicMeasurables: NSSet?  // For cardio exercises
    @NSManaged public var implements: NSSet?  // Optional
    @NSManaged public var usedByExercises: NSSet?  // Inverse of ExerciseEntity.exerciseLibrary

    var muscleGroupArray: [MuscleGroupEntity] {
        muscleGroups?.allObjects as? [MuscleGroupEntity] ?? []
    }

    var intrinsicMeasurableArray: [MeasurableEntity] {
        intrinsicMeasurables?.allObjects as? [MeasurableEntity] ?? []
    }

    var implementArray: [ImplementEntity] {
        implements?.allObjects as? [ImplementEntity] ?? []
    }

    var usedByExerciseArray: [ExerciseEntity] {
        usedByExercises?.allObjects as? [ExerciseEntity] ?? []
    }

    /// Validation: must have either intrinsicMeasurables or implements
    var isValid: Bool {
        !intrinsicMeasurableArray.isEmpty || !implementArray.isEmpty
    }

    /// All available measurables (intrinsic + from implements)
    var allMeasurables: [MeasurableEntity] {
        var measurables: [MeasurableEntity] = []
        measurables.append(contentsOf: intrinsicMeasurableArray)
        for implement in implementArray {
            measurables.append(contentsOf: implement.measurableArray)
        }
        return measurables
    }
}
