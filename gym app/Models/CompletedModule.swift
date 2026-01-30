//
//  CompletedModule.swift
//  gym app
//
//  A completed module from a workout session containing logged exercises
//

import Foundation

struct CompletedModule: Identifiable, Codable, Hashable {
    var id: UUID
    var moduleId: UUID
    var moduleName: String // Denormalized
    var moduleType: ModuleType
    var completedExercises: [SessionExercise]
    var skipped: Bool
    var notes: String?

    // Sharing context (denormalized for standalone sharing)
    var sessionId: UUID?
    var workoutId: UUID?
    var workoutName: String?
    var date: Date?

    init(
        id: UUID = UUID(),
        moduleId: UUID,
        moduleName: String,
        moduleType: ModuleType,
        completedExercises: [SessionExercise] = [],
        skipped: Bool = false,
        notes: String? = nil,
        sessionId: UUID? = nil,
        workoutId: UUID? = nil,
        workoutName: String? = nil,
        date: Date? = nil
    ) {
        self.id = id
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.moduleType = moduleType
        self.completedExercises = completedExercises
        self.skipped = skipped
        self.notes = notes
        self.sessionId = sessionId
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        moduleId = try container.decode(UUID.self, forKey: .moduleId)
        moduleName = try container.decode(String.self, forKey: .moduleName)
        moduleType = try container.decode(ModuleType.self, forKey: .moduleType)

        // Optional with defaults
        completedExercises = try container.decodeIfPresent([SessionExercise].self, forKey: .completedExercises) ?? []
        skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped) ?? false

        // Truly optional
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Sharing context (optional - populated when needed for sharing)
        sessionId = try container.decodeIfPresent(UUID.self, forKey: .sessionId)
        workoutId = try container.decodeIfPresent(UUID.self, forKey: .workoutId)
        workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
    }

    private enum CodingKeys: String, CodingKey {
        case id, moduleId, moduleName, moduleType, completedExercises, skipped, notes
        case sessionId, workoutId, workoutName, date
    }
}
