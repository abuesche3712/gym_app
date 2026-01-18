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

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode schema version (default to 1 for backward compatibility)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = SchemaVersions.exerciseInstance  // Always store current version

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
        templateId = try container.decode(UUID.self, forKey: .templateId)
        setGroups = try container.decodeIfPresent([SetGroup].self, forKey: .setGroups) ?? []
        supersetGroupId = try container.decodeIfPresent(UUID.self, forKey: .supersetGroupId)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        nameOverride = try container.decodeIfPresent(String.self, forKey: .nameOverride)
        exerciseTypeOverride = try container.decodeIfPresent(ExerciseType.self, forKey: .exerciseTypeOverride)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, templateId, setGroups, supersetGroupId, order, notes, nameOverride, exerciseTypeOverride, createdAt, updatedAt
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
    /// Always stores nameOverride as a fallback in case template lookup fails
    static func from(template: ExerciseTemplate, order: Int = 0) -> ExerciseInstance {
        ExerciseInstance(
            templateId: template.id,
            setGroups: template.defaultSetGroups,
            order: order,
            notes: nil,
            nameOverride: template.name,  // Store name as backup
            exerciseTypeOverride: template.exerciseType  // Store type as backup
        )
    }
}
