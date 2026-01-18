//
//  ExerciseMigrationManager.swift
//  gym app
//
//  Handles migration from the old Exercise model to the normalized
//  ExerciseTemplate + ExerciseInstance pattern.
//

import CoreData
import Foundation

struct ExerciseMigrationManager {
    private let viewContext: NSManagedObjectContext
    private let migrationKey = "ExerciseMigrationCompleted_v1"
    private let repairKey = "ExerciseTemplateIdRepair_v1"

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Migration Check

    /// Returns true if migration has already been completed
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Returns true if repair has already been completed
    var isRepairCompleted: Bool {
        UserDefaults.standard.bool(forKey: repairKey)
    }

    /// Returns true if there are old Exercises that need migration
    func needsMigration() -> Bool {
        // Skip if already migrated
        guard !isMigrationCompleted else { return false }

        // Check if there are any modules with old exercises
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        do {
            let modules = try viewContext.fetch(request)
            // Need migration if any module has old exercises but no exercise instances
            return modules.contains { module in
                !module.exerciseArray.isEmpty && module.exerciseInstanceArray.isEmpty
            }
        } catch {
            Logger.error(error, context: "ExerciseMigrationManager checkMigration")
            return false
        }
    }

    // MARK: - Template ID Repair
    //
    // This repairs ExerciseInstances that have templateIds pointing to OLD random UUIDs
    // from before ExerciseLibrary was fixed to use stable IDs. We match by exercise name
    // and update the templateId to the new stable UUID.

    /// Repairs orphaned ExerciseInstances by remapping templateIds based on name matching
    /// This is a non-critical migration - if it fails, the app should still work
    func repairTemplateIdsIfNeeded() {
        guard !isRepairCompleted else {
            Logger.debug("ExerciseMigrationManager: Template ID repair already completed")
            return
        }

        Logger.info("ExerciseMigrationManager: Starting template ID repair...")

        do {
            try repairAllInstances()
            markRepairComplete()
            Logger.info("ExerciseMigrationManager: Template ID repair completed successfully")
        } catch {
            // Non-critical: mark as complete to avoid repeated failures, log error
            Logger.error(error, context: "ExerciseMigrationManager repairTemplateIds - skipping")
            markRepairComplete()  // Don't retry on next launch
        }
    }

    private func repairAllInstances() throws {
        // Build a lookup map from exercise name -> stable template ID (built-in library only)
        // We only use ExerciseLibrary.shared which is NOT MainActor isolated
        var nameToTemplateId: [String: UUID] = [:]
        let builtInTemplateIds = Set(ExerciseLibrary.shared.exercises.map { $0.id })
        for template in ExerciseLibrary.shared.exercises {
            nameToTemplateId[template.name.lowercased()] = template.id
        }

        let request = NSFetchRequest<ExerciseInstanceEntity>(entityName: "ExerciseInstanceEntity")
        let instances = try viewContext.fetch(request)

        var repairedCount = 0

        for instance in instances {
            // Check if the current templateId exists in the built-in library
            let currentTemplateId = instance.templateId
            let existsInBuiltInLibrary = builtInTemplateIds.contains(currentTemplateId)

            // Ensure nameOverride is set for ALL instances (as a backup)
            if instance.nameOverride == nil, let module = instance.module {
                if let exerciseName = findExerciseNameFromLegacy(instance: instance, in: module) {
                    instance.nameOverride = exerciseName
                    Logger.debug("Set nameOverride backup for '\(exerciseName)'")
                }
            }

            // Only repair templateId if it's NOT in the built-in library
            if !existsInBuiltInLibrary {
                // Try to repair by name matching to built-in library
                if let nameOverride = instance.nameOverride,
                   let newTemplateId = nameToTemplateId[nameOverride.lowercased()] {
                    instance.templateId = newTemplateId
                    repairedCount += 1
                    Logger.debug("Repaired instance '\(nameOverride)' -> stable templateId")
                }
                // For custom exercises not in built-in library, leave templateId as-is
                // but nameOverride is already set above for fallback
            }
        }

        // Always save if we made any changes (including nameOverride backups)
        if viewContext.hasChanges {
            try viewContext.save()
            Logger.info("ExerciseMigrationManager: Repaired \(repairedCount) template IDs, updated instance backups")
        }
    }

    /// Attempts to find the exercise name from legacy data in the module
    private func findExerciseNameFromLegacy(instance: ExerciseInstanceEntity, in module: ModuleEntity) -> String? {
        let legacyExercises = module.exerciseArray

        // First try: match by order index
        let orderIndex = Int(instance.orderIndex)
        if orderIndex >= 0 && orderIndex < legacyExercises.count {
            return legacyExercises[orderIndex].name
        }

        // Second try: match by position in instance array
        let instanceIndex = module.exerciseInstanceArray.firstIndex { $0.id == instance.id } ?? -1
        if instanceIndex >= 0 && instanceIndex < legacyExercises.count {
            return legacyExercises[instanceIndex].name
        }

        // Third try: if only one exercise in both arrays, use it
        if legacyExercises.count == 1 && module.exerciseInstanceArray.count == 1 {
            return legacyExercises[0].name
        }

        return nil
    }

    private func markRepairComplete() {
        UserDefaults.standard.set(true, forKey: repairKey)
    }

    // MARK: - Migration

    /// Migrates all old Exercises to the new ExerciseInstance model
    func migrateIfNeeded() {
        guard needsMigration() else {
            Logger.debug("ExerciseMigrationManager: No migration needed")
            return
        }

        Logger.info("ExerciseMigrationManager: Starting migration...")

        do {
            try migrateAllModules()
            markMigrationComplete()
            Logger.info("ExerciseMigrationManager: Migration completed successfully")
        } catch {
            Logger.error(error, context: "ExerciseMigrationManager migrate")
        }
    }

