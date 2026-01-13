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
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var completedModule: CompletedModuleEntity?
    @NSManaged public var completedSetGroups: NSOrderedSet?

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
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
