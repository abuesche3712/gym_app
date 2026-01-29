//
//  CompletedProgram.swift
//  gym app
//
//  Represents a user's completion/progress through a training program.
//  Top-level entity in the shareable hierarchy:
//  CompletedProgram → Session → CompletedModule → SessionExercise → SetData
//

import Foundation

// MARK: - Program Completion Status

enum ProgramCompletionStatus: String, Codable, CaseIterable {
    case inProgress = "inProgress"
    case completed = "completed"
    case abandoned = "abandoned"

    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .abandoned: return "Abandoned"
        }
    }
}

// MARK: - Completed Program

/// Tracks a user's journey through a training program.
/// This is the top-level shareable entity that links to all sessions completed as part of the program.
struct CompletedProgram: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.completedProgram

    var id: UUID
    var programId: UUID              // The program template this is tracking
    var programName: String          // Denormalized for display
    var programDescription: String?

    // Timeline
    var startDate: Date              // When the user started the program
    var endDate: Date?               // When the user finished (completed/abandoned)
    var targetEndDate: Date?         // Original planned end date

    // Progress
    var status: ProgramCompletionStatus
    var totalWeeks: Int              // Total weeks in the program
    var currentWeek: Int             // Current week (1-based)
    var completedSessionIds: [UUID]  // All sessions completed as part of this program

    // Aggregate stats (updated as sessions complete)
    var totalSessionsPlanned: Int
    var totalSessionsCompleted: Int
    var totalSetsCompleted: Int
    var totalVolume: Double          // Total weight × reps across all sessions
    var totalDurationMinutes: Int    // Total time spent

    // Metadata
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    // Notes/reflection
    var notes: String?
    var completionNotes: String?     // Final thoughts when completing the program

    init(
        id: UUID = UUID(),
        programId: UUID,
        programName: String,
        programDescription: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        targetEndDate: Date? = nil,
        status: ProgramCompletionStatus = .inProgress,
        totalWeeks: Int,
        currentWeek: Int = 1,
        completedSessionIds: [UUID] = [],
        totalSessionsPlanned: Int = 0,
        totalSessionsCompleted: Int = 0,
        totalSetsCompleted: Int = 0,
        totalVolume: Double = 0,
        totalDurationMinutes: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync,
        notes: String? = nil,
        completionNotes: String? = nil
    ) {
        self.id = id
        self.programId = programId
        self.programName = programName
        self.programDescription = programDescription
        self.startDate = startDate
        self.endDate = endDate
        self.targetEndDate = targetEndDate
        self.status = status
        self.totalWeeks = totalWeeks
        self.currentWeek = currentWeek
        self.completedSessionIds = completedSessionIds
        self.totalSessionsPlanned = totalSessionsPlanned
        self.totalSessionsCompleted = totalSessionsCompleted
        self.totalSetsCompleted = totalSetsCompleted
        self.totalVolume = totalVolume
        self.totalDurationMinutes = totalDurationMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.notes = notes
        self.completionNotes = completionNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.completedProgram

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        programId = try container.decode(UUID.self, forKey: .programId)
        programName = try container.decode(String.self, forKey: .programName)
        startDate = try container.decode(Date.self, forKey: .startDate)
        status = try container.decode(ProgramCompletionStatus.self, forKey: .status)
        totalWeeks = try container.decode(Int.self, forKey: .totalWeeks)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        syncStatus = try container.decode(SyncStatus.self, forKey: .syncStatus)

        // Optional with defaults
        currentWeek = try container.decodeIfPresent(Int.self, forKey: .currentWeek) ?? 1
        completedSessionIds = try container.decodeIfPresent([UUID].self, forKey: .completedSessionIds) ?? []
        totalSessionsPlanned = try container.decodeIfPresent(Int.self, forKey: .totalSessionsPlanned) ?? 0
        totalSessionsCompleted = try container.decodeIfPresent(Int.self, forKey: .totalSessionsCompleted) ?? 0
        totalSetsCompleted = try container.decodeIfPresent(Int.self, forKey: .totalSetsCompleted) ?? 0
        totalVolume = try container.decodeIfPresent(Double.self, forKey: .totalVolume) ?? 0
        totalDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .totalDurationMinutes) ?? 0

        // Truly optional
        programDescription = try container.decodeIfPresent(String.self, forKey: .programDescription)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        targetEndDate = try container.decodeIfPresent(Date.self, forKey: .targetEndDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        completionNotes = try container.decodeIfPresent(String.self, forKey: .completionNotes)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, programId, programName, programDescription
        case startDate, endDate, targetEndDate
        case status, totalWeeks, currentWeek, completedSessionIds
        case totalSessionsPlanned, totalSessionsCompleted, totalSetsCompleted, totalVolume, totalDurationMinutes
        case createdAt, updatedAt, syncStatus
        case notes, completionNotes
    }

    // MARK: - Computed Properties

    /// Progress percentage (0.0 - 1.0)
    var progressPercentage: Double {
        guard totalSessionsPlanned > 0 else { return 0 }
        return Double(totalSessionsCompleted) / Double(totalSessionsPlanned)
    }

    /// Week progress percentage (0.0 - 1.0)
    var weekProgressPercentage: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(currentWeek - 1) / Double(totalWeeks)
    }

    /// Formatted duration
    var formattedTotalDuration: String {
        let hours = totalDurationMinutes / 60
        let minutes = totalDurationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Formatted volume
    var formattedTotalVolume: String {
        if totalVolume >= 1_000_000 {
            return String(format: "%.1fM lbs", totalVolume / 1_000_000)
        } else if totalVolume >= 1000 {
            return String(format: "%.1fk lbs", totalVolume / 1000)
        }
        return String(format: "%.0f lbs", totalVolume)
    }

    /// Whether the program is still active
    var isActive: Bool {
        status == .inProgress
    }

    // MARK: - Mutating Methods

    /// Add a completed session to this program
    mutating func addSession(_ session: Session) {
        completedSessionIds.append(session.id)
        totalSessionsCompleted += 1
        totalSetsCompleted += session.totalSetsCompleted
        totalDurationMinutes += session.duration ?? 0

        // Calculate volume from session
        let sessionVolume = session.completedModules.reduce(0.0) { moduleTotal, module in
            moduleTotal + module.completedExercises.reduce(0.0) { $0 + $1.totalVolume }
        }
        totalVolume += sessionVolume

        updatedAt = Date()
    }

    /// Mark the program as completed
    mutating func markCompleted(notes: String? = nil) {
        status = .completed
        endDate = Date()
        completionNotes = notes
        updatedAt = Date()
    }

    /// Mark the program as abandoned
    mutating func markAbandoned(notes: String? = nil) {
        status = .abandoned
        endDate = Date()
        completionNotes = notes
        updatedAt = Date()
    }

    /// Advance to the next week
    mutating func advanceWeek() {
        if currentWeek < totalWeeks {
            currentWeek += 1
            updatedAt = Date()
        }
    }
}

// MARK: - Factory Method

extension CompletedProgram {
    /// Create a CompletedProgram from a Program template when the user starts it
    static func start(from program: Program) -> CompletedProgram {
        let targetEnd = program.startDate.flatMap { start in
            Calendar.current.date(byAdding: .weekOfYear, value: program.durationWeeks, to: start)
        }

        // Count planned sessions
        let plannedSessions = program.workoutSlots.count * program.durationWeeks

        return CompletedProgram(
            programId: program.id,
            programName: program.name,
            programDescription: program.programDescription,
            startDate: program.startDate ?? Date(),
            targetEndDate: targetEnd,
            totalWeeks: program.durationWeeks,
            totalSessionsPlanned: plannedSessions
        )
    }
}
