//
//  WorkoutRepository.swift
//  gym app
//
//  Handles Workout CRUD operations and CoreData conversion
//

import CoreData

@MainActor
class WorkoutRepository {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - CRUD Operations

    func loadAll() -> [Workout] {
        let request = NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutEntity.name, ascending: true)]
        request.predicate = NSPredicate(format: "archived == NO")

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { convertToWorkout($0) }
        } catch {
            Logger.error(error, context: "WorkoutRepository.loadAll")
            return []
        }
    }

    func save(_ workout: Workout) {
        let entity = findOrCreateEntity(id: workout.id)
        updateEntity(entity, from: workout)
        persistence.save()
    }

    func delete(_ workout: Workout) {
        if let entity = findEntity(id: workout.id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    func find(id: UUID) -> Workout? {
        guard let entity = findEntity(id: id) else { return nil }
        return convertToWorkout(entity)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> WorkoutEntity? {
        let request = NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
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

    private func findOrCreateEntity(id: UUID) -> WorkoutEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = WorkoutEntity(context: viewContext)
        entity.id = id
        return entity
    }

    private func updateEntity(_ entity: WorkoutEntity, from workout: Workout) {
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

    private func convertToWorkout(_ entity: WorkoutEntity) -> Workout {
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
}
