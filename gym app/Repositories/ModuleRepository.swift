//
//  ModuleRepository.swift
//  gym app
//
//  Handles Module CRUD operations and CoreData conversion
//

import CoreData

@MainActor
class ModuleRepository {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - CRUD Operations

    func loadAll() -> [Module] {
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ModuleEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { convertToModule($0) }
        } catch {
            Logger.error(error, context: "ModuleRepository.loadAll")
            return []
        }
    }

    func save(_ module: Module) {
        let entity = findOrCreateEntity(id: module.id)
        updateEntity(entity, from: module)
        persistence.save()
    }

    func delete(_ module: Module) {
        if let entity = findEntity(id: module.id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    func find(id: UUID) -> Module? {
        guard let entity = findEntity(id: id) else { return nil }
        return convertToModule(entity)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> ModuleEntity? {
        let request = NSFetchRequest<ModuleEntity>(entityName: "ModuleEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    func deleteEntity(id: UUID) {
        if let entity = findEntity(id: id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateEntity(id: UUID) -> ModuleEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = ModuleEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateEntity(_ entity: ModuleEntity, from module: Module) {
        entity.name = module.name
        entity.type = module.type
        entity.notes = module.notes
        entity.estimatedDuration = Int32(module.estimatedDuration ?? 0)
        entity.createdAt = module.createdAt
        entity.updatedAt = module.updatedAt
        entity.syncStatus = module.syncStatus

        // Clear existing legacy exercises (no longer used)
        if let existingExercises = entity.exercises {
            for case let exercise as ExerciseEntity in existingExercises {
                viewContext.delete(exercise)
            }
        }
        entity.exercises = nil

        // Clear existing exercise instances
        if let existingInstances = entity.exerciseInstances {
            for case let instance as ExerciseInstanceEntity in existingInstances {
                viewContext.delete(instance)
            }
        }

        // Add exercise instances
        let instanceEntities = createExerciseInstanceEntities(from: module.exercises, for: entity)
        entity.exerciseInstances = NSOrderedSet(array: instanceEntities)
    }

    private func convertToModule(_ entity: ModuleEntity) -> Module {
        let exercises = convertExerciseInstanceEntities(entity.exerciseInstanceArray)

        return Module(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            exercises: exercises,
            notes: entity.notes,
            estimatedDuration: entity.estimatedDuration > 0 ? Int(entity.estimatedDuration) : nil,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            syncStatus: entity.syncStatus
        )
    }

    // MARK: - ExerciseInstance Conversion

    private func convertExerciseInstanceEntities(_ entities: [ExerciseInstanceEntity]) -> [ExerciseInstance] {
        entities.map { instanceEntity in
            let setGroups = instanceEntity.setGroupArray.map { sgEntity in
                SetGroup(
                    id: sgEntity.id,
                    sets: Int(sgEntity.sets),
                    targetReps: sgEntity.targetReps > 0 ? Int(sgEntity.targetReps) : nil,
                    targetWeight: sgEntity.targetWeight > 0 ? sgEntity.targetWeight : nil,
                    targetRPE: sgEntity.targetRPE > 0 ? Int(sgEntity.targetRPE) : nil,
                    targetDuration: sgEntity.targetDuration > 0 ? Int(sgEntity.targetDuration) : nil,
                    targetDistance: sgEntity.targetDistance > 0 ? sgEntity.targetDistance : nil,
                    targetHoldTime: sgEntity.targetHoldTime > 0 ? Int(sgEntity.targetHoldTime) : nil,
                    restPeriod: sgEntity.restPeriod > 0 ? Int(sgEntity.restPeriod) : nil,
                    notes: sgEntity.notes,
                    isInterval: sgEntity.isInterval,
                    workDuration: sgEntity.workDuration > 0 ? Int(sgEntity.workDuration) : nil,
                    intervalRestDuration: sgEntity.intervalRestDuration > 0 ? Int(sgEntity.intervalRestDuration) : nil,
                    implementMeasurableLabel: sgEntity.implementMeasurableLabel,
                    implementMeasurableUnit: sgEntity.implementMeasurableUnit,
                    implementMeasurableValue: sgEntity.implementMeasurableValue > 0 ? sgEntity.implementMeasurableValue : nil,
                    implementMeasurableStringValue: sgEntity.implementMeasurableStringValue
                )
            }

            // Migration: use direct fields, falling back to legacy overrides, then template lookup
            let name: String = instanceEntity.name
                ?? instanceEntity.nameOverride
                ?? ExerciseResolver.shared.getTemplate(id: instanceEntity.templateId ?? UUID())?.name
                ?? "Unknown Exercise"

            let exerciseType: ExerciseType = {
                if let raw = instanceEntity.exerciseTypeRaw, let type = ExerciseType(rawValue: raw) {
                    return type
                }
                if let override = instanceEntity.exerciseTypeOverride {
                    return override
                }
                if let templateId = instanceEntity.templateId,
                   let template = ExerciseResolver.shared.getTemplate(id: templateId) {
                    return template.exerciseType
                }
                return .strength
            }()

            let cardioMetric: CardioTracking = {
                if let raw = instanceEntity.cardioMetricRaw, let metric = CardioTracking(rawValue: raw) {
                    return metric
                }
                if let override = instanceEntity.cardioMetricOverride {
                    return override
                }
                if let templateId = instanceEntity.templateId,
                   let template = ExerciseResolver.shared.getTemplate(id: templateId) {
                    return template.cardioMetric
                }
                return .timeOnly
            }()

            let distanceUnit: DistanceUnit = {
                if let raw = instanceEntity.distanceUnitRaw, let unit = DistanceUnit(rawValue: raw) {
                    return unit
                }
                if let override = instanceEntity.distanceUnitOverride {
                    return override
                }
                if let templateId = instanceEntity.templateId,
                   let template = ExerciseResolver.shared.getTemplate(id: templateId) {
                    return template.distanceUnit
                }
                return .meters
            }()

            let mobilityTracking: MobilityTracking = {
                if let raw = instanceEntity.mobilityTrackingRaw, let tracking = MobilityTracking(rawValue: raw) {
                    return tracking
                }
                if let override = instanceEntity.mobilityTrackingOverride {
                    return override
                }
                if let templateId = instanceEntity.templateId,
                   let template = ExerciseResolver.shared.getTemplate(id: templateId) {
                    return template.mobilityTracking
                }
                return .repsOnly
            }()

            // Get other fields from entity or template
            let template = instanceEntity.templateId.flatMap { ExerciseResolver.shared.getTemplate(id: $0) }
            let primaryMuscles = instanceEntity.primaryMuscles.isEmpty ? (template?.primaryMuscles ?? []) : instanceEntity.primaryMuscles
            let secondaryMuscles = instanceEntity.secondaryMuscles.isEmpty ? (template?.secondaryMuscles ?? []) : instanceEntity.secondaryMuscles
            let implementIds = instanceEntity.implementIds.isEmpty ? (template?.implementIds ?? []) : instanceEntity.implementIds

            return ExerciseInstance(
                id: instanceEntity.id,
                templateId: instanceEntity.templateId,
                name: name,
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                distanceUnit: distanceUnit,
                mobilityTracking: mobilityTracking,
                isBodyweight: instanceEntity.isBodyweight || (template?.isBodyweight ?? false),
                recoveryActivityType: instanceEntity.recoveryActivityType ?? template?.recoveryActivityType,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                implementIds: implementIds,
                setGroups: setGroups,
                supersetGroupId: instanceEntity.supersetGroupId,
                order: Int(instanceEntity.orderIndex),
                notes: instanceEntity.notes,
                createdAt: instanceEntity.createdAt ?? Date(),
                updatedAt: instanceEntity.updatedAt ?? Date()
            )
        }
    }

    private func createExerciseInstanceEntities(
        from instances: [ExerciseInstance],
        for moduleEntity: ModuleEntity
    ) -> [ExerciseInstanceEntity] {
        instances.enumerated().map { index, instance in
            let instanceEntity = ExerciseInstanceEntity(context: viewContext)
            instanceEntity.id = instance.id
            instanceEntity.templateId = instance.templateId
            instanceEntity.supersetGroupId = instance.supersetGroupId
            instanceEntity.notes = instance.notes
            instanceEntity.orderIndex = Int32(index)
            instanceEntity.createdAt = instance.createdAt
            instanceEntity.updatedAt = instance.updatedAt

            // Save direct fields (new self-contained model)
            instanceEntity.name = instance.name
            instanceEntity.exerciseType = instance.exerciseType
            instanceEntity.cardioMetric = instance.cardioMetric
            instanceEntity.distanceUnit = instance.distanceUnit
            instanceEntity.mobilityTracking = instance.mobilityTracking
            instanceEntity.isBodyweight = instance.isBodyweight
            instanceEntity.recoveryActivityType = instance.recoveryActivityType
            instanceEntity.primaryMuscles = instance.primaryMuscles
            instanceEntity.secondaryMuscles = instance.secondaryMuscles
            instanceEntity.implementIds = instance.implementIds

            instanceEntity.module = moduleEntity

            // Add set groups
            let setGroupEntities = instance.setGroups.enumerated().map { sgIndex, setGroup in
                let sgEntity = SetGroupEntity(context: viewContext)
                sgEntity.id = setGroup.id
                sgEntity.sets = Int32(setGroup.sets)
                sgEntity.targetReps = Int32(setGroup.targetReps ?? 0)
                sgEntity.targetWeight = setGroup.targetWeight ?? 0
                sgEntity.targetRPE = Int32(setGroup.targetRPE ?? 0)
                sgEntity.targetDuration = Int32(setGroup.targetDuration ?? 0)
                sgEntity.targetDistance = setGroup.targetDistance ?? 0
                sgEntity.targetHoldTime = Int32(setGroup.targetHoldTime ?? 0)
                sgEntity.restPeriod = Int32(setGroup.restPeriod ?? 0)
                sgEntity.notes = setGroup.notes
                sgEntity.orderIndex = Int32(sgIndex)
                sgEntity.exerciseInstance = instanceEntity
                // Interval fields
                sgEntity.isInterval = setGroup.isInterval
                sgEntity.workDuration = Int32(setGroup.workDuration ?? 0)
                sgEntity.intervalRestDuration = Int32(setGroup.intervalRestDuration ?? 0)
                // Implement measurable fields
                sgEntity.implementMeasurableLabel = setGroup.implementMeasurableLabel
                sgEntity.implementMeasurableUnit = setGroup.implementMeasurableUnit
                sgEntity.implementMeasurableValue = setGroup.implementMeasurableValue ?? 0
                sgEntity.implementMeasurableStringValue = setGroup.implementMeasurableStringValue
                return sgEntity
            }
            instanceEntity.setGroups = NSOrderedSet(array: setGroupEntities)
            return instanceEntity
        }
    }
}
