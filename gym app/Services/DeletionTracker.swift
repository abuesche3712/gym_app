//
//  DeletionTracker.swift
//  gym app
//
//  Tracks deleted entities for reliable cross-device sync
//  Uses CoreData for persistence and syncs to Firebase
//

import Foundation
import CoreData

@preconcurrency @MainActor
class DeletionTracker {
    static let shared = DeletionTracker()

    private let persistence = PersistenceController.shared
    private let logger = SyncLogger.shared

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    // MARK: - Legacy UserDefaults Keys (for migration)

    private let legacyDeletedModuleIdsKey = "deletedModuleIds"
    private let legacyDeletedWorkoutIdsKey = "deletedWorkoutIds"
    private let legacyDeletedProgramIdsKey = "deletedProgramIds"
    private let legacyDeletedSessionIdsKey = "deletedSessionIds"
    private let legacyDeletedScheduledWorkoutIdsKey = "deletedScheduledWorkoutIds"
    private let migrationCompletedKey = "deletionTracker_migrationCompleted"

    // Configuration
    private let retentionDays = 30

    // MARK: - Initialization & Migration

    init() {
        // Run migration on first access if needed
        migrateFromUserDefaultsIfNeeded()
    }

    /// Migrate existing UserDefaults deletion IDs to CoreData (one-time)
    private func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return
        }

        logger.info("Starting deletion records migration from UserDefaults", context: "DeletionTracker")

        var totalMigrated = 0

        // Migrate modules
        totalMigrated += migrateIdsFromUserDefaults(key: legacyDeletedModuleIdsKey, entityType: .module)

        // Migrate workouts
        totalMigrated += migrateIdsFromUserDefaults(key: legacyDeletedWorkoutIdsKey, entityType: .workout)

        // Migrate programs
        totalMigrated += migrateIdsFromUserDefaults(key: legacyDeletedProgramIdsKey, entityType: .program)

        // Migrate sessions
        totalMigrated += migrateIdsFromUserDefaults(key: legacyDeletedSessionIdsKey, entityType: .session)

        // Migrate scheduled workouts
        totalMigrated += migrateIdsFromUserDefaults(key: legacyDeletedScheduledWorkoutIdsKey, entityType: .scheduledWorkout)

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)

        logger.info("Migration complete: \(totalMigrated) deletion records migrated", context: "DeletionTracker")
    }

    private func migrateIdsFromUserDefaults(key: String, entityType: DeletionEntityType) -> Int {
        let strings = UserDefaults.standard.stringArray(forKey: key) ?? []
        let ids = strings.compactMap { UUID(uuidString: $0) }

        guard !ids.isEmpty else { return 0 }

        // Use a date in the past for migrated records (we don't know exact deletion time)
        let migrationDate = Date().addingTimeInterval(-86400) // 1 day ago

        for id in ids {
            recordDeletionInternal(entityType: entityType, entityId: id, deletedAt: migrationDate)
        }

        logger.info("Migrated \(ids.count) \(entityType.rawValue) deletion records", context: "DeletionTracker")

        return ids.count
    }

    // MARK: - Record Deletions

    /// Record that an entity was deleted
    func recordDeletion(entityType: DeletionEntityType, entityId: UUID) {
        recordDeletionInternal(entityType: entityType, entityId: entityId, deletedAt: Date())
        logger.info("Recorded deletion: \(entityType.rawValue) \(entityId)", context: "DeletionTracker")
    }

    private func recordDeletionInternal(entityType: DeletionEntityType, entityId: UUID, deletedAt: Date) {
        // Check if already exists
        if getDeletionRecord(entityType: entityType, entityId: entityId) != nil {
            return
        }

        let entity = DeletionRecordEntity(context: viewContext)
        entity.id = UUID()
        entity.entityType = entityType
        entity.entityId = entityId
        entity.deletedAt = deletedAt
        entity.syncedAt = nil

        do {
            try viewContext.save()
        } catch {
            logger.logError(error, context: "DeletionTracker.recordDeletion", additionalInfo: "Failed to save deletion record")
        }
    }

    /// Record multiple deletions at once (for batch operations)
    func recordDeletions(entityType: DeletionEntityType, entityIds: [UUID]) {
        for entityId in entityIds {
            recordDeletionInternal(entityType: entityType, entityId: entityId, deletedAt: Date())
        }
        logger.info("Recorded \(entityIds.count) \(entityType.rawValue) deletions", context: "DeletionTracker")
    }

    // MARK: - Check Deletions

    /// Check if an entity has been deleted
    func isDeleted(entityType: DeletionEntityType, entityId: UUID) -> Bool {
        getDeletionRecord(entityType: entityType, entityId: entityId) != nil
    }

    /// Check if an entity was deleted after a given date
    /// Returns true if entity was deleted AND the deletion is newer than the edit
    func wasDeletedAfter(entityType: DeletionEntityType, entityId: UUID, date: Date) -> Bool {
        guard let record = getDeletionRecord(entityType: entityType, entityId: entityId) else {
            return false
        }
        return record.deletedAt > date
    }

    /// Get all deleted entity IDs for a type
    func getDeletedIds(entityType: DeletionEntityType) -> Set<UUID> {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(format: "entityTypeRaw == %@", entityType.rawValue)

        do {
            let records = try viewContext.fetch(request)
            return Set(records.map { $0.entityId })
        } catch {
            logger.logError(error, context: "DeletionTracker.getDeletedIds")
            return []
        }
    }

    /// Get deletion record for an entity
    func getDeletionRecord(entityType: DeletionEntityType, entityId: UUID) -> DeletionRecord? {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(
            format: "entityTypeRaw == %@ AND entityId == %@",
            entityType.rawValue,
            entityId as CVarArg
        )
        request.fetchLimit = 1

        do {
            let records = try viewContext.fetch(request)
            return records.first?.toModel()
        } catch {
            logger.logError(error, context: "DeletionTracker.getDeletionRecord")
            return nil
        }
    }

    // MARK: - Sync Support

    /// Get all deletion records that need to be synced
    func getUnsyncedDeletions() -> [DeletionRecord] {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(format: "syncedAt == nil")

        do {
            let records = try viewContext.fetch(request)
            return records.map { $0.toModel() }
        } catch {
            logger.logError(error, context: "DeletionTracker.getUnsyncedDeletions")
            return []
        }
    }

    /// Get all deletion records (for full sync)
    func getAllDeletions() -> [DeletionRecord] {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DeletionRecordEntity.deletedAt, ascending: false)]

        do {
            let records = try viewContext.fetch(request)
            return records.map { $0.toModel() }
        } catch {
            logger.logError(error, context: "DeletionTracker.getAllDeletions")
            return []
        }
    }

    /// Mark deletion as synced
    func markAsSynced(entityType: DeletionEntityType, entityId: UUID) {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(
            format: "entityTypeRaw == %@ AND entityId == %@",
            entityType.rawValue,
            entityId as CVarArg
        )
        request.fetchLimit = 1

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.syncedAt = Date()
                try viewContext.save()
            }
        } catch {
            logger.logError(error, context: "DeletionTracker.markAsSynced")
        }
    }

    /// Import deletion from cloud (for sync)
    func importFromCloud(_ record: DeletionRecord) {
        // Check if we already have this deletion
        if let existing = getDeletionRecord(entityType: record.entityType, entityId: record.entityId) {
            // Keep the newer one
            if record.deletedAt > existing.deletedAt {
                updateDeletionDate(entityType: record.entityType, entityId: record.entityId, deletedAt: record.deletedAt)
            }
            return
        }

        // Create new record
        let entity = DeletionRecordEntity(context: viewContext)
        entity.id = record.id
        entity.entityType = record.entityType
        entity.entityId = record.entityId
        entity.deletedAt = record.deletedAt
        entity.syncedAt = Date() // Mark as synced since it came from cloud

        do {
            try viewContext.save()
            logger.info("Imported deletion from cloud: \(record.entityType.rawValue) \(record.entityId)", context: "DeletionTracker")
        } catch {
            logger.logError(error, context: "DeletionTracker.importFromCloud")
        }
    }

    private func updateDeletionDate(entityType: DeletionEntityType, entityId: UUID, deletedAt: Date) {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(
            format: "entityTypeRaw == %@ AND entityId == %@",
            entityType.rawValue,
            entityId as CVarArg
        )
        request.fetchLimit = 1

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.deletedAt = deletedAt
                try viewContext.save()
            }
        } catch {
            logger.logError(error, context: "DeletionTracker.updateDeletionDate")
        }
    }

    // MARK: - Cleanup

    /// Remove deletion records older than retention period
    func cleanupOldRecords() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(format: "deletedAt < %@ AND syncedAt != nil", cutoffDate as NSDate)

        do {
            let oldRecords = try viewContext.fetch(request)

            guard !oldRecords.isEmpty else { return }

            for record in oldRecords {
                viewContext.delete(record)
            }
            try viewContext.save()

            logger.info("Cleaned up \(oldRecords.count) old deletion records", context: "DeletionTracker")
        } catch {
            logger.logError(error, context: "DeletionTracker.cleanupOldRecords")
        }
    }

    /// Get deletion records older than retention period (for cloud cleanup)
    func getRecordsToCleanup() -> [DeletionRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(format: "deletedAt < %@ AND syncedAt != nil", cutoffDate as NSDate)

        do {
            let records = try viewContext.fetch(request)
            return records.map { $0.toModel() }
        } catch {
            logger.logError(error, context: "DeletionTracker.getRecordsToCleanup")
            return []
        }
    }

    /// Remove a specific deletion record (after cleanup from cloud)
    func removeRecord(entityType: DeletionEntityType, entityId: UUID) {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(
            format: "entityTypeRaw == %@ AND entityId == %@",
            entityType.rawValue,
            entityId as CVarArg
        )

        do {
            let records = try viewContext.fetch(request)
            for record in records {
                viewContext.delete(record)
            }
            try viewContext.save()
        } catch {
            logger.logError(error, context: "DeletionTracker.removeRecord")
        }
    }

    // MARK: - Debug / Stats

    /// Get count of deletion records
    func getRecordCount() -> Int {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    /// Get count by entity type
    func getRecordCount(for entityType: DeletionEntityType) -> Int {
        let request = NSFetchRequest<DeletionRecordEntity>(entityName: "DeletionRecordEntity")
        request.predicate = NSPredicate(format: "entityTypeRaw == %@", entityType.rawValue)
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }
}
