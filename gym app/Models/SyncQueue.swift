//
//  SyncQueue.swift
//  gym app
//
//  Model for queued sync operations that need to be uploaded to Firebase
//

import Foundation

// MARK: - Sync Operation Type

enum SyncAction: String, Codable {
    case create
    case update
    case delete
}

// MARK: - Sync Entity Type

enum SyncEntityType: String, Codable, CaseIterable {
    case session          // Completed workout
    case setData          // Individual set logged during workout
    case module
    case workout
    case program
    case scheduledWorkout
    case customExercise
    case userProfile

    var displayName: String {
        switch self {
        case .session: return "Completed Workout"
        case .setData: return "Set"
        case .module: return "Module"
        case .workout: return "Workout"
        case .program: return "Program"
        case .scheduledWorkout: return "Scheduled Workout"
        case .customExercise: return "Custom Exercise"
        case .userProfile: return "User Profile"
        }
    }

    /// Priority for sync ordering (lower = higher priority)
    var priority: Int {
        switch self {
        case .setData: return 1        // Sets sync first (during active workout)
        case .session: return 2        // Then completed workouts
        case .userProfile: return 3    // Then profile
        case .customExercise: return 4 // Then library items
        case .module: return 5
        case .workout: return 6
        case .program: return 7
        case .scheduledWorkout: return 8
        }
    }
}

// MARK: - Sync Queue Item

struct SyncQueueItem: Identifiable, Codable {
    var id: UUID
    var entityType: SyncEntityType
    var entityId: UUID
    var action: SyncAction
    var payload: Data  // JSON-encoded entity data
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var lastError: String?

    /// Maximum retry attempts before flagging for manual intervention
    static let maxRetries = 5

    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        action: SyncAction,
        payload: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.action = action
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.lastError = lastError
    }

    /// Whether this item has exceeded retry limit
    var needsManualIntervention: Bool {
        retryCount >= Self.maxRetries
    }

    /// Create a copy with incremented retry count and error
    func withRetry(error: String) -> SyncQueueItem {
        var copy = self
        copy.retryCount += 1
        copy.lastAttemptAt = Date()
        copy.lastError = error
        return copy
    }
}

// MARK: - Sync Status

enum SyncState: Equatable {
    case idle
    case syncing(progress: String)
    case offline
    case error(message: String)
    case success

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .syncing(let progress): return progress
        case .offline: return "Offline"
        case .error(let message): return "Error: \(message)"
        case .success: return "Synced"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "checkmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        case .success: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Library Sync Metadata

struct LibrarySyncMetadata: Codable {
    var exerciseLibraryLastSync: Date?
    var equipmentLibraryLastSync: Date?
    var progressionSchemesLastSync: Date?

    init() {
        self.exerciseLibraryLastSync = nil
        self.equipmentLibraryLastSync = nil
        self.progressionSchemesLastSync = nil
    }

    /// Check if library needs refresh (older than 24 hours)
    func needsRefresh(_ keyPath: KeyPath<LibrarySyncMetadata, Date?>, maxAge: TimeInterval = 86400) -> Bool {
        guard let lastSync = self[keyPath: keyPath] else { return true }
        return Date().timeIntervalSince(lastSync) > maxAge
    }
}
