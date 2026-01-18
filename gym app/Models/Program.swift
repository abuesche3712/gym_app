//
//  Program.swift
//  gym app
//
//  A training program/block that contains scheduled workout slots
//

import Foundation

// MARK: - Program

struct Program: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.program

    var id: UUID
    var name: String
    var programDescription: String?
    var durationWeeks: Int
    var startDate: Date?
    var endDate: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var workoutSlots: [ProgramWorkoutSlot]

    init(
        id: UUID = UUID(),
        name: String,
        programDescription: String? = nil,
        durationWeeks: Int = 4,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync,
        workoutSlots: [ProgramWorkoutSlot] = []
    ) {
        self.id = id
        self.name = name
        self.programDescription = programDescription
        self.durationWeeks = durationWeeks
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.workoutSlots = workoutSlots
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode schema version (default to 1 for backward compatibility)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = SchemaVersions.program  // Always store current version

        // Handle migrations based on version
        switch version {
        case 1:
            // V1 is current - decode normally
            break
        default:
            // Unknown future version - attempt to decode with defaults
            break
        }

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        programDescription = try container.decodeIfPresent(String.self, forKey: .programDescription)
        durationWeeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks) ?? 4
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
        workoutSlots = try container.decodeIfPresent([ProgramWorkoutSlot].self, forKey: .workoutSlots) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, name, programDescription, durationWeeks, startDate, endDate, isActive, createdAt, updatedAt, syncStatus, workoutSlots
    }

    // MARK: - Computed Properties

    /// Computed end date based on start date and duration
    var computedEndDate: Date? {
        guard let start = startDate else { return nil }
        return Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: start)
    }

    /// Get slots for a specific day of week (0 = Sunday, 6 = Saturday)
    func slots(for dayOfWeek: Int) -> [ProgramWorkoutSlot] {
        workoutSlots
            .filter { $0.dayOfWeek == dayOfWeek && $0.scheduleType == .weekly }
            .sorted { $0.order < $1.order }
    }

    /// Get slots for a specific week and day (for programs with week-specific variations)
    func slots(forWeek weekNumber: Int, dayOfWeek: Int) -> [ProgramWorkoutSlot] {
        // First get weekly slots
        var slots = workoutSlots.filter {
            $0.scheduleType == .weekly && $0.dayOfWeek == dayOfWeek
        }

        // Then add/override with specific week slots
        let weekSpecificSlots = workoutSlots.filter {
            $0.scheduleType == .specificWeek &&
            $0.weekNumber == weekNumber &&
            $0.dayOfWeek == dayOfWeek
        }
        slots.append(contentsOf: weekSpecificSlots)

        return slots.sorted { $0.order < $1.order }
    }

    // MARK: - Slot Management

    mutating func addSlot(_ slot: ProgramWorkoutSlot) {
        workoutSlots.append(slot)
        updatedAt = Date()
    }

    mutating func removeSlot(_ slotId: UUID) {
        workoutSlots.removeAll { $0.id == slotId }
        updatedAt = Date()
    }

    mutating func updateSlot(_ slot: ProgramWorkoutSlot) {
        if let index = workoutSlots.firstIndex(where: { $0.id == slot.id }) {
            workoutSlots[index] = slot
            updatedAt = Date()
        }
    }

    // MARK: - Schedule Generation

    /// Generate ScheduledWorkout entries from program start date to end date
    func generateScheduledWorkouts(from startDate: Date) -> [ScheduledWorkout] {
        var scheduledWorkouts: [ScheduledWorkout] = []
        let calendar = Calendar.current

        // Normalize to start of day
        let normalizedStart = calendar.startOfDay(for: startDate)

        // Find the start of the week containing startDate
        let weekday = calendar.component(.weekday, from: normalizedStart)
        let daysFromSunday = weekday - 1
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromSunday, to: normalizedStart) else {
            return []
        }

        // Iterate through each week
        for weekIndex in 0..<durationWeeks {
            guard let currentWeekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: weekStart) else {
                continue
            }

            let weekNumber = weekIndex + 1  // 1-based week number

            // For each day of the week (0 = Sunday to 6 = Saturday)
            for dayOfWeek in 0...6 {
                guard let dateForDay = calendar.date(byAdding: .day, value: dayOfWeek, to: currentWeekStart) else {
                    continue
                }

                // Skip dates before the actual start date
                if dateForDay < normalizedStart {
                    continue
                }

                // Get slots for this day
                let slotsForDay = slots(forWeek: weekNumber, dayOfWeek: dayOfWeek)

                for slot in slotsForDay {
                    let scheduled = ScheduledWorkout(
                        workoutId: slot.workoutId,
                        workoutName: slot.workoutName,
                        scheduledDate: dateForDay,
                        notes: slot.notes,
                        programId: self.id,
                        programSlotId: slot.id
                    )
                    scheduledWorkouts.append(scheduled)
                }
            }
        }

        return scheduledWorkouts.sorted { $0.scheduledDate < $1.scheduledDate }
    }
}

