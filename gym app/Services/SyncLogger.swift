//
//  SyncLogger.swift
//  gym app
//
//  Persistent logging service for sync operations
//  Helps debug sync issues in TestFlight builds
//

import Foundation
import CoreData

@preconcurrency @MainActor
class SyncLogger {
    static let shared = SyncLogger()

    private let persistence = PersistenceController.shared
    private let maxLogEntries = 100

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    // MARK: - Logging Methods

    /// Log an info message
    func info(_ message: String, context: String) {
        log(message, context: context, severity: .info)
    }

    /// Log a warning message
    func warning(_ message: String, context: String) {
        log(message, context: context, severity: .warning)
    }

    /// Log an error message
    func error(_ message: String, context: String) {
        log(message, context: context, severity: .error)
    }

    /// Log an Error object with additional context
    func logError(_ error: Error, context: String, additionalInfo: String? = nil) {
        var message = error.localizedDescription
        if let additionalInfo = additionalInfo {
            message = "\(additionalInfo): \(message)"
        }
        log(message, context: context, severity: .error)

        // TODO: In production builds, consider also sending critical errors to Firebase Crashlytics
        // Example: Crashlytics.crashlytics().record(error: error)
    }

    /// Core logging method
    func log(_ message: String, context: String, severity: SyncLogSeverity) {
        // Also print to console for Xcode debugging
        let prefix: String
        switch severity {
        case .info: prefix = "ℹ️"
        case .warning: prefix = "⚠️"
        case .error: prefix = "❌"
        }
        print("\(prefix) [\(context)] \(message)")

        // Create CoreData entry
        let entity = SyncLogEntity(context: viewContext)
        entity.id = UUID()
        entity.timestamp = Date()
        entity.context = context
        entity.message = message
        entity.severity = severity

        do {
            try viewContext.save()
            // Trim old entries if needed
            trimLogsIfNeeded()
        } catch {
            print("SyncLogger: Failed to save log entry: \(error)")
        }
    }

    // MARK: - Retrieval Methods

    /// Get recent log entries
    func getRecentLogs(limit: Int = 100) -> [SyncLogEntry] {
        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncLogEntity.timestamp, ascending: false)
        ]
        request.fetchLimit = limit

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            print("SyncLogger: Failed to fetch logs: \(error)")
            return []
        }
    }

    /// Get logs filtered by severity
    func getLogs(severity: SyncLogSeverity, limit: Int = 100) -> [SyncLogEntry] {
        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        request.predicate = NSPredicate(format: "severityRaw == %@", severity.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncLogEntity.timestamp, ascending: false)
        ]
        request.fetchLimit = limit

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            print("SyncLogger: Failed to fetch filtered logs: \(error)")
            return []
        }
    }

    /// Get logs filtered by context
    func getLogs(context: String, limit: Int = 100) -> [SyncLogEntry] {
        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        request.predicate = NSPredicate(format: "context CONTAINS[cd] %@", context)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncLogEntity.timestamp, ascending: false)
        ]
        request.fetchLimit = limit

        do {
            let entities = try viewContext.fetch(request)
            return entities.map { $0.toModel() }
        } catch {
            print("SyncLogger: Failed to fetch filtered logs: \(error)")
            return []
        }
    }

    /// Get total log count
    func getLogCount() -> Int {
        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    /// Get error count
    func getErrorCount() -> Int {
        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        request.predicate = NSPredicate(format: "severityRaw == %@", SyncLogSeverity.error.rawValue)
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    // MARK: - Cleanup

    /// Clear all logs
    func clearLogs() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "SyncLogEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            info("Logs cleared", context: "SyncLogger")
        } catch {
            print("SyncLogger: Failed to clear logs: \(error)")
        }
    }

    /// Trim logs to keep only the most recent entries
    private func trimLogsIfNeeded() {
        let count = getLogCount()
        guard count > maxLogEntries else { return }

        let deleteCount = count - maxLogEntries

        let request = NSFetchRequest<SyncLogEntity>(entityName: "SyncLogEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SyncLogEntity.timestamp, ascending: true)
        ]
        request.fetchLimit = deleteCount

        do {
            let oldEntries = try viewContext.fetch(request)
            for entry in oldEntries {
                viewContext.delete(entry)
            }
            try viewContext.save()
        } catch {
            print("SyncLogger: Failed to trim old logs: \(error)")
        }
    }

    // MARK: - Export

    /// Export logs as a string for sharing/debugging
    func exportLogsAsText() -> String {
        let logs = getRecentLogs(limit: maxLogEntries)
        var output = "=== Sync Logs Export ===\n"
        output += "Exported: \(Date())\n"
        output += "Total entries: \(logs.count)\n"
        output += "========================\n\n"

        for log in logs.reversed() {
            let severityIcon: String
            switch log.severity {
            case .info: severityIcon = "[INFO]"
            case .warning: severityIcon = "[WARN]"
            case .error: severityIcon = "[ERROR]"
            }
            output += "\(log.formattedTimestamp) \(severityIcon) [\(log.context)] \(log.message)\n"
        }

        return output
    }
}
