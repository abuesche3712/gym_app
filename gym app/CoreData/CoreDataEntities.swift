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
}

// MARK: - Exercise Entity

@objc(ExerciseEntity)
public class ExerciseEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var trackingMetricsRaw: String
    @NSManaged public var progressionTypeRaw: String
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var module: ModuleEntity?
    @NSManaged public var setGroups: NSOrderedSet?

    // Library system reference (optional for backward compatibility)
    @NSManaged public var exerciseLibraryId: UUID?
    @NSManaged public var exerciseLibrary: ExerciseLibraryEntity?

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var progressionType: ProgressionType {
        get { ProgressionType(rawValue: progressionTypeRaw) ?? .none }
        set { progressionTypeRaw = newValue.rawValue }
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

// MARK: - SetGroup Entity

@objc(SetGroupEntity)
public class SetGroupEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var sets: Int32
    @NSManaged public var targetReps: Int32
    @NSManaged public var targetWeight: Double
    @NSManaged public var targetRPE: Int32
    @NSManaged public var targetDuration: Int32
    @NSManaged public var targetDistance: Double
    @NSManaged public var targetHoldTime: Int32
    @NSManaged public var restPeriod: Int32
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var exercise: ExerciseEntity?

    // Interval mode fields
    @NSManaged public var isInterval: Bool
    @NSManaged public var workDuration: Int32
    @NSManaged public var intervalRestDuration: Int32
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
    @NSManaged public var weight: Double
    @NSManaged public var reps: Int32
    @NSManaged public var rpe: Int32
    @NSManaged public var completed: Bool
    @NSManaged public var duration: Int32
    @NSManaged public var distance: Double
    @NSManaged public var pace: Double
    @NSManaged public var avgHeartRate: Int32
    @NSManaged public var holdTime: Int32
    @NSManaged public var intensity: Int32
    @NSManaged public var height: Double
    @NSManaged public var quality: Int32
    @NSManaged public var restAfter: Int32
    @NSManaged public var completedSetGroup: CompletedSetGroupEntity?
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

// MARK: - Custom Exercise Template Entity

@objc(CustomExerciseTemplateEntity)
public class CustomExerciseTemplateEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var exerciseTypeRaw: String
    @NSManaged public var primaryMusclesRaw: String?
    @NSManaged public var secondaryMusclesRaw: String?
    @NSManaged public var createdAt: Date

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .fullBody }
        set { categoryRaw = newValue.rawValue }
    }

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
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
}

// MARK: - Implement Entity

@objc(ImplementEntity)
public class ImplementEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
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
