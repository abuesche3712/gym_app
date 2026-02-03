//
//  WorkoutRepository.swift
//  gym app
//
//  Handles Workout CRUD operations and CoreData conversion
//

import CoreData

@MainActor
class WorkoutRepository: CoreDataRepository {
    typealias DomainModel = Workout
    typealias CDEntity = WorkoutEntity

    let persistence: PersistenceController

    var entityName: String { "WorkoutEntity" }

    var defaultSortDescriptors: [NSSortDescriptor] {
        [NSSortDescriptor(keyPath: \WorkoutEntity.name, ascending: true)]
    }

    var defaultPredicate: NSPredicate? {
        NSPredicate(format: "archived == NO")
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Entity-Specific Conversion

    func toDomain(_ entity: WorkoutEntity) -> Workout {
        let moduleRefs = entity.moduleReferenceArray.map { refEntity in
            ModuleReference(
                id: refEntity.id,
                moduleId: refEntity.moduleId,
                order: Int(refEntity.orderIndex),
                isRequired: refEntity.isRequired,
                notes: refEntity.notes
            )
        }

        return Workout(
            id: entity.id,
            name: entity.name,
            moduleReferences: moduleRefs,
            standaloneExercises: entity.standaloneExercises,
            estimatedDuration: entity.estimatedDuration > 0 ? Int(entity.estimatedDuration) : nil,
            notes: entity.notes,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            archived: entity.archived,
            syncStatus: entity.syncStatus
        )
    }

    func updateEntity(_ entity: WorkoutEntity, from workout: Workout) {
        entity.name = workout.name
        entity.estimatedDuration = Int32(workout.estimatedDuration ?? 0)
        entity.notes = workout.notes
        entity.archived = workout.archived
        entity.createdAt = workout.createdAt
        entity.updatedAt = workout.updatedAt
        entity.syncStatus = workout.syncStatus

        // Clear existing module references
        if let existingRefs = entity.moduleReferences {
            for case let ref as ModuleReferenceEntity in existingRefs {
                viewContext.delete(ref)
            }
        }

        // Add module references
        let refEntities = workout.moduleReferences.map { ref in
            let refEntity = ModuleReferenceEntity(context: viewContext)
            refEntity.id = ref.id
            refEntity.moduleId = ref.moduleId
            refEntity.orderIndex = Int32(ref.order)
            refEntity.isRequired = ref.isRequired
            refEntity.notes = ref.notes
            refEntity.workout = entity
            return refEntity
        }
        entity.moduleReferences = NSOrderedSet(array: refEntities)

        // Save standalone exercises
        entity.standaloneExercises = workout.standaloneExercises
    }
}
