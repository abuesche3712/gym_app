//
//  Session.swift
//  gym app
//
//  A completed workout instance with actual logged data
//

import Foundation

struct Session: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.session

    var id: UUID
    var workoutId: UUID
    var workoutName: String // Denormalized for easy display
    var date: Date
    var completedModules: [CompletedModule]
    var skippedModuleIds: [UUID]
    var duration: Int? // minutes, actual time taken
    var overallFeeling: Int? // 1-5 scale
    var notes: String?
    var createdAt: Date
    var syncStatus: SyncStatus

    // Program context (for sessions completed as part of a program)
    var programId: UUID?
    var programName: String?
    var programWeekNumber: Int? // Which week of the program (1-based)

    // Quick Log flag (true for sessions created via Quick Log without workout template)
    var isQuickLog: Bool

    // Freestyle flag (true for sessions started without a template, exercises added on-the-fly)
    var isFreestyle: Bool

    // Imported flag (true for sessions imported from external apps like Strong)
    var isImported: Bool

    /// Whether this session is unstructured (Quick Log or Freestyle)
    var isUnstructured: Bool { isQuickLog || isFreestyle }

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        date: Date = Date(),
        completedModules: [CompletedModule] = [],
        skippedModuleIds: [UUID] = [],
        duration: Int? = nil,
        overallFeeling: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync,
        programId: UUID? = nil,
        programName: String? = nil,
        programWeekNumber: Int? = nil,
        isQuickLog: Bool = false,
        isFreestyle: Bool = false,
        isImported: Bool = false
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.date = date
        self.completedModules = completedModules
        self.skippedModuleIds = skippedModuleIds
        self.duration = duration
        self.overallFeeling = overallFeeling
        self.notes = notes
        self.createdAt = createdAt
        self.syncStatus = syncStatus
        self.programId = programId
        self.programName = programName
        self.programWeekNumber = programWeekNumber
        self.isQuickLog = isQuickLog
        self.isFreestyle = isFreestyle
        self.isImported = isImported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.session

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        date = try container.decode(Date.self, forKey: .date)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        syncStatus = try container.decode(SyncStatus.self, forKey: .syncStatus)

        // Optional with defaults
        completedModules = try container.decodeIfPresent([CompletedModule].self, forKey: .completedModules) ?? []
        skippedModuleIds = try container.decodeIfPresent([UUID].self, forKey: .skippedModuleIds) ?? []

        // Truly optional
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        overallFeeling = try container.decodeIfPresent(Int.self, forKey: .overallFeeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Program context (optional - nil for ad-hoc workouts)
        programId = try container.decodeIfPresent(UUID.self, forKey: .programId)
        programName = try container.decodeIfPresent(String.self, forKey: .programName)
        programWeekNumber = try container.decodeIfPresent(Int.self, forKey: .programWeekNumber)

        // Quick Log flag (backward compat default of false)
        isQuickLog = try container.decodeIfPresent(Bool.self, forKey: .isQuickLog) ?? false

        // Freestyle flag (backward compat default of false)
        isFreestyle = try container.decodeIfPresent(Bool.self, forKey: .isFreestyle) ?? false

        // Imported flag (backward compat default of false)
        isImported = try container.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, workoutId, workoutName, date, completedModules, skippedModuleIds, duration, overallFeeling, notes, createdAt, syncStatus
        case programId, programName, programWeekNumber
        case isQuickLog, isFreestyle, isImported
    }

    var formattedDate: String {
        formatDate(date)
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        return formatDurationMinutes(duration)
    }

    var totalExercisesCompleted: Int {
        completedModules.filter { !$0.skipped }.reduce(0) { $0 + $1.completedExercises.count }
    }

    var totalSetsCompleted: Int {
        completedModules.filter { !$0.skipped }.reduce(0) { module, completed in
            module + completed.completedExercises.reduce(0) { exercise, completedExercise in
                exercise + completedExercise.completedSetGroups.reduce(0) { setGroup, completedGroup in
                    setGroup + completedGroup.sets.filter { $0.completed }.count
                }
            }
        }
    }

    /// Whether this session can still be edited (within 30 days of creation)
    var isEditable: Bool {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return daysSinceCreation <= 30
    }

    /// Display name for the session - shows exercise name for Quick Log/Freestyle, otherwise workout name
    var displayName: String {
        if isUnstructured {
            // For Quick Log/Freestyle, show the first exercise name(s)
            let exercises = completedModules.flatMap { $0.completedExercises }
            if exercises.isEmpty {
                return isFreestyle ? "Freestyle" : "Quick Log"
            } else if exercises.count == 1 {
                return exercises[0].exerciseName
            } else {
                // Multiple exercises - show first + count
                return "\(exercises[0].exerciseName) +\(exercises.count - 1)"
            }
        }
        return workoutName
    }
}
