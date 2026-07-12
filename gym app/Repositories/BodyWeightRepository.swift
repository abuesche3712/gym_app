//
//  BodyWeightRepository.swift
//  gym app
//
//  Handles BodyWeightEntry CRUD operations and CoreData conversion.
//  Local-only (no Firestore sync plumbing) by design.
//

import CoreData
import Combine

@MainActor
class BodyWeightRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    /// Sorted ascending by date (oldest first) for charting convenience.
    @Published private(set) var entries: [BodyWeightEntry] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadAll()
    }

    // MARK: - CRUD Operations

    /// Load all bodyweight entries from CoreData
    func loadAll() {
        let request = NSFetchRequest<BodyWeightEntryEntity>(entityName: "BodyWeightEntryEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            entries = entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "BodyWeightRepository.loadAll")
        }
    }

    /// Save or update a bodyweight entry
    @discardableResult
    func save(_ entry: BodyWeightEntry) -> Bool {
        let entity = findOrCreateEntity(id: entry.id)
        entity.update(from: entry)
        let success = persistence.save()
        loadAll()
        Logger.debug("BodyWeightRepository: saved entry \(entry.id) (\(entry.weightKg) kg)")
        return success
    }

    /// Delete a bodyweight entry
    func delete(_ entry: BodyWeightEntry) {
        if let entity = findEntity(id: entry.id) {
            viewContext.delete(entity)
            persistence.save()
        }
        loadAll()
        Logger.debug("BodyWeightRepository: deleted entry \(entry.id)")
    }

    // MARK: - Query Operations

    /// Latest logged entry (by date)
    var latestEntry: BodyWeightEntry? {
        entries.last
    }

    /// Entries within a closed date range, ascending by date.
    func entries(from startDate: Date, to endDate: Date = Date()) -> [BodyWeightEntry] {
        entries.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Private Helpers

    private func findEntity(id: UUID) -> BodyWeightEntryEntity? {
        let request = NSFetchRequest<BodyWeightEntryEntity>(entityName: "BodyWeightEntryEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    private func findOrCreateEntity(id: UUID) -> BodyWeightEntryEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = BodyWeightEntryEntity(context: viewContext)
        entity.id = id
        return entity
    }
}
