//
//  ExerciseInstance.swift
//  gym app
//
//  A lightweight reference to an exercise template, stored within modules.
//  Contains session-specific data like setGroups and optional overrides.
//

import Foundation

struct ExerciseInstance: Identifiable, Codable, Hashable {
    var id: UUID
    var templateId: UUID  // Required - links to ExerciseTemplate
    var setGroups: [SetGroup]
    var supersetGroupId: UUID?
    var order: Int
    var notes: String?

    // Optional overrides (rarely used - for edge cases)
    var nameOverride: String?
    var exerciseTypeOverride: ExerciseType?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        templateId: UUID,
        setGroups: [SetGroup] = [],
        supersetGroupId: UUID? = nil,
        order: Int = 0,
        notes: String? = nil,
        nameOverride: String? = nil,
        exerciseTypeOverride: ExerciseType? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.templateId = templateId
        self.setGroups = setGroups
        self.supersetGroupId = supersetGroupId
        self.order = order
        self.notes = notes
        self.nameOverride = nameOverride
        self.exerciseTypeOverride = exerciseTypeOverride
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether this instance is part of a superset
    var isInSuperset: Bool {
        supersetGroupId != nil
    }

    /// Total number of sets across all set groups
    var totalSets: Int {
        setGroups.reduce(0) { $0 + $1.sets }
    }

    /// Creates an instance from a template with default set groups
    static func from(template: ExerciseTemplate, order: Int = 0) -> ExerciseInstance {
        ExerciseInstance(
            templateId: template.id,
            setGroups: template.defaultSetGroups,
            order: order,
            notes: nil
        )
    }
}
