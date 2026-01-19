//
//  PersistenceController.swift
//  gym app
//
//  CoreData persistence controller
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Add sample data for previews
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "GymApp", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Enable lightweight migration for schema changes (adding optional attributes is supported)
            if let description = container.persistentStoreDescriptions.first {
                description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            }
        }

        container.loadPersistentStores { [container] storeDescription, error in
            if let error = error as NSError? {
                // Log the error - always log CoreData errors even in release
                Logger.error("CoreData store failed to load: \(error.localizedDescription)")

                // Attempt recovery by deleting incompatible store
                if let storeURL = storeDescription.url {
                    Logger.warning("Attempting to delete incompatible store and recreate...")
                    do {
                        try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                        // Delete related files
                        let fileManager = FileManager.default
                        let storePath = storeURL.path
                        for suffix in ["", "-shm", "-wal"] {
                            try? fileManager.removeItem(atPath: storePath + suffix)
                        }

                        // Try loading again
                        try container.persistentStoreCoordinator.addPersistentStore(
                            ofType: NSSQLiteStoreType,
                            configurationName: nil,
                            at: storeURL,
                            options: [
                                NSMigratePersistentStoresAutomaticallyOption: true,
                                NSInferMappingModelAutomaticallyOption: true
                            ]
                        )
                        Logger.info("Store recreated successfully")
                    } catch {
                        Logger.error("Failed to recreate store: \(error.localizedDescription)")
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Seed default data on first launch
        seedDataIfNeeded()
    }

    // MARK: - Model Creation

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create entities
        let moduleEntity = createModuleEntity()
        let exerciseEntity = createExerciseEntity()
        let setGroupEntity = createSetGroupEntity()
        let workoutEntity = createWorkoutEntity()
        let moduleReferenceEntity = createModuleReferenceEntity()
        let sessionEntity = createSessionEntity()
        let completedModuleEntity = createCompletedModuleEntity()
        let sessionExerciseEntity = createSessionExerciseEntity()
        let completedSetGroupEntity = createCompletedSetGroupEntity()
        let setDataEntity = createSetDataEntity()
        let syncQueueEntity = createSyncQueueEntity()
        let customExerciseTemplateEntity = createCustomExerciseTemplateEntity()
        let exerciseInstanceEntity = createExerciseInstanceEntity()

        // Create new library entities
        let implementEntity = createImplementEntity()
        let measurableEntity = createMeasurableEntity()
        let muscleGroupEntity = createMuscleGroupEntity()
        let exerciseLibraryEntity = createExerciseLibraryEntity()

        // Create dynamic measurable entities
        let targetValueEntity = createTargetValueEntity()
        let actualValueEntity = createActualValueEntity()

        // Create program entities
        let programEntity = createProgramEntity()
        let programWorkoutSlotEntity = createProgramWorkoutSlotEntity()

        // Create library cache entities
        let progressionSchemeEntity = createProgressionSchemeEntity()

        // Create sync logging entity
        let syncLogEntity = createSyncLogEntity()

        // Create deletion tracking entity
        let deletionRecordEntity = createDeletionRecordEntity()

        // Set up relationships
        setupRelationships(
            moduleEntity: moduleEntity,
            exerciseEntity: exerciseEntity,
            setGroupEntity: setGroupEntity,
            workoutEntity: workoutEntity,
            moduleReferenceEntity: moduleReferenceEntity,
            sessionEntity: sessionEntity,
            completedModuleEntity: completedModuleEntity,
            sessionExerciseEntity: sessionExerciseEntity,
            completedSetGroupEntity: completedSetGroupEntity,
            setDataEntity: setDataEntity,
            targetValueEntity: targetValueEntity,
            actualValueEntity: actualValueEntity
        )

        // Set up library relationships
        setupLibraryRelationships(
            exerciseEntity: exerciseEntity,
            implementEntity: implementEntity,
            measurableEntity: measurableEntity,
            muscleGroupEntity: muscleGroupEntity,
            exerciseLibraryEntity: exerciseLibraryEntity
        )

        // Set up ExerciseInstance relationships (for normalized model)
        setupExerciseInstanceRelationships(
            moduleEntity: moduleEntity,
            exerciseInstanceEntity: exerciseInstanceEntity,
            setGroupEntity: setGroupEntity
        )

        // Set up Program relationships
        setupProgramRelationships(
            programEntity: programEntity,
            programWorkoutSlotEntity: programWorkoutSlotEntity
        )

        model.entities = [
            moduleEntity, exerciseEntity, setGroupEntity,
            workoutEntity, moduleReferenceEntity,
            sessionEntity, completedModuleEntity, sessionExerciseEntity,
            completedSetGroupEntity, setDataEntity, syncQueueEntity,
            customExerciseTemplateEntity, exerciseInstanceEntity,
            // Library entities
            implementEntity, measurableEntity, muscleGroupEntity, exerciseLibraryEntity,
            // Dynamic measurable entities
            targetValueEntity, actualValueEntity,
            // Program entities
            programEntity, programWorkoutSlotEntity,
            // Library cache entities
            progressionSchemeEntity,
            // Sync logging entity
            syncLogEntity,
            // Deletion tracking entity
            deletionRecordEntity
        ]

        return model
    }

    // MARK: - Entity Definitions

    private static func createModuleEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ModuleEntity"
        entity.managedObjectClassName = "ModuleEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("typeRaw", type: .stringAttributeType),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("estimatedDuration", type: .integer32AttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncStatusRaw", type: .stringAttributeType)
        ]

        return entity
    }

    private static func createExerciseEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ExerciseEntity"
        entity.managedObjectClassName = "ExerciseEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("exerciseTypeRaw", type: .stringAttributeType),
            createAttribute("trackingMetricsRaw", type: .stringAttributeType),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            // Library system reference (optional for backward compatibility)
            createAttribute("exerciseLibraryId", type: .UUIDAttributeType, optional: true),
            // Library system fields (direct storage for muscle groups and implements)
            createAttribute("muscleGroupIdsRaw", type: .stringAttributeType, optional: true),
            createAttribute("implementIdsRaw", type: .stringAttributeType, optional: true),
            // Additional exercise fields
            createAttribute("templateId", type: .UUIDAttributeType, optional: true),
            createAttribute("cardioMetricRaw", type: .stringAttributeType, optional: true),
            createAttribute("distanceUnitRaw", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createSetGroupEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SetGroupEntity"
        entity.managedObjectClassName = "SetGroupEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("sets", type: .integer32AttributeType),
            createAttribute("targetReps", type: .integer32AttributeType, optional: true),
            createAttribute("targetWeight", type: .doubleAttributeType, optional: true),
            createAttribute("targetRPE", type: .integer32AttributeType, optional: true),
            createAttribute("targetDuration", type: .integer32AttributeType, optional: true),
            createAttribute("targetDistance", type: .doubleAttributeType, optional: true),
            createAttribute("targetHoldTime", type: .integer32AttributeType, optional: true),
            createAttribute("restPeriod", type: .integer32AttributeType, optional: true),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            // Interval mode fields
            createAttribute("isInterval", type: .booleanAttributeType, optional: true),
            createAttribute("workDuration", type: .integer32AttributeType, optional: true),
            createAttribute("intervalRestDuration", type: .integer32AttributeType, optional: true),
            // Implement-specific measurable fields
            createAttribute("implementMeasurableLabel", type: .stringAttributeType, optional: true),
            createAttribute("implementMeasurableUnit", type: .stringAttributeType, optional: true),
            createAttribute("implementMeasurableValue", type: .doubleAttributeType, optional: true),
            createAttribute("implementMeasurableStringValue", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createWorkoutEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "WorkoutEntity"
        entity.managedObjectClassName = "WorkoutEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("estimatedDuration", type: .integer32AttributeType, optional: true),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("archived", type: .booleanAttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncStatusRaw", type: .stringAttributeType),
            createAttribute("standaloneExercisesData", type: .binaryDataAttributeType, optional: true)
        ]

        return entity
    }

    private static func createModuleReferenceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ModuleReferenceEntity"
        entity.managedObjectClassName = "ModuleReferenceEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("moduleId", type: .UUIDAttributeType),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("isRequired", type: .booleanAttributeType),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createSessionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SessionEntity"
        entity.managedObjectClassName = "SessionEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("workoutId", type: .UUIDAttributeType),
            createAttribute("workoutName", type: .stringAttributeType),
            createAttribute("date", type: .dateAttributeType),
            createAttribute("skippedModuleIdsRaw", type: .stringAttributeType, optional: true),
            createAttribute("duration", type: .integer32AttributeType, optional: true),
            createAttribute("overallFeeling", type: .integer32AttributeType, optional: true),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncStatusRaw", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createCompletedModuleEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CompletedModuleEntity"
        entity.managedObjectClassName = "CompletedModuleEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("moduleId", type: .UUIDAttributeType),
            createAttribute("moduleName", type: .stringAttributeType),
            createAttribute("moduleTypeRaw", type: .stringAttributeType),
            createAttribute("skipped", type: .booleanAttributeType),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createSessionExerciseEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SessionExerciseEntity"
        entity.managedObjectClassName = "SessionExerciseEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("exerciseId", type: .UUIDAttributeType),
            createAttribute("exerciseName", type: .stringAttributeType),
            createAttribute("exerciseTypeRaw", type: .stringAttributeType),
            createAttribute("cardioMetricRaw", type: .stringAttributeType, optional: true),
            createAttribute("distanceUnitRaw", type: .stringAttributeType, optional: true),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("progressionRecommendationRaw", type: .stringAttributeType, optional: true),
            createAttribute("mobilityTrackingRaw", type: .stringAttributeType, optional: true),
            createAttribute("isBodyweight", type: .booleanAttributeType, optional: true),
            createAttribute("supersetGroupIdRaw", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createCompletedSetGroupEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CompletedSetGroupEntity"
        entity.managedObjectClassName = "CompletedSetGroupEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("setGroupId", type: .UUIDAttributeType),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("restPeriod", type: .integer32AttributeType, optional: true),
            // Interval mode fields
            createAttribute("isInterval", type: .booleanAttributeType, optional: true),
            createAttribute("workDuration", type: .integer32AttributeType, optional: true),
            createAttribute("intervalRestDuration", type: .integer32AttributeType, optional: true)
        ]

        return entity
    }

    private static func createSetDataEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SetDataEntity"
        entity.managedObjectClassName = "SetDataEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("setNumber", type: .integer32AttributeType),
            createAttribute("weight", type: .doubleAttributeType, optional: true),
            createAttribute("reps", type: .integer32AttributeType, optional: true),
            createAttribute("rpe", type: .integer32AttributeType, optional: true),
            createAttribute("completed", type: .booleanAttributeType),
            createAttribute("duration", type: .integer32AttributeType, optional: true),
            createAttribute("distance", type: .doubleAttributeType, optional: true),
            createAttribute("pace", type: .doubleAttributeType, optional: true),
            createAttribute("avgHeartRate", type: .integer32AttributeType, optional: true),
            createAttribute("holdTime", type: .integer32AttributeType, optional: true),
            createAttribute("intensity", type: .integer32AttributeType, optional: true),
            createAttribute("height", type: .doubleAttributeType, optional: true),
            createAttribute("quality", type: .integer32AttributeType, optional: true),
            createAttribute("restAfter", type: .integer32AttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createSyncQueueEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SyncQueueEntity"
        entity.managedObjectClassName = "SyncQueueEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("entityTypeRaw", type: .stringAttributeType),
            createAttribute("entityId", type: .UUIDAttributeType),
            createAttribute("actionRaw", type: .stringAttributeType),
            createAttribute("payload", type: .binaryDataAttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("retryCount", type: .integer32AttributeType, defaultValue: 0),
            createAttribute("lastAttemptAt", type: .dateAttributeType, optional: true),
            createAttribute("lastError", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createCustomExerciseTemplateEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CustomExerciseTemplateEntity"
        entity.managedObjectClassName = "CustomExerciseTemplateEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("categoryRaw", type: .stringAttributeType),
            createAttribute("exerciseTypeRaw", type: .stringAttributeType),
            createAttribute("primaryMusclesRaw", type: .stringAttributeType, optional: true),
            createAttribute("secondaryMusclesRaw", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            // Library system fields
            createAttribute("muscleGroupIdsRaw", type: .stringAttributeType, optional: true),
            createAttribute("implementIdsRaw", type: .stringAttributeType, optional: true),
            // Tracking configuration
            createAttribute("cardioMetricRaw", type: .stringAttributeType, optional: true),
            createAttribute("mobilityTrackingRaw", type: .stringAttributeType, optional: true),
            createAttribute("distanceUnitRaw", type: .stringAttributeType, optional: true),
            // Physical attributes
            createAttribute("isBodyweight", type: .booleanAttributeType, optional: true, defaultValue: false),
            createAttribute("recoveryActivityTypeRaw", type: .stringAttributeType, optional: true),
            // Defaults for new instances
            createAttribute("defaultSetGroupsData", type: .binaryDataAttributeType, optional: true),
            createAttribute("defaultNotes", type: .stringAttributeType, optional: true),
            // Library management
            createAttribute("isArchived", type: .booleanAttributeType, optional: true, defaultValue: false),
            createAttribute("isCustom", type: .booleanAttributeType, optional: true, defaultValue: true)
        ]

        return entity
    }

    private static func createExerciseInstanceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ExerciseInstanceEntity"
        entity.managedObjectClassName = "ExerciseInstanceEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("templateId", type: .UUIDAttributeType),  // Required - links to template
            createAttribute("supersetGroupIdRaw", type: .stringAttributeType, optional: true),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            // Optional overrides (fallbacks when template lookup fails)
            createAttribute("nameOverride", type: .stringAttributeType, optional: true),
            createAttribute("exerciseTypeOverrideRaw", type: .stringAttributeType, optional: true),
            createAttribute("mobilityTrackingOverrideRaw", type: .stringAttributeType, optional: true),
            createAttribute("cardioMetricOverrideRaw", type: .stringAttributeType, optional: true),
            createAttribute("distanceUnitOverrideRaw", type: .stringAttributeType, optional: true)
        ]

        return entity
    }

    private static func createImplementEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ImplementEntity"
        entity.managedObjectClassName = "ImplementEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("isCustom", type: .booleanAttributeType, defaultValue: false)
        ]

        return entity
    }

    private static func createMeasurableEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "MeasurableEntity"
        entity.managedObjectClassName = "MeasurableEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("unit", type: .stringAttributeType),
            createAttribute("defaultValue", type: .doubleAttributeType, optional: true),
            createAttribute("hasDefaultValue", type: .booleanAttributeType, defaultValue: false),
            createAttribute("isStringBased", type: .booleanAttributeType, defaultValue: false)
        ]

        return entity
    }

    private static func createMuscleGroupEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "MuscleGroupEntity"
        entity.managedObjectClassName = "MuscleGroupEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType)
        ]

        return entity
    }

    private static func createExerciseLibraryEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ExerciseLibraryEntity"
        entity.managedObjectClassName = "ExerciseLibraryEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType)
        ]

        return entity
    }

    private static func createTargetValueEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TargetValueEntity"
        entity.managedObjectClassName = "TargetValueEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("measurableName", type: .stringAttributeType),
            createAttribute("measurableUnit", type: .stringAttributeType),
            createAttribute("targetValue", type: .doubleAttributeType),
            createAttribute("stringValue", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createActualValueEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ActualValueEntity"
        entity.managedObjectClassName = "ActualValueEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("measurableName", type: .stringAttributeType),
            createAttribute("measurableUnit", type: .stringAttributeType),
            createAttribute("actualValue", type: .doubleAttributeType),
            createAttribute("stringValue", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createProgramEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ProgramEntity"
        entity.managedObjectClassName = "ProgramEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("programDescription", type: .stringAttributeType, optional: true),
            createAttribute("durationWeeks", type: .integer32AttributeType),
            createAttribute("startDate", type: .dateAttributeType, optional: true),
            createAttribute("endDate", type: .dateAttributeType, optional: true),
            createAttribute("isActive", type: .booleanAttributeType, defaultValue: false),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncStatusRaw", type: .stringAttributeType)
        ]

        return entity
    }

    private static func createProgramWorkoutSlotEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ProgramWorkoutSlotEntity"
        entity.managedObjectClassName = "ProgramWorkoutSlotEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("workoutId", type: .UUIDAttributeType),
            createAttribute("workoutName", type: .stringAttributeType),
            createAttribute("scheduleTypeRaw", type: .stringAttributeType),
            createAttribute("dayOfWeek", type: .integer32AttributeType, optional: true, defaultValue: -1),
            createAttribute("weekNumber", type: .integer32AttributeType, optional: true, defaultValue: 0),
            createAttribute("specificDateOffset", type: .integer32AttributeType, optional: true, defaultValue: -1),
            createAttribute("orderIndex", type: .integer32AttributeType),
            createAttribute("notes", type: .stringAttributeType, optional: true),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createProgressionSchemeEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ProgressionSchemeEntity"
        entity.managedObjectClassName = "ProgressionSchemeEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("name", type: .stringAttributeType),
            createAttribute("typeRaw", type: .stringAttributeType),
            createAttribute("parametersData", type: .binaryDataAttributeType, optional: true),
            createAttribute("isDefault", type: .booleanAttributeType, defaultValue: false),
            createAttribute("createdAt", type: .dateAttributeType, optional: true),
            createAttribute("updatedAt", type: .dateAttributeType, optional: true),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    private static func createSyncLogEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SyncLogEntity"
        entity.managedObjectClassName = "SyncLogEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("timestamp", type: .dateAttributeType),
            createAttribute("context", type: .stringAttributeType),
            createAttribute("message", type: .stringAttributeType),
            createAttribute("severityRaw", type: .stringAttributeType)
        ]

        return entity
    }

    private static func createDeletionRecordEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "DeletionRecordEntity"
        entity.managedObjectClassName = "DeletionRecordEntity"

        entity.properties = [
            createAttribute("id", type: .UUIDAttributeType),
            createAttribute("entityTypeRaw", type: .stringAttributeType),
            createAttribute("entityId", type: .UUIDAttributeType),
            createAttribute("deletedAt", type: .dateAttributeType),
            createAttribute("syncedAt", type: .dateAttributeType, optional: true)
        ]

        return entity
    }

    // MARK: - Relationship Setup

    private static func setupRelationships(
        moduleEntity: NSEntityDescription,
        exerciseEntity: NSEntityDescription,
        setGroupEntity: NSEntityDescription,
        workoutEntity: NSEntityDescription,
        moduleReferenceEntity: NSEntityDescription,
        sessionEntity: NSEntityDescription,
        completedModuleEntity: NSEntityDescription,
        sessionExerciseEntity: NSEntityDescription,
        completedSetGroupEntity: NSEntityDescription,
        setDataEntity: NSEntityDescription,
        targetValueEntity: NSEntityDescription,
        actualValueEntity: NSEntityDescription
    ) {
        // Module <-> Exercise (one-to-many)
        let moduleToExercises = NSRelationshipDescription()
        moduleToExercises.name = "exercises"
        moduleToExercises.destinationEntity = exerciseEntity
        moduleToExercises.isOrdered = true
        moduleToExercises.minCount = 0
        moduleToExercises.maxCount = 0 // unlimited
        moduleToExercises.deleteRule = .cascadeDeleteRule

        let exerciseToModule = NSRelationshipDescription()
        exerciseToModule.name = "module"
        exerciseToModule.destinationEntity = moduleEntity
        exerciseToModule.minCount = 0
        exerciseToModule.maxCount = 1
        exerciseToModule.deleteRule = .nullifyDeleteRule

        moduleToExercises.inverseRelationship = exerciseToModule
        exerciseToModule.inverseRelationship = moduleToExercises

        moduleEntity.properties.append(moduleToExercises)
        exerciseEntity.properties.append(exerciseToModule)

        // Exercise <-> SetGroup (one-to-many)
        let exerciseToSetGroups = NSRelationshipDescription()
        exerciseToSetGroups.name = "setGroups"
        exerciseToSetGroups.destinationEntity = setGroupEntity
        exerciseToSetGroups.isOrdered = true
        exerciseToSetGroups.minCount = 0
        exerciseToSetGroups.maxCount = 0
        exerciseToSetGroups.deleteRule = .cascadeDeleteRule

        let setGroupToExercise = NSRelationshipDescription()
        setGroupToExercise.name = "exercise"
        setGroupToExercise.destinationEntity = exerciseEntity
        setGroupToExercise.minCount = 0
        setGroupToExercise.maxCount = 1
        setGroupToExercise.deleteRule = .nullifyDeleteRule

        exerciseToSetGroups.inverseRelationship = setGroupToExercise
        setGroupToExercise.inverseRelationship = exerciseToSetGroups

        exerciseEntity.properties.append(exerciseToSetGroups)
        setGroupEntity.properties.append(setGroupToExercise)

        // Workout <-> ModuleReference (one-to-many)
        let workoutToModuleRefs = NSRelationshipDescription()
        workoutToModuleRefs.name = "moduleReferences"
        workoutToModuleRefs.destinationEntity = moduleReferenceEntity
        workoutToModuleRefs.isOrdered = true
        workoutToModuleRefs.minCount = 0
        workoutToModuleRefs.maxCount = 0
        workoutToModuleRefs.deleteRule = .cascadeDeleteRule

        let moduleRefToWorkout = NSRelationshipDescription()
        moduleRefToWorkout.name = "workout"
        moduleRefToWorkout.destinationEntity = workoutEntity
        moduleRefToWorkout.minCount = 0
        moduleRefToWorkout.maxCount = 1
        moduleRefToWorkout.deleteRule = .nullifyDeleteRule

        workoutToModuleRefs.inverseRelationship = moduleRefToWorkout
        moduleRefToWorkout.inverseRelationship = workoutToModuleRefs

        workoutEntity.properties.append(workoutToModuleRefs)
        moduleReferenceEntity.properties.append(moduleRefToWorkout)

        // Session <-> CompletedModule (one-to-many)
        let sessionToCompletedModules = NSRelationshipDescription()
        sessionToCompletedModules.name = "completedModules"
        sessionToCompletedModules.destinationEntity = completedModuleEntity
        sessionToCompletedModules.isOrdered = true
        sessionToCompletedModules.minCount = 0
        sessionToCompletedModules.maxCount = 0
        sessionToCompletedModules.deleteRule = .cascadeDeleteRule

        let completedModuleToSession = NSRelationshipDescription()
        completedModuleToSession.name = "session"
        completedModuleToSession.destinationEntity = sessionEntity
        completedModuleToSession.minCount = 0
        completedModuleToSession.maxCount = 1
        completedModuleToSession.deleteRule = .nullifyDeleteRule

        sessionToCompletedModules.inverseRelationship = completedModuleToSession
        completedModuleToSession.inverseRelationship = sessionToCompletedModules

        sessionEntity.properties.append(sessionToCompletedModules)
        completedModuleEntity.properties.append(completedModuleToSession)

        // CompletedModule <-> SessionExercise (one-to-many)
        let completedModuleToExercises = NSRelationshipDescription()
        completedModuleToExercises.name = "completedExercises"
        completedModuleToExercises.destinationEntity = sessionExerciseEntity
        completedModuleToExercises.isOrdered = true
        completedModuleToExercises.minCount = 0
        completedModuleToExercises.maxCount = 0
        completedModuleToExercises.deleteRule = .cascadeDeleteRule

        let sessionExerciseToModule = NSRelationshipDescription()
        sessionExerciseToModule.name = "completedModule"
        sessionExerciseToModule.destinationEntity = completedModuleEntity
        sessionExerciseToModule.minCount = 0
        sessionExerciseToModule.maxCount = 1
        sessionExerciseToModule.deleteRule = .nullifyDeleteRule

        completedModuleToExercises.inverseRelationship = sessionExerciseToModule
        sessionExerciseToModule.inverseRelationship = completedModuleToExercises

        completedModuleEntity.properties.append(completedModuleToExercises)
        sessionExerciseEntity.properties.append(sessionExerciseToModule)

        // SessionExercise <-> CompletedSetGroup (one-to-many)
        let sessionExerciseToSetGroups = NSRelationshipDescription()
        sessionExerciseToSetGroups.name = "completedSetGroups"
        sessionExerciseToSetGroups.destinationEntity = completedSetGroupEntity
        sessionExerciseToSetGroups.isOrdered = true
        sessionExerciseToSetGroups.minCount = 0
        sessionExerciseToSetGroups.maxCount = 0
        sessionExerciseToSetGroups.deleteRule = .cascadeDeleteRule

        let completedSetGroupToExercise = NSRelationshipDescription()
        completedSetGroupToExercise.name = "sessionExercise"
        completedSetGroupToExercise.destinationEntity = sessionExerciseEntity
        completedSetGroupToExercise.minCount = 0
        completedSetGroupToExercise.maxCount = 1
        completedSetGroupToExercise.deleteRule = .nullifyDeleteRule

        sessionExerciseToSetGroups.inverseRelationship = completedSetGroupToExercise
        completedSetGroupToExercise.inverseRelationship = sessionExerciseToSetGroups

        sessionExerciseEntity.properties.append(sessionExerciseToSetGroups)
        completedSetGroupEntity.properties.append(completedSetGroupToExercise)

        // CompletedSetGroup <-> SetData (one-to-many)
        let completedSetGroupToSets = NSRelationshipDescription()
        completedSetGroupToSets.name = "sets"
        completedSetGroupToSets.destinationEntity = setDataEntity
        completedSetGroupToSets.isOrdered = true
        completedSetGroupToSets.minCount = 0
        completedSetGroupToSets.maxCount = 0
        completedSetGroupToSets.deleteRule = .cascadeDeleteRule

        let setDataToSetGroup = NSRelationshipDescription()
        setDataToSetGroup.name = "completedSetGroup"
        setDataToSetGroup.destinationEntity = completedSetGroupEntity
        setDataToSetGroup.minCount = 0
        setDataToSetGroup.maxCount = 1
        setDataToSetGroup.deleteRule = .nullifyDeleteRule

        completedSetGroupToSets.inverseRelationship = setDataToSetGroup
        setDataToSetGroup.inverseRelationship = completedSetGroupToSets

        completedSetGroupEntity.properties.append(completedSetGroupToSets)
        setDataEntity.properties.append(setDataToSetGroup)

        // SetGroup <-> TargetValue (one-to-many, dynamic measurable targets)
        let setGroupToTargetValues = NSRelationshipDescription()
        setGroupToTargetValues.name = "targetValues"
        setGroupToTargetValues.destinationEntity = targetValueEntity
        setGroupToTargetValues.minCount = 0
        setGroupToTargetValues.maxCount = 0
        setGroupToTargetValues.deleteRule = .cascadeDeleteRule

        let targetValueToSetGroup = NSRelationshipDescription()
        targetValueToSetGroup.name = "setGroup"
        targetValueToSetGroup.destinationEntity = setGroupEntity
        targetValueToSetGroup.minCount = 0
        targetValueToSetGroup.maxCount = 1
        targetValueToSetGroup.deleteRule = .nullifyDeleteRule

        setGroupToTargetValues.inverseRelationship = targetValueToSetGroup
        targetValueToSetGroup.inverseRelationship = setGroupToTargetValues

        setGroupEntity.properties.append(setGroupToTargetValues)
        targetValueEntity.properties.append(targetValueToSetGroup)

        // SetData <-> ActualValue (one-to-many, dynamic measurable actuals)
        let setDataToActualValues = NSRelationshipDescription()
        setDataToActualValues.name = "actualValues"
        setDataToActualValues.destinationEntity = actualValueEntity
        setDataToActualValues.minCount = 0
        setDataToActualValues.maxCount = 0
        setDataToActualValues.deleteRule = .cascadeDeleteRule

        let actualValueToSetData = NSRelationshipDescription()
        actualValueToSetData.name = "setData"
        actualValueToSetData.destinationEntity = setDataEntity
        actualValueToSetData.minCount = 0
        actualValueToSetData.maxCount = 1
        actualValueToSetData.deleteRule = .nullifyDeleteRule

        setDataToActualValues.inverseRelationship = actualValueToSetData
        actualValueToSetData.inverseRelationship = setDataToActualValues

        setDataEntity.properties.append(setDataToActualValues)
        actualValueEntity.properties.append(actualValueToSetData)
    }

    // MARK: - Library Relationship Setup

    private static func setupLibraryRelationships(
        exerciseEntity: NSEntityDescription,
        implementEntity: NSEntityDescription,
        measurableEntity: NSEntityDescription,
        muscleGroupEntity: NSEntityDescription,
        exerciseLibraryEntity: NSEntityDescription
    ) {
        // ExerciseEntity <-> ExerciseLibraryEntity (many-to-one, optional)
        let exerciseToLibrary = NSRelationshipDescription()
        exerciseToLibrary.name = "exerciseLibrary"
        exerciseToLibrary.destinationEntity = exerciseLibraryEntity
        exerciseToLibrary.minCount = 0
        exerciseToLibrary.maxCount = 1
        exerciseToLibrary.isOptional = true
        exerciseToLibrary.deleteRule = .nullifyDeleteRule

        let libraryToExercises = NSRelationshipDescription()
        libraryToExercises.name = "usedByExercises"
        libraryToExercises.destinationEntity = exerciseEntity
        libraryToExercises.minCount = 0
        libraryToExercises.maxCount = 0  // unlimited
        libraryToExercises.deleteRule = .nullifyDeleteRule

        exerciseToLibrary.inverseRelationship = libraryToExercises
        libraryToExercises.inverseRelationship = exerciseToLibrary

        exerciseEntity.properties.append(exerciseToLibrary)
        exerciseLibraryEntity.properties.append(libraryToExercises)

        // Implement <-> Measurable (one-to-many)
        let implementToMeasurables = NSRelationshipDescription()
        implementToMeasurables.name = "measurables"
        implementToMeasurables.destinationEntity = measurableEntity
        implementToMeasurables.minCount = 0
        implementToMeasurables.maxCount = 0  // unlimited
        implementToMeasurables.deleteRule = .cascadeDeleteRule

        let measurableToImplement = NSRelationshipDescription()
        measurableToImplement.name = "implement"
        measurableToImplement.destinationEntity = implementEntity
        measurableToImplement.minCount = 0
        measurableToImplement.maxCount = 1
        measurableToImplement.isOptional = true
        measurableToImplement.deleteRule = .nullifyDeleteRule

        implementToMeasurables.inverseRelationship = measurableToImplement
        measurableToImplement.inverseRelationship = implementToMeasurables

        implementEntity.properties.append(implementToMeasurables)
        measurableEntity.properties.append(measurableToImplement)

        // MuscleGroup <-> ExerciseLibrary (many-to-many)
        let muscleGroupToExercises = NSRelationshipDescription()
        muscleGroupToExercises.name = "exercises"
        muscleGroupToExercises.destinationEntity = exerciseLibraryEntity
        muscleGroupToExercises.minCount = 0
        muscleGroupToExercises.maxCount = 0
        muscleGroupToExercises.deleteRule = .nullifyDeleteRule

        let exerciseToMuscleGroups = NSRelationshipDescription()
        exerciseToMuscleGroups.name = "muscleGroups"
        exerciseToMuscleGroups.destinationEntity = muscleGroupEntity
        exerciseToMuscleGroups.minCount = 0
        exerciseToMuscleGroups.maxCount = 0
        exerciseToMuscleGroups.deleteRule = .nullifyDeleteRule

        muscleGroupToExercises.inverseRelationship = exerciseToMuscleGroups
        exerciseToMuscleGroups.inverseRelationship = muscleGroupToExercises

        muscleGroupEntity.properties.append(muscleGroupToExercises)
        exerciseLibraryEntity.properties.append(exerciseToMuscleGroups)

        // ExerciseLibrary <-> Measurable (one-to-many for intrinsicMeasurables)
        let exerciseToIntrinsicMeasurables = NSRelationshipDescription()
        exerciseToIntrinsicMeasurables.name = "intrinsicMeasurables"
        exerciseToIntrinsicMeasurables.destinationEntity = measurableEntity
        exerciseToIntrinsicMeasurables.minCount = 0
        exerciseToIntrinsicMeasurables.maxCount = 0
        exerciseToIntrinsicMeasurables.deleteRule = .cascadeDeleteRule

        let measurableToExerciseLibrary = NSRelationshipDescription()
        measurableToExerciseLibrary.name = "exerciseLibrary"
        measurableToExerciseLibrary.destinationEntity = exerciseLibraryEntity
        measurableToExerciseLibrary.minCount = 0
        measurableToExerciseLibrary.maxCount = 1
        measurableToExerciseLibrary.isOptional = true
        measurableToExerciseLibrary.deleteRule = .nullifyDeleteRule

        exerciseToIntrinsicMeasurables.inverseRelationship = measurableToExerciseLibrary
        measurableToExerciseLibrary.inverseRelationship = exerciseToIntrinsicMeasurables

        exerciseLibraryEntity.properties.append(exerciseToIntrinsicMeasurables)
        measurableEntity.properties.append(measurableToExerciseLibrary)

        // ExerciseLibrary <-> Implement (many-to-many)
        let exerciseToImplements = NSRelationshipDescription()
        exerciseToImplements.name = "implements"
        exerciseToImplements.destinationEntity = implementEntity
        exerciseToImplements.minCount = 0
        exerciseToImplements.maxCount = 0
        exerciseToImplements.deleteRule = .nullifyDeleteRule

        let implementToExercises = NSRelationshipDescription()
        implementToExercises.name = "exercises"
        implementToExercises.destinationEntity = exerciseLibraryEntity
        implementToExercises.minCount = 0
        implementToExercises.maxCount = 0
        implementToExercises.deleteRule = .nullifyDeleteRule

        exerciseToImplements.inverseRelationship = implementToExercises
        implementToExercises.inverseRelationship = exerciseToImplements

        exerciseLibraryEntity.properties.append(exerciseToImplements)
        implementEntity.properties.append(implementToExercises)
    }

    // MARK: - ExerciseInstance Relationship Setup

    private static func setupExerciseInstanceRelationships(
        moduleEntity: NSEntityDescription,
        exerciseInstanceEntity: NSEntityDescription,
        setGroupEntity: NSEntityDescription
    ) {
        // Module <-> ExerciseInstance (one-to-many)
        let moduleToExerciseInstances = NSRelationshipDescription()
        moduleToExerciseInstances.name = "exerciseInstances"
        moduleToExerciseInstances.destinationEntity = exerciseInstanceEntity
        moduleToExerciseInstances.isOrdered = true
        moduleToExerciseInstances.minCount = 0
        moduleToExerciseInstances.maxCount = 0  // unlimited
        moduleToExerciseInstances.deleteRule = .cascadeDeleteRule

        let exerciseInstanceToModule = NSRelationshipDescription()
        exerciseInstanceToModule.name = "module"
        exerciseInstanceToModule.destinationEntity = moduleEntity
        exerciseInstanceToModule.minCount = 0
        exerciseInstanceToModule.maxCount = 1
        exerciseInstanceToModule.deleteRule = .nullifyDeleteRule

        moduleToExerciseInstances.inverseRelationship = exerciseInstanceToModule
        exerciseInstanceToModule.inverseRelationship = moduleToExerciseInstances

        moduleEntity.properties.append(moduleToExerciseInstances)
        exerciseInstanceEntity.properties.append(exerciseInstanceToModule)

        // ExerciseInstance <-> SetGroup (one-to-many)
        // Note: SetGroups can belong to either Exercise OR ExerciseInstance (not both)
        // This allows both systems to coexist during migration
        let exerciseInstanceToSetGroups = NSRelationshipDescription()
        exerciseInstanceToSetGroups.name = "setGroups"
        exerciseInstanceToSetGroups.destinationEntity = setGroupEntity
        exerciseInstanceToSetGroups.isOrdered = true
        exerciseInstanceToSetGroups.minCount = 0
        exerciseInstanceToSetGroups.maxCount = 0  // unlimited
        exerciseInstanceToSetGroups.deleteRule = .cascadeDeleteRule

        let setGroupToExerciseInstance = NSRelationshipDescription()
        setGroupToExerciseInstance.name = "exerciseInstance"
        setGroupToExerciseInstance.destinationEntity = exerciseInstanceEntity
        setGroupToExerciseInstance.minCount = 0
        setGroupToExerciseInstance.maxCount = 1
        setGroupToExerciseInstance.isOptional = true
        setGroupToExerciseInstance.deleteRule = .nullifyDeleteRule

        exerciseInstanceToSetGroups.inverseRelationship = setGroupToExerciseInstance
        setGroupToExerciseInstance.inverseRelationship = exerciseInstanceToSetGroups

        exerciseInstanceEntity.properties.append(exerciseInstanceToSetGroups)
        setGroupEntity.properties.append(setGroupToExerciseInstance)
    }

    // MARK: - Program Relationship Setup

    private static func setupProgramRelationships(
        programEntity: NSEntityDescription,
        programWorkoutSlotEntity: NSEntityDescription
    ) {
        // Program <-> ProgramWorkoutSlot (one-to-many)
        let programToSlots = NSRelationshipDescription()
        programToSlots.name = "workoutSlots"
        programToSlots.destinationEntity = programWorkoutSlotEntity
        programToSlots.isOrdered = true
        programToSlots.minCount = 0
        programToSlots.maxCount = 0  // unlimited
        programToSlots.deleteRule = .cascadeDeleteRule

        let slotToProgram = NSRelationshipDescription()
        slotToProgram.name = "program"
        slotToProgram.destinationEntity = programEntity
        slotToProgram.minCount = 0
        slotToProgram.maxCount = 1
        slotToProgram.deleteRule = .nullifyDeleteRule

        programToSlots.inverseRelationship = slotToProgram
        slotToProgram.inverseRelationship = programToSlots

        programEntity.properties.append(programToSlots)
        programWorkoutSlotEntity.properties.append(slotToProgram)
    }

    // MARK: - Helper Functions

    private static func createAttribute(
        _ name: String,
        type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        if let defaultValue = defaultValue {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }

    // MARK: - Save Context

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Logger.error(error, context: "CoreData save")
            }
        }
    }

    // MARK: - Data Seeding

    func seedDataIfNeeded() {
        let seeder = DataSeeder(context: container.viewContext)
        seeder.seedIfNeeded()
    }
}
