//
//  ProgramRepository.swift
//  gym app
//
//  Handles Program CRUD operations and CoreData conversion
//

import CoreData

@MainActor
class ProgramRepository {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - CRUD Operations

    func loadAll() -> [Program] {
        let request = NSFetchRequest<ProgramEntity>(entityName: "ProgramEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgramEntity.updatedAt, ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { convertToProgram($0) }
        } catch {
            Logger.error(error, context: "ProgramRepository.loadAll")
            return []
        }
    }

    func save(_ program: Program) {
        let entity = findOrCreateEntity(id: program.id)
        updateEntity(entity, from: program)
        persistence.save()
    }

    func delete(_ program: Program) {
        if let entity = findEntity(id: program.id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    func find(id: UUID) -> Program? {
        guard let entity = findEntity(id: id) else { return nil }
        return convertToProgram(entity)
    }

    func findActive() -> Program? {
        let request = NSFetchRequest<ProgramEntity>(entityName: "ProgramEntity")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1

        guard let entity = try? viewContext.fetch(request).first else {
            return nil
        }
        return convertToProgram(entity)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> ProgramEntity? {
        let request = NSFetchRequest<ProgramEntity>(entityName: "ProgramEntity")
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

    private func findOrCreateEntity(id: UUID) -> ProgramEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = ProgramEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateEntity(_ entity: ProgramEntity, from program: Program) {
        entity.name = program.name
        entity.programDescription = program.programDescription
        entity.durationWeeks = Int32(program.durationWeeks)
        entity.startDate = program.startDate
        entity.endDate = program.endDate
        entity.isActive = program.isActive
        entity.createdAt = program.createdAt
        entity.updatedAt = program.updatedAt
        entity.syncStatus = program.syncStatus

        // Progression configuration
        entity.progressionEnabled = program.progressionEnabled
        entity.defaultProgressionRule = program.defaultProgressionRule
        entity.progressionEnabledExercises = program.progressionEnabledExercises
        entity.exerciseProgressionOverrides = program.exerciseProgressionOverrides

        // Clear existing workout slots
        if let existingSlots = entity.workoutSlots {
            for case let slot as ProgramWorkoutSlotEntity in existingSlots {
                viewContext.delete(slot)
            }
        }

        // Add workout slots
        let slotEntities = program.workoutSlots.enumerated().map { index, slot in
            let slotEntity = ProgramWorkoutSlotEntity(context: viewContext)
            slotEntity.id = slot.id
            slotEntity.workoutId = slot.workoutId
            slotEntity.workoutName = slot.workoutName
            slotEntity.scheduleType = slot.scheduleType
            slotEntity.optionalDayOfWeek = slot.dayOfWeek
            slotEntity.optionalWeekNumber = slot.weekNumber
            slotEntity.optionalSpecificDateOffset = slot.specificDateOffset
            slotEntity.orderIndex = Int32(index)
            slotEntity.notes = slot.notes
            slotEntity.program = entity
            return slotEntity
        }
        entity.workoutSlots = NSOrderedSet(array: slotEntities)
    }

    private func convertToProgram(_ entity: ProgramEntity) -> Program {
        let slots = entity.workoutSlotArray.map { slotEntity in
            ProgramWorkoutSlot(
                id: slotEntity.id,
                workoutId: slotEntity.workoutId,
                workoutName: slotEntity.workoutName,
                scheduleType: slotEntity.scheduleType,
                dayOfWeek: slotEntity.optionalDayOfWeek,
                weekNumber: slotEntity.optionalWeekNumber,
                specificDateOffset: slotEntity.optionalSpecificDateOffset,
                order: Int(slotEntity.orderIndex),
                notes: slotEntity.notes
            )
        }

        return Program(
            id: entity.id,
            name: entity.name,
            programDescription: entity.programDescription,
            durationWeeks: Int(entity.durationWeeks),
            startDate: entity.startDate,
            endDate: entity.endDate,
            isActive: entity.isActive,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            syncStatus: entity.syncStatus,
            workoutSlots: slots,
            defaultProgressionRule: entity.defaultProgressionRule,
            progressionEnabled: entity.progressionEnabled,
            progressionEnabledExercises: entity.progressionEnabledExercises,
            exerciseProgressionOverrides: entity.exerciseProgressionOverrides
        )
    }
}
