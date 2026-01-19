//
//  CoreDataEntities.swift
//  gym app
//
//  NSManagedObject subclasses for CoreData entities
//

import CoreData
import FirebaseFirestore

// MARK: - Syncable Entity Protocol

/// Protocol for entities that sync to Firebase
/// Provides required timestamp fields for conflict resolution
@objc protocol SyncableEntity: NSObjectProtocol {
    /// When the entity was first created locally (nil for legacy data)
    var createdAt: Date? { get set }
    /// When the entity was last modified locally (auto-updated on save, nil for legacy data)
    var updatedAt: Date? { get set }
    /// When the entity was last successfully synced to cloud (nil if never synced)
    var syncedAt: Date? { get set }
}

/// Extension to auto-update timestamps on save
extension SyncableEntity where Self: NSManagedObject {
    /// Call this in willSave() to auto-update updatedAt timestamp
    func updateTimestampsOnSave() {
        // Only update if there are actual changes (not just relationship updates)
        if hasChanges && !changedValues().isEmpty {
            // Avoid infinite loop by checking if updatedAt is the only change
            let changedKeys = changedValues().keys
            if changedKeys.count == 1 && changedKeys.contains("updatedAt") {
                return
            }

            // Set updatedAt to now
            let now = Date()
            if updatedAt != now {
                setPrimitiveValue(now, forKey: "updatedAt")
            }
        }
    }
}

// MARK: - Module Entity