    private func migrateAllModules() throws {
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        let modules = try viewContext.fetch(request)

        for module in modules {
            migrateModule(module)
        }

        try viewContext.save()
    }

    private func migrateModule(_ module: ModuleEntity) {
        // Skip if already has exercise instances
        guard module.exerciseInstanceArray.isEmpty else { return }

        // Get old exercises
        let oldExercises = module.exerciseArray

        // Build superset group mapping (old ID -> new ID)
        var supersetMapping: [UUID: UUID] = [:]

        // First pass: identify superset groups and create new UUIDs
        for exercise in oldExercises {
            if let oldSupersetId = exercise.templateId, supersetMapping[oldSupersetId] == nil {
                // Note: templateId was being used for superset tracking in the old model
                // Create a new consistent ID for this superset group
                supersetMapping[oldSupersetId] = UUID()
            }
        }

        // Second pass: create exercise instances
        var instanceEntities: [ExerciseInstanceEntity] = []

        for (index, oldExercise) in oldExercises.enumerated() {
            let instance = ExerciseInstanceEntity(context: viewContext)
            instance.id = UUID()
            instance.orderIndex = Int32(index)
            instance.notes = oldExercise.notes
            instance.createdAt = oldExercise.createdAt
            instance.updatedAt = oldExercise.updatedAt
            instance.module = module

            // Find or create template
            let template = findOrCreateTemplate(for: oldExercise)
            instance.templateId = template.id

            // Handle superset group ID (was stored in templateId in old model)
            if let oldSupersetId = oldExercise.templateId,
               let newSupersetId = supersetMapping[oldSupersetId] {
                instance.supersetGroupId = newSupersetId
            }

            // Migrate set groups
            migrateSetGroups(from: oldExercise, to: instance)

            instanceEntities.append(instance)
        }

        // Update module's exercise instances
        let orderedSet = NSOrderedSet(array: instanceEntities)
        module.setValue(orderedSet, forKey: "exerciseInstances")
    }

    private func findOrCreateTemplate(for exercise: ExerciseEntity) -> ExerciseTemplate {
        // Check built-in library first (not MainActor isolated)
        if let existing = ExerciseLibrary.shared.exercises.first(where: {
            $0.name.lowercased() == exercise.name.lowercased() &&
            $0.exerciseType == exercise.exerciseType
        }) {
            return existing
        }

        // Create new template (will be added to custom library on MainActor)
        let newTemplate = ExerciseTemplate(
            id: UUID(),
            name: exercise.name,
            category: categorize(exercise),
            exerciseType: exercise.exerciseType,
            cardioMetric: exercise.cardioMetric,
            mobilityTracking: .repsOnly,
            distanceUnit: exercise.distanceUnit,
            primary: [],
            secondary: [],
            muscleGroupIds: exercise.muscleGroupIds,
            implementIds: exercise.implementIds,
            isBodyweight: false,
            recoveryActivityType: nil,
            defaultSetGroups: [],
            defaultNotes: nil,
            isArchived: false,
            isCustom: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save to custom library on MainActor
        Task { @MainActor in
            CustomExerciseLibrary.shared.addExercise(newTemplate)
        }

        return newTemplate
    }

    private func categorize(_ exercise: ExerciseEntity) -> ExerciseCategory {
        // Try to infer category from exercise type
        switch exercise.exerciseType {
        case .cardio:
            return .fullBody
        case .mobility:
            return .fullBody
        case .recovery:
            return .fullBody
        default:
            return .fullBody
        }
    }

    private func migrateSetGroups(from oldExercise: ExerciseEntity, to newInstance: ExerciseInstanceEntity) {
        let oldSetGroups = oldExercise.setGroupArray

        var newSetGroupEntities: [SetGroupEntity] = []

        for (index, oldSetGroup) in oldSetGroups.enumerated() {
            let newSetGroup = SetGroupEntity(context: viewContext)
            newSetGroup.id = UUID()
            newSetGroup.orderIndex = Int32(index)
            newSetGroup.sets = oldSetGroup.sets
            newSetGroup.restPeriod = oldSetGroup.restPeriod
            newSetGroup.notes = oldSetGroup.notes

            // Copy target values
            newSetGroup.targetReps = oldSetGroup.targetReps
            newSetGroup.targetWeight = oldSetGroup.targetWeight
            newSetGroup.targetRPE = oldSetGroup.targetRPE
            newSetGroup.targetDuration = oldSetGroup.targetDuration
            newSetGroup.targetDistance = oldSetGroup.targetDistance
            newSetGroup.targetHoldTime = oldSetGroup.targetHoldTime

            // Copy interval mode fields
            newSetGroup.isInterval = oldSetGroup.isInterval
            newSetGroup.workDuration = oldSetGroup.workDuration
            newSetGroup.intervalRestDuration = oldSetGroup.intervalRestDuration

            // Copy implement measurable fields
            newSetGroup.implementMeasurableLabel = oldSetGroup.implementMeasurableLabel
            newSetGroup.implementMeasurableUnit = oldSetGroup.implementMeasurableUnit
            newSetGroup.implementMeasurableValue = oldSetGroup.implementMeasurableValue
            newSetGroup.implementMeasurableStringValue = oldSetGroup.implementMeasurableStringValue

            // Set relationship to new instance (not old exercise)
            newSetGroup.exerciseInstance = newInstance

            newSetGroupEntities.append(newSetGroup)
        }

        // Update instance's set groups
        let orderedSet = NSOrderedSet(array: newSetGroupEntities)
        newInstance.setValue(orderedSet, forKey: "setGroups")
    }

    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Reset (for testing)

    /// Resets migration status (for testing purposes)
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }
}
