//
//  UserProfile.swift
//  gym app
//
//  User profile with preferences and social features
//

import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var schemaVersion: Int = SchemaVersions.userProfile
    var id: UUID

    // Social identity
    var username: String  // unique, 1-32 chars, lowercase, [a-z0-9._-]
    var displayName: String?
    var bio: String?  // max 160 chars
    var isPublic: Bool

    // Settings/preferences
    var weightUnit: WeightUnit
    var distanceUnit: DistanceUnit
    var defaultRestTime: Int

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Sync
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        username: String = "",
        displayName: String? = nil,
        bio: String? = nil,
        isPublic: Bool = false,
        weightUnit: WeightUnit = .lbs,
        distanceUnit: DistanceUnit = .miles,
        defaultRestTime: Int = 90,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.isPublic = isPublic
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.defaultRestTime = defaultRestTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.userProfile
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()

        // Social identity (with defaults for migration from old profiles)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false

        // Settings
        weightUnit = try container.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .lbs
        distanceUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .miles
        defaultRestTime = try container.decodeIfPresent(Int.self, forKey: .defaultRestTime) ?? 90

        // Timestamps
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // Sync
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pendingSync
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, username, displayName, bio, isPublic
        case weightUnit, distanceUnit, defaultRestTime
        case createdAt, updatedAt, syncStatus
    }
}
