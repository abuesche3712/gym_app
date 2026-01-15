//
//  ScheduledWorkout.swift
//  gym app
//
//  A scheduled workout or rest day for a specific date
//

import Foundation

struct ScheduledWorkout: Identifiable, Codable, Hashable {
    var id: UUID
    var workoutId: UUID?  // nil for rest days
    var workoutName: String  // "Rest" for rest days
    var scheduledDate: Date
    var completedSessionId: UUID?  // Links to session if completed
    var isRestDay: Bool
    var notes: String?
    var createdAt: Date

    /// Initialize a scheduled workout
    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        scheduledDate: Date,
        completedSessionId: UUID? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.scheduledDate = scheduledDate
        self.completedSessionId = completedSessionId
        self.isRestDay = false
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Initialize a rest day
    init(
        id: UUID = UUID(),
        scheduledDate: Date,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.workoutId = nil
        self.workoutName = "Rest"
        self.scheduledDate = scheduledDate
        self.completedSessionId = nil
        self.isRestDay = true
        self.notes = notes
        self.createdAt = createdAt
    }

    var isCompleted: Bool {
        completedSessionId != nil || isRestDay
    }

    /// Check if this scheduled workout is for a specific date (ignoring time)
    func isScheduledFor(date: Date) -> Bool {
        Calendar.current.isDate(scheduledDate, inSameDayAs: date)
    }
}
