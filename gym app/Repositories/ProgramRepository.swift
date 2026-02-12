//
//  ProgramRepository.swift
//  gym app
//
//  Handles Program CRUD operations and CoreData conversion
//

import CoreData

@MainActor
class ProgramRepository: CoreDataRepository {
    typealias DomainModel = Program
    typealias CDEntity = ProgramEntity

    let persistence: PersistenceController

    var entityName: String { "ProgramEntity" }

    var defaultSortDescriptors: [NSSortDescriptor] {
        [NSSortDescriptor(keyPath: \ProgramEntity.updatedAt, ascending: false)]
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Entity-Specific Conversion

    func toDomain(_ entity: ProgramEntity) -> Program {
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
            progressionPolicy: entity.progressionPolicy,
            progressionEnabledExercises: entity.progressionEnabledExercises,
            exerciseProgressionOverrides: entity.exerciseProgressionOverrides,
            exerciseProgressionStates: entity.exerciseProgressionStates
        )
    }

    func updateEntity(_ entity: ProgramEntity, from program: Program) {
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
        entity.progressionPolicy = program.progressionPolicy
        entity.defaultProgressionRule = program.defaultProgressionRule
        entity.progressionEnabledExercises = program.progressionEnabledExercises
        entity.exerciseProgressionOverrides = program.exerciseProgressionOverrides
        entity.exerciseProgressionStates = program.exerciseProgressionStates

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

    // MARK: - Program-Specific Queries

    func findActive() -> Program? {
        let request = NSFetchRequest<ProgramEntity>(entityName: entityName)
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1

        guard let entity = try? viewContext.fetch(request).first else {
            return nil
        }
        return toDomain(entity)
    }
}