@objc(ModuleEntity)
public class ModuleEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var typeRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var estimatedDuration: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var exercises: NSOrderedSet?
    @NSManaged public var exerciseInstances: NSOrderedSet?

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class ExerciseEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var trackingMetricsRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
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

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class ExerciseInstanceEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var templateId: UUID?  // Optional - for reference only
    @NSManaged public var supersetGroupIdRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var module: ModuleEntity?
    @NSManaged public var setGroups: NSOrderedSet?

    // Direct exercise data (self-contained, no template lookup needed)
    @NSManaged public var name: String?
    @NSManaged public var exerciseTypeRaw: String?
    @NSManaged public var cardioMetricRaw: String?
    @NSManaged public var distanceUnitRaw: String?
    @NSManaged public var mobilityTrackingRaw: String?
    @NSManaged public var isBodyweight: Bool
    @NSManaged public var recoveryActivityTypeRaw: String?
    @NSManaged public var primaryMusclesData: Data?
    @NSManaged public var secondaryMusclesData: Data?

    // Legacy override fields (kept for migration)
    @NSManaged public var nameOverride: String?
    @NSManaged public var exerciseTypeOverrideRaw: String?
    @NSManaged public var mobilityTrackingOverrideRaw: String?
    @NSManaged public var cardioMetricOverrideRaw: String?
    @NSManaged public var distanceUnitOverrideRaw: String?

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var supersetGroupId: UUID? {
        get {
            guard let raw = supersetGroupIdRaw else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            supersetGroupIdRaw = newValue?.uuidString
        }
    }

    // MARK: - Direct Field Accessors

    var exerciseType: ExerciseType {
        get {
            guard let raw = exerciseTypeRaw else { return .strength }
            return ExerciseType(rawValue: raw) ?? .strength
        }
        set {
            exerciseTypeRaw = newValue.rawValue
        }
    }

    var cardioMetric: CardioTracking {
        get {
            guard let raw = cardioMetricRaw else { return .timeOnly }
            return CardioTracking(rawValue: raw) ?? .timeOnly
        }
        set {
            cardioMetricRaw = newValue.rawValue
        }
    }

    var distanceUnit: DistanceUnit {
        get {
            guard let raw = distanceUnitRaw else { return .meters }
            return DistanceUnit(rawValue: raw) ?? .meters
        }
        set {
            distanceUnitRaw = newValue.rawValue
        }
    }

    var mobilityTracking: MobilityTracking {
        get {
            guard let raw = mobilityTrackingRaw else { return .repsOnly }
            return MobilityTracking(rawValue: raw) ?? .repsOnly
        }
        set {
            mobilityTrackingRaw = newValue.rawValue
        }
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
            guard let data = primaryMusclesData else { return [] }
            return (try? JSONDecoder().decode([MuscleGroup].self, from: data)) ?? []
        }
        set {
            primaryMusclesData = try? JSONEncoder().encode(newValue)
        }
    }

    var secondaryMuscles: [MuscleGroup] {
        get {
            guard let data = secondaryMusclesData else { return [] }
            return (try? JSONDecoder().decode([MuscleGroup].self, from: data)) ?? []
        }
        set {
            secondaryMusclesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Legacy Override Accessors (for migration)

    var exerciseTypeOverride: ExerciseType? {
        get {
            guard let raw = exerciseTypeOverrideRaw else { return nil }
            return ExerciseType(rawValue: raw)
        }
        set {
            exerciseTypeOverrideRaw = newValue?.rawValue
        }
    }

    var mobilityTrackingOverride: MobilityTracking? {
        get {
            guard let raw = mobilityTrackingOverrideRaw else { return nil }
            return MobilityTracking(rawValue: raw)
        }
        set {
            mobilityTrackingOverrideRaw = newValue?.rawValue
        }
    }

    var cardioMetricOverride: CardioMetric? {
        get {
            guard let raw = cardioMetricOverrideRaw else { return nil }
            return CardioMetric(rawValue: raw)
        }
        set {
            cardioMetricOverrideRaw = newValue?.rawValue
        }
    }

    var distanceUnitOverride: DistanceUnit? {
        get {
            guard let raw = distanceUnitOverrideRaw else { return nil }
            return DistanceUnit(rawValue: raw)
        }
        set {
            distanceUnitOverrideRaw = newValue?.rawValue
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
public class SetGroupEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var sets: Int32
    @NSManaged public var restPeriod: Int32
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
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

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class TargetValueEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var measurableName: String  // Matches MeasurableEntity.name
    @NSManaged public var measurableUnit: String  // Copied from MeasurableEntity.unit for display
    @NSManaged public var targetValue: Double     // For numeric measurables
    @NSManaged public var stringValue: String?    // For text-based measurables (e.g., band color)
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var setGroup: SetGroupEntity?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class WorkoutEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var estimatedDuration: Int32
    @NSManaged public var notes: String?
    @NSManaged public var archived: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var moduleReferences: NSOrderedSet?
    @NSManaged public var standaloneExercisesData: Data?  // JSON-encoded [WorkoutExercise]

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingSync }
        set { syncStatusRaw = newValue.rawValue }
    }

    var moduleReferenceArray: [ModuleReferenceEntity] {
        moduleReferences?.array as? [ModuleReferenceEntity] ?? []
    }

    var standaloneExercises: [WorkoutExercise] {
        get {
            guard let data = standaloneExercisesData else { return [] }
            return (try? JSONDecoder().decode([WorkoutExercise].self, from: data)) ?? []
        }
        set {
            standaloneExercisesData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Module Reference Entity

@objc(ModuleReferenceEntity)
public class ModuleReferenceEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var moduleId: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var isRequired: Bool
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var workout: WorkoutEntity?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }
}

// MARK: - Session Entity

@objc(SessionEntity)
public class SessionEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var workoutId: UUID
    @NSManaged public var workoutName: String
    @NSManaged public var date: Date
    @NSManaged public var skippedModuleIdsRaw: String?
    @NSManaged public var duration: Int32
    @NSManaged public var overallFeeling: Int32
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var syncStatusRaw: String?
    @NSManaged public var completedModules: NSOrderedSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw ?? "") ?? .pendingSync }
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
public class CompletedModuleEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var moduleId: UUID
    @NSManaged public var moduleName: String
    @NSManaged public var moduleTypeRaw: String
    @NSManaged public var skipped: Bool
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var session: SessionEntity?
    @NSManaged public var completedExercises: NSOrderedSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class SessionExerciseEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var exerciseId: UUID
    @NSManaged public var exerciseName: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var cardioMetricRaw: String?
    @NSManaged public var distanceUnitRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var completedModule: CompletedModuleEntity?
    @NSManaged public var completedSetGroups: NSOrderedSet?
    @NSManaged public var progressionRecommendationRaw: String?
    @NSManaged public var mobilityTrackingRaw: String?
    @NSManaged public var isBodyweight: Bool
    @NSManaged public var supersetGroupIdRaw: String?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class CompletedSetGroupEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var setGroupId: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var sessionExercise: SessionExerciseEntity?
    @NSManaged public var sets: NSOrderedSet?

    // Interval mode fields
    @NSManaged public var isInterval: Bool
    @NSManaged public var workDuration: Int32
    @NSManaged public var intervalRestDuration: Int32
    @NSManaged public var restPeriod: Int32

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var setArray: [SetDataEntity] {
        sets?.array as? [SetDataEntity] ?? []
    }
}

// MARK: - Set Data Entity

