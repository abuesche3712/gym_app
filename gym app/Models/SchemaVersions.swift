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
//  2. When decoding, if `schemaVersion` is missing, it defaults to current version
//  3. When adding new required fields, bump the version and handle in decoder
//
//  ## When to Bump Version
//
//  - Adding a required field (non-optional without sensible default) -> bump version
//  - Removing a field -> bump version (need to handle old data that has it)
//  - Changing field type -> bump version
//  - Renaming a field -> bump version (old data uses old name)
//  - Adding optional field with default -> NO bump needed (use decodeIfPresent)
//

import Foundation

/// Central registry of current schema versions for all Codable models.
/// Increment these values when making breaking changes to model structures.
enum SchemaVersions {
    static let exerciseInstance = 1
    static let module = 1
    static let workout = 1
    static let session = 1
    static let program = 1
    static let setGroup = 1
    static let scheduledWorkout = 1
    static let completedProgram = 1
    static let userProfile = 1
    static let friendship = 1
    static let conversation = 1
    static let message = 1

    // Share bundles
    static let programShareBundle = 1
    static let workoutShareBundle = 1
    static let moduleShareBundle = 1
    static let sessionShareBundle = 1
    static let exerciseShareBundle = 1
    static let setShareBundle = 1
    static let completedModuleShareBundle = 1
    static let highlightsShareBundle = 1
    static let exerciseInstanceShareBundle = 1
    static let setGroupShareBundle = 1
    static let completedSetGroupShareBundle = 1

    // Social feed
    static let post = 1
    static let postLike = 1
    static let postComment = 1
}
