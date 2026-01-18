//
//  SchemaVersions.swift
//  gym app
//
//  Central registry for Codable model schema versions.
//  Used to handle data migrations when model structures change.
//
//  ## How Schema Versioning Works
//
//  1. Each model has a `schemaVersion` property that is encoded/decoded
//  2. When decoding, if `schemaVersion` is missing, it defaults to 1 (backward compat)
//  3. The decoder switches on version to apply any necessary migrations
//  4. When adding new fields, bump the version and add migration logic
//
//  ## When to Bump Version
//
//  - Adding a required field (non-optional without sensible default) -> bump version
//  - Removing a field -> bump version (need to handle old data that has it)
//  - Changing field type -> bump version
//  - Renaming a field -> bump version (old data uses old name)
//  - Adding optional field with default -> NO bump needed (use decodeIfPresent)
//
//  ## Migration Example
//
//  When bumping from V1 to V2:
//  1. Update SchemaVersions.exercise = 2
//  2. In init(from decoder:), add case for version 2
//  3. Keep V1 case to handle old data
//  4. Add migrateExerciseFromV1() to convert old format to new
//

import Foundation

/// Central registry of current schema versions for all Codable models.
/// Increment these values when making breaking changes to model structures.
enum SchemaVersions {
    /// Exercise model version
    /// - V1: Initial version
    static let exercise = 1

    /// ExerciseInstance model version
    /// - V1: Initial version
    static let exerciseInstance = 1

    /// Module model version
    /// - V1: Initial version
    static let module = 1

    /// Workout model version
    /// - V1: Initial version
    static let workout = 1

    /// Session model version
    /// - V1: Initial version
    static let session = 1

    /// Program model version
    /// - V1: Initial version
    static let program = 1

    /// SetGroup model version
    /// - V1: Initial version
    static let setGroup = 1

    /// ScheduledWorkout model version
    /// - V1: Initial version
    static let scheduledWorkout = 1
}

// MARK: - Migration Protocols

/// Protocol for models that support schema migration
protocol SchemaMigratable {
    /// The current schema version for this model type
    static var currentSchemaVersion: Int { get }
}

// MARK: - Migration Stubs

/// Migration utilities for Exercise model
enum ExerciseMigrations {
    /// Migrate from V1 to current version
    /// Called when decoding data with schemaVersion = 1
    static func migrateFromV1(
        container: KeyedDecodingContainer<Exercise.CodingKeys>
    ) throws -> Exercise? {
        // V1 is current - no migration needed yet
        // When V2 is released, this will contain logic to transform V1 data
        return nil
    }
}

/// Migration utilities for ExerciseInstance model
enum ExerciseInstanceMigrations {
    /// Migrate from V1 to current version
    static func migrateFromV1(
        container: KeyedDecodingContainer<ExerciseInstance.CodingKeys>
    ) throws -> ExerciseInstance? {
        // V1 is current - no migration needed yet
        return nil
    }
}

/// Migration utilities for Module model
enum ModuleMigrations {
    /// Migrate from V1 to current version
    static func migrateFromV1(
        container: KeyedDecodingContainer<Module.CodingKeys>
    ) throws -> Module? {
        // V1 is current - no migration needed yet
        return nil
    }
}

/// Migration utilities for Workout model
enum WorkoutMigrations {
    /// Migrate from V1 to current version
    static func migrateFromV1(
        container: KeyedDecodingContainer<Workout.CodingKeys>
    ) throws -> Workout? {
        // V1 is current - no migration needed yet
        return nil
    }
}

/// Migration utilities for Session model
enum SessionMigrations {
    /// Migrate from V1 to current version
    static func migrateFromV1(
        container: KeyedDecodingContainer<Session.CodingKeys>
    ) throws -> Session? {
        // V1 is current - no migration needed yet
        return nil
    }
}

/// Migration utilities for Program model
enum ProgramMigrations {
    /// Migrate from V1 to current version
    static func migrateFromV1(
        container: KeyedDecodingContainer<Program.CodingKeys>
    ) throws -> Program? {
        // V1 is current - no migration needed yet
        return nil
    }
}