// MARK: - Program Workout Slot

struct ProgramWorkoutSlot: Identifiable, Codable, Hashable {
    var id: UUID
    var workoutId: UUID
    var workoutName: String
    var scheduleType: SlotScheduleType
    var dayOfWeek: Int?       // 0 = Sunday, 6 = Saturday
    var weekNumber: Int?      // 1-based (for specificWeek type)
    var specificDateOffset: Int?  // Days from program start (for specificDate type)
    var order: Int
    var notes: String?

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        scheduleType: SlotScheduleType = .weekly,
        dayOfWeek: Int? = nil,
        weekNumber: Int? = nil,
        specificDateOffset: Int? = nil,
        order: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.scheduleType = scheduleType
        self.dayOfWeek = dayOfWeek
        self.weekNumber = weekNumber
        self.specificDateOffset = specificDateOffset
        self.order = order
        self.notes = notes
    }

    /// Create a weekly recurring slot
    static func weekly(
        workoutId: UUID,
        workoutName: String,
        dayOfWeek: Int,
        order: Int = 0,
        notes: String? = nil
    ) -> ProgramWorkoutSlot {
        ProgramWorkoutSlot(
            workoutId: workoutId,
            workoutName: workoutName,
            scheduleType: .weekly,
            dayOfWeek: dayOfWeek,
            order: order,
            notes: notes
        )
    }

    /// Create a slot for a specific week
    static func specificWeek(
        workoutId: UUID,
        workoutName: String,
        weekNumber: Int,
        dayOfWeek: Int,
        order: Int = 0,
        notes: String? = nil
    ) -> ProgramWorkoutSlot {
        ProgramWorkoutSlot(
            workoutId: workoutId,
            workoutName: workoutName,
            scheduleType: .specificWeek,
            dayOfWeek: dayOfWeek,
            weekNumber: weekNumber,
            order: order,
            notes: notes
        )
    }
}

// MARK: - Slot Schedule Type

enum SlotScheduleType: String, Codable, CaseIterable {
    case weekly = "weekly"
    case specificWeek = "specificWeek"
    case specificDate = "specificDate"

    var displayName: String {
        switch self {
        case .weekly: return "Every Week"
        case .specificWeek: return "Specific Week"
        case .specificDate: return "Specific Date"
        }
    }

    var description: String {
        switch self {
        case .weekly: return "Same workout every week on this day"
        case .specificWeek: return "Only during specific week(s)"
        case .specificDate: return "On a specific date in the program"
        }
    }
}

// MARK: - Day of Week Helper

extension Int {
    var dayOfWeekName: String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard self >= 0 && self < 7 else { return "Unknown" }
        return days[self]
    }

    var dayOfWeekShort: String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard self >= 0 && self < 7 else { return "?" }
        return days[self]
    }
}
