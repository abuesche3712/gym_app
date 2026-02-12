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
    var workoutSlots: [ProgramWorkoutSlot]  // Legacy workout-only slots
    var moduleSlots: [ProgramSlot]           // Unified slots (workouts and modules)

    // Progression configuration
    var progressionRules: [UUID: ProgressionRule]  // Keyed by ExerciseTemplate.id (legacy)
    var defaultProgressionRule: ProgressionRule?   // Fallback for exercises without specific rules
    var progressionEnabled: Bool                   // Global toggle for auto-progression
    var progressionPolicy: ProgressionPolicy       // Legacy or adaptive progression engine
    var progressionEnabledExercises: Set<UUID>     // ExerciseInstance IDs that get progression
    var exerciseProgressionOverrides: [UUID: ProgressionRule]  // Per-exercise custom rules
    var exerciseProgressionStates: [UUID: ExerciseProgressionState]  // Per-exercise stateful progression context

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
        workoutSlots: [ProgramWorkoutSlot] = [],
        moduleSlots: [ProgramSlot] = [],
        progressionRules: [UUID: ProgressionRule] = [:],
        defaultProgressionRule: ProgressionRule? = nil,
        progressionEnabled: Bool = false,
        progressionPolicy: ProgressionPolicy = .legacy,
        progressionEnabledExercises: Set<UUID> = [],
        exerciseProgressionOverrides: [UUID: ProgressionRule] = [:],
        exerciseProgressionStates: [UUID: ExerciseProgressionState] = [:]
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
        self.moduleSlots = moduleSlots
        self.progressionRules = progressionRules
        self.defaultProgressionRule = defaultProgressionRule
        self.progressionEnabled = progressionEnabled
        self.progressionPolicy = progressionPolicy
        self.progressionEnabledExercises = progressionEnabledExercises
        self.exerciseProgressionOverrides = exerciseProgressionOverrides
        self.exerciseProgressionStates = exerciseProgressionStates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.program

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Handle legacy field names: "created" -> "createdAt", "updated" -> "updatedAt"
        if let date = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else if let date = try container.decodeIfPresent(Date.self, forKey: .legacyCreated) {
            createdAt = date
        } else {
            createdAt = Date() // Fallback
        }

        if let date = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else if let date = try container.decodeIfPresent(Date.self, forKey: .legacyUpdated) {
            updatedAt = date
        } else {
            updatedAt = Date() // Fallback
        }

        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pendingSync

        // Handle legacy field name: "duration" -> "durationWeeks"
        if let weeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks) {
            durationWeeks = weeks
        } else if let weeks = try container.decodeIfPresent(Int.self, forKey: .legacyDuration) {
            durationWeeks = weeks
        } else {
            durationWeeks = 4 // Default
        }

        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        workoutSlots = try container.decodeIfPresent([ProgramWorkoutSlot].self, forKey: .workoutSlots) ?? []
        moduleSlots = try container.decodeIfPresent([ProgramSlot].self, forKey: .moduleSlots) ?? []

        // Truly optional
        programDescription = try container.decodeIfPresent(String.self, forKey: .programDescription)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)

        // Progression (optional with defaults for backward compatibility)
        // progressionRules can be either a dictionary [String: ProgressionRule] or an empty array []
        // Firebase may store empty dict as empty array, so handle both cases
        if let stringKeyedRules = try? container.decodeIfPresent([String: ProgressionRule].self, forKey: .progressionRules) {
            progressionRules = Dictionary(uniqueKeysWithValues: stringKeyedRules.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } else {
            progressionRules = [:]
        }
        defaultProgressionRule = try container.decodeIfPresent(ProgressionRule.self, forKey: .defaultProgressionRule)
        progressionEnabled = try container.decodeIfPresent(Bool.self, forKey: .progressionEnabled) ?? false
        progressionPolicy = try container.decodeIfPresent(ProgressionPolicy.self, forKey: .progressionPolicy) ?? .legacy

        // Per-exercise progression configuration (new fields with defaults for backward compatibility)
        if let enabledArray = try container.decodeIfPresent([String].self, forKey: .progressionEnabledExercises) {
            progressionEnabledExercises = Set(enabledArray.compactMap { UUID(uuidString: $0) })
        } else {
            progressionEnabledExercises = []
        }

        if let stringKeyedOverrides = try container.decodeIfPresent([String: ProgressionRule].self, forKey: .exerciseProgressionOverrides) {
            exerciseProgressionOverrides = Dictionary(uniqueKeysWithValues: stringKeyedOverrides.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } else {
            exerciseProgressionOverrides = [:]
        }

        if let stringKeyedStates = try container.decodeIfPresent([String: ExerciseProgressionState].self, forKey: .exerciseProgressionStates) {
            exerciseProgressionStates = Dictionary(uniqueKeysWithValues: stringKeyedStates.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        } else {
            exerciseProgressionStates = [:]
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case progressionRules, defaultProgressionRule, progressionEnabled, progressionPolicy
        case progressionEnabledExercises, exerciseProgressionOverrides, exerciseProgressionStates
        case id, name, programDescription, durationWeeks, startDate, endDate, isActive, createdAt, updatedAt, syncStatus, workoutSlots, moduleSlots
        // Legacy field names (for backward compatibility with old Firebase data)
        case legacyCreated = "created"
        case legacyDuration = "duration"
        case legacyUpdated = "updated"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(programDescription, forKey: .programDescription)
        try container.encode(durationWeeks, forKey: .durationWeeks)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(syncStatus, forKey: .syncStatus)
        try container.encode(workoutSlots, forKey: .workoutSlots)
        try container.encode(moduleSlots, forKey: .moduleSlots)

        // Encode UUID-keyed progressionRules as String-keyed
        let stringKeyedRules = Dictionary(uniqueKeysWithValues: progressionRules.map { ($0.key.uuidString, $0.value) })
        try container.encode(stringKeyedRules, forKey: .progressionRules)

        try container.encodeIfPresent(defaultProgressionRule, forKey: .defaultProgressionRule)
        try container.encode(progressionEnabled, forKey: .progressionEnabled)
        try container.encode(progressionPolicy, forKey: .progressionPolicy)

        // Encode progressionEnabledExercises as array of UUID strings
        let enabledArray = progressionEnabledExercises.map { $0.uuidString }
        try container.encode(enabledArray, forKey: .progressionEnabledExercises)

        // Encode UUID-keyed exerciseProgressionOverrides as String-keyed
        let stringKeyedOverrides = Dictionary(uniqueKeysWithValues: exerciseProgressionOverrides.map { ($0.key.uuidString, $0.value) })
        try container.encode(stringKeyedOverrides, forKey: .exerciseProgressionOverrides)

        // Encode UUID-keyed exerciseProgressionStates as String-keyed
        let stringKeyedStates = Dictionary(uniqueKeysWithValues: exerciseProgressionStates.map { ($0.key.uuidString, $0.value) })
        try container.encode(stringKeyedStates, forKey: .exerciseProgressionStates)
    }

    // MARK: - Progression

    /// Get the progression rule for a specific exercise template (legacy)
    /// Falls back to defaultProgressionRule if no specific rule exists
    func progressionRule(for templateId: UUID?) -> ProgressionRule? {
        guard progressionEnabled else { return nil }
        if let id = templateId, let rule = progressionRules[id] {
            return rule
        }
        return defaultProgressionRule
    }

    /// Check if an exercise instance has progression enabled
    func isProgressionEnabled(for exerciseInstanceId: UUID) -> Bool {
        guard progressionEnabled else { return false }
        return progressionEnabledExercises.contains(exerciseInstanceId)
    }

    /// Get the progression rule for a specific exercise instance
    /// Returns override if present, otherwise returns default rule
    func progressionRuleForExercise(_ exerciseInstanceId: UUID) -> ProgressionRule? {
        guard progressionEnabled, progressionEnabledExercises.contains(exerciseInstanceId) else {
            return nil
        }
        return exerciseProgressionOverrides[exerciseInstanceId] ?? defaultProgressionRule
    }

    /// Enable or disable progression for an exercise instance
    mutating func setProgressionEnabled(_ enabled: Bool, for exerciseInstanceId: UUID) {
        if enabled {
            progressionEnabledExercises.insert(exerciseInstanceId)
        } else {
            progressionEnabledExercises.remove(exerciseInstanceId)
            exerciseProgressionOverrides.removeValue(forKey: exerciseInstanceId)
            exerciseProgressionStates.removeValue(forKey: exerciseInstanceId)
        }
        updatedAt = Date()
    }

    /// Set a custom progression rule for an exercise instance
    mutating func setProgressionOverride(_ rule: ProgressionRule?, for exerciseInstanceId: UUID) {
        if let rule = rule {
            exerciseProgressionOverrides[exerciseInstanceId] = rule
        } else {
            exerciseProgressionOverrides.removeValue(forKey: exerciseInstanceId)
        }
        updatedAt = Date()
    }

    /// Get persisted progression state for a specific exercise instance
    func progressionState(for exerciseInstanceId: UUID) -> ExerciseProgressionState? {
        exerciseProgressionStates[exerciseInstanceId]
    }

    /// Set progression state for a specific exercise instance
    mutating func setProgressionState(_ state: ExerciseProgressionState?, for exerciseInstanceId: UUID) {
        if let state {
            exerciseProgressionStates[exerciseInstanceId] = state
        } else {
            exerciseProgressionStates.removeValue(forKey: exerciseInstanceId)
        }
        updatedAt = Date()
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

    // MARK: - Unified Slot Management (for both workouts and modules)

    /// Get all unified slots for a specific day of week
    func unifiedSlots(for dayOfWeek: Int) -> [ProgramSlot] {
        moduleSlots
            .filter { $0.dayOfWeek == dayOfWeek && $0.scheduleType == .weekly }
            .sorted { $0.order < $1.order }
    }

    /// Get all unified slots for a specific week and day
    func unifiedSlots(forWeek weekNumber: Int, dayOfWeek: Int) -> [ProgramSlot] {
        var result = moduleSlots.filter {
            $0.scheduleType == .weekly && $0.dayOfWeek == dayOfWeek
        }

        let weekSpecific = moduleSlots.filter {
            $0.scheduleType == .specificWeek &&
            $0.weekNumber == weekNumber &&
            $0.dayOfWeek == dayOfWeek
        }
        result.append(contentsOf: weekSpecific)

        return result.sorted { $0.order < $1.order }
    }

    mutating func addModuleSlot(_ slot: ProgramSlot) {
        moduleSlots.append(slot)
        updatedAt = Date()
    }

    mutating func removeModuleSlot(_ slotId: UUID) {
        moduleSlots.removeAll { $0.id == slotId }
        updatedAt = Date()
    }

    mutating func updateModuleSlot(_ slot: ProgramSlot) {
        if let index = moduleSlots.firstIndex(where: { $0.id == slot.id }) {
            moduleSlots[index] = slot
            updatedAt = Date()
        }
    }

    /// Combined view of all slots (both legacy workoutSlots and new moduleSlots) for display
    func allSlotsForDay(_ dayOfWeek: Int) -> [ProgramSlot] {
        // Convert legacy workout slots to unified format
        let legacyAsUnified = workoutSlots
            .filter { $0.dayOfWeek == dayOfWeek && $0.scheduleType == .weekly }
            .map { legacy in
                ProgramSlot(
                    id: legacy.id,
                    content: .workout(id: legacy.workoutId, name: legacy.workoutName),
                    scheduleType: legacy.scheduleType,
                    dayOfWeek: legacy.dayOfWeek,
                    weekNumber: legacy.weekNumber,
                    specificDateOffset: legacy.specificDateOffset,
                    order: legacy.order,
                    notes: legacy.notes
                )
            }

        // Get new unified slots
        let unified = unifiedSlots(for: dayOfWeek)

        // Combine and sort
        return (legacyAsUnified + unified).sorted { $0.order < $1.order }
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

// MARK: - Program Slot Content (Workout or Module)

enum ProgramSlotContent: Codable, Hashable {
    case workout(id: UUID, name: String)
    case module(id: UUID, name: String, type: ModuleType)

    var displayName: String {
        switch self {
        case .workout(_, let name), .module(_, let name, _):
            return name
        }
    }

    var id: UUID {
        switch self {
        case .workout(let id, _), .module(let id, _, _):
            return id
        }
    }

    var isWorkout: Bool {
        if case .workout = self { return true }
        return false
    }

    var isModule: Bool {
        if case .module = self { return true }
        return false
    }

    var moduleType: ModuleType? {
        if case .module(_, _, let type) = self { return type }
        return nil
    }
}

// MARK: - Program Slot (Unified Workout or Module Slot)

struct ProgramSlot: Identifiable, Codable, Hashable {
    var id: UUID
    var content: ProgramSlotContent
    var scheduleType: SlotScheduleType
    var dayOfWeek: Int?       // 0 = Sunday, 6 = Saturday
    var weekNumber: Int?      // 1-based (for specificWeek type)
    var specificDateOffset: Int?  // Days from program start (for specificDate type)
    var order: Int
    var notes: String?

    init(
        id: UUID = UUID(),
        content: ProgramSlotContent,
        scheduleType: SlotScheduleType = .weekly,
        dayOfWeek: Int? = nil,
        weekNumber: Int? = nil,
        specificDateOffset: Int? = nil,
        order: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.content = content
        self.scheduleType = scheduleType
        self.dayOfWeek = dayOfWeek
        self.weekNumber = weekNumber
        self.specificDateOffset = specificDateOffset
        self.order = order
        self.notes = notes
    }

    var displayName: String {
        content.displayName
    }

    var isWorkout: Bool {
        content.isWorkout
    }

    var isModule: Bool {
        content.isModule
    }

    /// Create a weekly recurring workout slot
    static func weeklyWorkout(
        workoutId: UUID,
        workoutName: String,
        dayOfWeek: Int,
        order: Int = 0,
        notes: String? = nil
    ) -> ProgramSlot {
        ProgramSlot(
            content: .workout(id: workoutId, name: workoutName),
            scheduleType: .weekly,
            dayOfWeek: dayOfWeek,
            order: order,
            notes: notes
        )
    }

    /// Create a weekly recurring module slot
    static func weeklyModule(
        moduleId: UUID,
        moduleName: String,
        moduleType: ModuleType,
        dayOfWeek: Int,
        order: Int = 0,
        notes: String? = nil
    ) -> ProgramSlot {
        ProgramSlot(
            content: .module(id: moduleId, name: moduleName, type: moduleType),
            scheduleType: .weekly,
            dayOfWeek: dayOfWeek,
            order: order,
            notes: notes
        )
    }
}
