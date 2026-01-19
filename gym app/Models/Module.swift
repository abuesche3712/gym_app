//
//  Module.swift
//  gym app
//
//  A reusable component of a workout
//

import Foundation

struct Module: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.module

    var id: UUID
    var name: String
    var type: ModuleType
    var exercises: [ExerciseInstance]  // Renamed from exerciseInstances
    var notes: String?
    var estimatedDuration: Int? // minutes
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        name: String,
        type: ModuleType,
        exercises: [ExerciseInstance] = [],
        notes: String? = nil,
        estimatedDuration: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.exercises = exercises
        self.notes = notes
        self.estimatedDuration = estimatedDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.module

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ModuleType.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        syncStatus = try container.decode(SyncStatus.self, forKey: .syncStatus)

        // Optional with defaults
        exercises = try container.decodeIfPresent([ExerciseInstance].self, forKey: .exercises) ?? []

        // Truly optional
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        estimatedDuration = try container.decodeIfPresent(Int.self, forKey: .estimatedDuration)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, name, type, exercises, notes, estimatedDuration, createdAt, updatedAt, syncStatus
    }

    // MARK: - Exercise Management

    mutating func addExercise(_ instance: ExerciseInstance) {
        // Validate before adding
        guard instance.isValid else {
            Logger.warning("Attempted to add invalid exercise: '\(instance.name)'")
            return
        }

        var newInstance = instance
        newInstance.order = exercises.count
        exercises.append(newInstance)
        updatedAt = Date()
    }

    mutating func removeExercise(at index: Int) {
        exercises.remove(at: index)
        // Reorder remaining instances
        for i in exercises.indices {
            exercises[i].order = i
        }
        updatedAt = Date()
    }

    mutating func updateExercise(_ instance: ExerciseInstance) {
        if let index = exercises.firstIndex(where: { $0.id == instance.id }) {
            exercises[index] = instance
            updatedAt = Date()
        }
    }

    /// Groups exercises by superset, maintaining original order
    var groupedExercises: [[ExerciseInstance]] {
        SupersetHelper.grouped(items: exercises.sorted(by: { $0.order < $1.order }))
    }

    /// Link exercises together as a superset
    mutating func createSuperset(exerciseIds: [UUID]) {
        guard exerciseIds.count >= 2 else { return }
        let supersetId = UUID()

        for i in exercises.indices {
            if exerciseIds.contains(exercises[i].id) {
                exercises[i].supersetGroupId = supersetId
            }
        }
        updatedAt = Date()
    }

    /// Remove an exercise from its superset
    mutating func breakSuperset(exerciseId: UUID) {
        if let index = exercises.firstIndex(where: { $0.id == exerciseId }) {
            exercises[index].supersetGroupId = nil
            updatedAt = Date()
        }
    }

    /// Break all exercises in a superset
    mutating func breakSupersetGroup(supersetGroupId: UUID) {
        for i in exercises.indices {
            if exercises[i].supersetGroupId == supersetGroupId {
                exercises[i].supersetGroupId = nil
            }
        }
        updatedAt = Date()
    }

    /// Resolves exercises using the ExerciseResolver
    /// Returns ResolvedExercise objects that combine instance + template data
    @MainActor
    func resolvedExercises(using resolver: ExerciseResolver? = nil) -> [ResolvedExercise] {
        let r = resolver ?? ExerciseResolver.shared
        return r.resolve(exercises)
    }

    /// Resolves exercises grouped by superset
    @MainActor
    func resolvedExercisesGrouped(using resolver: ExerciseResolver? = nil) -> [[ResolvedExercise]] {
        let r = resolver ?? ExerciseResolver.shared
        return r.resolveGrouped(exercises)
    }

    /// Cleans up orphaned superset IDs (exercises with a supersetGroupId that no other exercise shares)
    mutating func cleanupOrphanedSupersets() {
        let orphanedIds = SupersetHelper.orphanedSupersetIds(in: exercises)
        guard !orphanedIds.isEmpty else { return }

        for i in exercises.indices {
            if let supersetId = exercises[i].supersetGroupId, orphanedIds.contains(supersetId) {
                exercises[i].supersetGroupId = nil
            }
        }

        updatedAt = Date()
    }

    /// Number of exercises in this module
    var exerciseCount: Int {
        exercises.count
    }

    /// Whether this module has any exercises
    var hasExercises: Bool {
        !exercises.isEmpty
    }

    // MARK: - Deep Merge Support

    /// Merges exercises from a cloud module, keeping the newer version of each exercise.
    func mergedWith(_ cloudModule: Module) -> Module {
        var result = self

        // Determine which module has newer module-level changes
        let useCloudMetadata = cloudModule.updatedAt >= self.updatedAt
        if useCloudMetadata {
            result.name = cloudModule.name
            result.type = cloudModule.type
            result.notes = cloudModule.notes
            result.estimatedDuration = cloudModule.estimatedDuration
        }

        // Merge exercises by ID, keeping newer version of each
        result.exercises = mergeExerciseArrays(local: self.exercises, cloud: cloudModule.exercises)

        // Set updatedAt to the latest
        result.updatedAt = max(self.updatedAt, cloudModule.updatedAt)
        result.syncStatus = .synced

        return result
    }

    /// Merges two arrays of ExerciseInstance, keeping the newer version of each by ID
    private func mergeExerciseArrays(local: [ExerciseInstance], cloud: [ExerciseInstance]) -> [ExerciseInstance] {
        var merged: [UUID: ExerciseInstance] = [:]

        // Add all local instances
        for instance in local {
            merged[instance.id] = instance
        }

        // Merge cloud instances - keep newer version or add new ones
        for cloudInstance in cloud {
            if let localInstance = merged[cloudInstance.id] {
                if cloudInstance.updatedAt > localInstance.updatedAt {
                    merged[cloudInstance.id] = cloudInstance
                }
            } else {
                merged[cloudInstance.id] = cloudInstance
            }
        }

        // Return sorted by order field
        return Array(merged.values).sorted { $0.order < $1.order }
    }

    /// Computes a hash of all content for quick dirty-checking during sync.
    var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(notes)
        hasher.combine(estimatedDuration)

        for instance in exercises.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(instance.id)
            hasher.combine(instance.templateId)
            hasher.combine(instance.order)
            hasher.combine(instance.updatedAt)
            for setGroup in instance.setGroups {
                hasher.combine(setGroup.id)
                hasher.combine(setGroup.sets)
                hasher.combine(setGroup.targetReps)
                hasher.combine(setGroup.targetWeight)
            }
        }

        return hasher.finalize()
    }

    /// Returns true if this module needs to be synced
    func needsSync(comparedTo other: Module) -> Bool {
        self.contentHash != other.contentHash
    }
}

// MARK: - Sample Data

extension Module {
    static var sampleWarmup: Module {
        Module(
            name: "Standard Warmup",
            type: .warmup,
            exercises: [],  // Will be populated when templates exist
            estimatedDuration: 10
        )
    }

    static var samplePrehab: Module {
        Module(
            name: "Knee Care",
            type: .prehab,
            exercises: [],  // Will be populated when templates exist
            notes: "Do before every lower session",
            estimatedDuration: 10
        )
    }

    static var sampleStrength: Module {
        Module(
            name: "Lower Body A",
            type: .strength,
            exercises: [],  // Will be populated when templates exist
            estimatedDuration: 60
        )
    }

    static var sampleRecovery: Module {
        Module(
            name: "Post-Workout Recovery",
            type: .recovery,
            exercises: [],  // Will be populated when templates exist
            notes: "Complete after every workout",
            estimatedDuration: 20
        )
    }
}
