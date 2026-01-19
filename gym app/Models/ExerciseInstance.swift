//
//  ExerciseInstance.swift
//  gym app
//
//  A lightweight reference to an exercise template, stored within modules.
//  Contains session-specific data like setGroups and optional overrides.
//

import Foundation

struct ExerciseInstance: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.exerciseInstance

    var id: UUID
    var templateId: UUID  // Required - links to ExerciseTemplate
    var setGroups: [SetGroup]
    var supersetGroupId: UUID?
    var order: Int
    var notes: String?

    // Optional name override (for when user wants a different display name)
    var nameOverride: String?

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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.exerciseInstance

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        templateId = try container.decode(UUID.self, forKey: .templateId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Optional with defaults
        setGroups = try container.decodeIfPresent([SetGroup].self, forKey: .setGroups) ?? []
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0

        // Truly optional
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        nameOverride = try container.decodeIfPresent(String.self, forKey: .nameOverride)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, templateId, setGroups, supersetGroupId, order, notes, nameOverride
        case createdAt, updatedAt
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
            order: order
        )
    }
}
