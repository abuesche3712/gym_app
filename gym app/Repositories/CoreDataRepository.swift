//
//  CoreDataRepository.swift
//  gym app
//
//  Protocol for CoreData repositories with common CRUD operations.
//  Each repository implements entity-specific conversion methods.
//

import CoreData

/// Protocol for CoreData repositories with common CRUD operations.
/// Each conforming repository implements entity-specific conversion methods.
protocol CoreDataRepository {
    associatedtype DomainModel: Identifiable where DomainModel.ID == UUID
    associatedtype CDEntity: NSManagedObject

    var persistence: PersistenceController { get }
    var entityName: String { get }
    var defaultSortDescriptors: [NSSortDescriptor] { get }
    var defaultPredicate: NSPredicate? { get }

    /// Convert a CoreData entity to a domain model (implemented by each repo)
    func toDomain(_ entity: CDEntity) -> DomainModel

    /// Update a CoreData entity from a domain model (implemented by each repo)
    func updateEntity(_ entity: CDEntity, from model: DomainModel)
}

// MARK: - Default Implementations

extension CoreDataRepository {
    var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    var defaultPredicate: NSPredicate? { nil }

    // MARK: - Generic CRUD

    func loadAll() -> [DomainModel] {
        let request = NSFetchRequest<CDEntity>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        if let predicate = defaultPredicate {
            request.predicate = predicate
        }

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { toDomain($0) }
        } catch {
            Logger.error(error, context: "\(type(of: self)).loadAll")
            return []
        }
    }

    func find(id: UUID) -> DomainModel? {
        guard let entity = findEntity(id: id) else { return nil }
        return toDomain(entity)
    }

    func save(_ model: DomainModel) {
        let entity = findOrCreateEntity(id: model.id)
        updateEntity(entity, from: model)
        persistence.save()
    }

    func delete(_ model: DomainModel) {
        if let entity = findEntity(id: model.id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> CDEntity? {
        let request = NSFetchRequest<CDEntity>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    func deleteEntity(id: UUID) {
        if let entity = findEntity(id: id) {
            viewContext.delete(entity)
            persistence.save()
        }
    }

    func findOrCreateEntity(id: UUID) -> CDEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = CDEntity(context: viewContext)
        entity.setValue(id, forKey: "id")
        return entity
    }
}