@objc(SetDataEntity)
public class SetDataEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var setNumber: Int32
    @NSManaged public var completed: Bool
    @NSManaged public var restAfter: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
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

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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
public class ActualValueEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var measurableName: String  // Matches MeasurableEntity.name
    @NSManaged public var measurableUnit: String  // Copied from MeasurableEntity.unit for display
    @NSManaged public var actualValue: Double     // For numeric measurables
    @NSManaged public var stringValue: String?    // For text-based measurables (e.g., band color)
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var setData: SetDataEntity?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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

// MARK: - Custom Exercise Template Entity (Enhanced for normalized model)

@objc(CustomExerciseTemplateEntity)
public class CustomExerciseTemplateEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var primaryMusclesRaw: String?
    @NSManaged public var secondaryMusclesRaw: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?

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

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

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

// MARK: - Program Entity

@objc(ProgramEntity)
public class ProgramEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var programDescription: String?
    @NSManaged public var durationWeeks: Int32
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var syncStatusRaw: String
    @NSManaged public var workoutSlots: NSOrderedSet?

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingSync }
        set { syncStatusRaw = newValue.rawValue }
    }

    var workoutSlotArray: [ProgramWorkoutSlotEntity] {
        workoutSlots?.array as? [ProgramWorkoutSlotEntity] ?? []
    }
}

// MARK: - Program Workout Slot Entity

@objc(ProgramWorkoutSlotEntity)
public class ProgramWorkoutSlotEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var workoutId: UUID
    @NSManaged public var workoutName: String
    @NSManaged public var scheduleTypeRaw: String
    @NSManaged public var dayOfWeek: Int32
    @NSManaged public var weekNumber: Int32
    @NSManaged public var specificDateOffset: Int32
    @NSManaged public var orderIndex: Int32
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?
    @NSManaged public var program: ProgramEntity?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var scheduleType: SlotScheduleType {
        get { SlotScheduleType(rawValue: scheduleTypeRaw) ?? .weekly }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    var optionalDayOfWeek: Int? {
        get { dayOfWeek >= 0 ? Int(dayOfWeek) : nil }
        set { dayOfWeek = Int32(newValue ?? -1) }
    }

    var optionalWeekNumber: Int? {
        get { weekNumber > 0 ? Int(weekNumber) : nil }
        set { weekNumber = Int32(newValue ?? 0) }
    }

    var optionalSpecificDateOffset: Int? {
        get { specificDateOffset >= 0 ? Int(specificDateOffset) : nil }
        set { specificDateOffset = Int32(newValue ?? -1) }
    }
}

// MARK: - Progression Scheme Entity (Library Cache)

@objc(ProgressionSchemeEntity)
public class ProgressionSchemeEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var typeRaw: String  // linear, percentage, double_progression
    @NSManaged public var parametersData: Data?  // JSON encoded dictionary
    @NSManaged public var isDefault: Bool  // True for prebaked schemes
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncedAt: Date?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: "createdAt")
        setPrimitiveValue(now, forKey: "updatedAt")
    }

    public override func willSave() {
        super.willSave()
        updateTimestampsOnSave()
    }

    var schemeType: ProgressionSchemeType {
        get { ProgressionSchemeType(rawValue: typeRaw) ?? .linear }
        set { typeRaw = newValue.rawValue }
    }

    var parameters: [String: Any]? {
        get {
            guard let data = parametersData else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        set {
            guard let dict = newValue else {
                parametersData = nil
                return
            }
            parametersData = try? JSONSerialization.data(withJSONObject: dict)
        }
    }
}

enum ProgressionSchemeType: String, Codable {
    case linear
    case percentage
    case doubleProgression = "double_progression"
}

// MARK: - Sync Queue Entity

@objc(SyncQueueEntity)
public class SyncQueueEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var entityTypeRaw: String
    @NSManaged public var entityId: UUID
    @NSManaged public var actionRaw: String
    @NSManaged public var payload: Data
    @NSManaged public var createdAt: Date
    @NSManaged public var retryCount: Int32
    @NSManaged public var lastAttemptAt: Date?
    @NSManaged public var lastError: String?

    var entityType: SyncEntityType {
        get { SyncEntityType(rawValue: entityTypeRaw) ?? .session }
        set { entityTypeRaw = newValue.rawValue }
    }

    var action: SyncAction {
        get { SyncAction(rawValue: actionRaw) ?? .update }
        set { actionRaw = newValue.rawValue }
    }

    /// Whether this item has exceeded retry limit
    var needsManualIntervention: Bool {
        retryCount >= SyncQueueItem.maxRetries
    }

    /// Convert to model object
    func toModel() -> SyncQueueItem {
        SyncQueueItem(
            id: id,
            entityType: entityType,
            entityId: entityId,
            action: action,
            payload: payload,
            createdAt: createdAt,
            retryCount: Int(retryCount),
            lastAttemptAt: lastAttemptAt,
            lastError: lastError
        )
    }
}

// MARK: - Sync Log Entity

/// Persistent log entry for sync operations, useful for TestFlight debugging
@objc(SyncLogEntity)
public class SyncLogEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var context: String
    @NSManaged public var message: String
    @NSManaged public var severityRaw: String

    var severity: SyncLogSeverity {
        get { SyncLogSeverity(rawValue: severityRaw) ?? .info }
        set { severityRaw = newValue.rawValue }
    }

    /// Convert to model object
    func toModel() -> SyncLogEntry {
        SyncLogEntry(
            id: id,
            timestamp: timestamp,
            context: context,
            message: message,
            severity: severity
        )
    }
}

/// Severity levels for sync logs
enum SyncLogSeverity: String, Codable, CaseIterable {
    case info
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .info: return "textSecondary"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
}

/// Model representation of a sync log entry
struct SyncLogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let context: String
    let message: String
    let severity: SyncLogSeverity

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Deletion Record Entity

/// Tracks deleted entities for cross-device sync
@objc(DeletionRecordEntity)
public class DeletionRecordEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var entityTypeRaw: String
    @NSManaged public var entityId: UUID
    @NSManaged public var deletedAt: Date
    @NSManaged public var syncedAt: Date?

    var entityType: DeletionEntityType {
        get { DeletionEntityType(rawValue: entityTypeRaw) ?? .module }
        set { entityTypeRaw = newValue.rawValue }
    }

    /// Convert to model object
    func toModel() -> DeletionRecord {
        DeletionRecord(
            id: id,
            entityType: entityType,
            entityId: entityId,
            deletedAt: deletedAt,
            syncedAt: syncedAt
        )
    }
}

/// Entity types that can be deleted and tracked
enum DeletionEntityType: String, Codable, CaseIterable {
    case module
    case workout
    case program
    case session
    case scheduledWorkout
    case customExercise

    /// Maps to the Firebase collection name for the entity
    var collectionName: String {
        switch self {
        case .module: return "modules"
        case .workout: return "workouts"
        case .program: return "programs"
        case .session: return "sessions"
        case .scheduledWorkout: return "scheduledWorkouts"
        case .customExercise: return "customExercises"
        }
    }
}

// MARK: - In-Progress Session Entity

/// Stores a JSON-encoded Session for crash recovery
@objc(InProgressSessionEntity)
public class InProgressSessionEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var sessionData: Data?
    @NSManaged public var lastUpdated: Date
    @NSManaged public var workoutId: UUID
    @NSManaged public var workoutName: String?
    @NSManaged public var startTime: Date?

    /// Decode the stored session data back to a Session model
    func toSession() -> Session? {
        guard let data = sessionData else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    /// Update the entity from a Session model
    func update(from session: Session) {
        self.sessionData = try? JSONEncoder().encode(session)
        self.lastUpdated = Date()
        self.workoutId = session.workoutId
        self.workoutName = session.workoutName
        self.startTime = session.date
    }
}

/// Model representation of a deletion record
struct DeletionRecord: Identifiable, Codable {
    let id: UUID
    let entityType: DeletionEntityType
    let entityId: UUID
    let deletedAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        entityType: DeletionEntityType,
        entityId: UUID,
        deletedAt: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
    }

    /// For Firebase encoding
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "entityType": entityType.rawValue,
            "entityId": entityId.uuidString,
            "deletedAt": deletedAt
        ]
        if let syncedAt = syncedAt {
            data["syncedAt"] = syncedAt
        }
        return data
    }

    /// Initialize from Firebase data
    init?(from data: [String: Any]) {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let entityTypeRaw = data["entityType"] as? String,
              let entityType = DeletionEntityType(rawValue: entityTypeRaw),
              let entityIdString = data["entityId"] as? String,
              let entityId = UUID(uuidString: entityIdString),
              let deletedAt = data["deletedAt"] as? Date ?? (data["deletedAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }

        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.deletedAt = deletedAt
        self.syncedAt = data["syncedAt"] as? Date ?? (data["syncedAt"] as? Timestamp)?.dateValue()
    }
}
