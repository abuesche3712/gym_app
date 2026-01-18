//
//  Workout.swift
//  gym app
//
//  A template combining multiple modules for a training session
//

import Foundation

struct Workout: Identifiable, Codable, Hashable {
    // Schema version for migration support
    var schemaVersion: Int = SchemaVersions.workout

    var id: UUID
    var name: String
    var moduleReferences: [ModuleReference]
    var standaloneExercises: [WorkoutExercise]  // Exercises added directly to workout
    var estimatedDuration: Int? // minutes
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archived: Bool
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        name: String,
        moduleReferences: [ModuleReference] = [],
        standaloneExercises: [WorkoutExercise] = [],
        estimatedDuration: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archived: Bool = false,
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.name = name
        self.moduleReferences = moduleReferences
        self.standaloneExercises = standaloneExercises
        self.estimatedDuration = estimatedDuration
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
        self.syncStatus = syncStatus
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode schema version (default to 1 for backward compatibility)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = SchemaVersions.workout  // Always store current version

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
        moduleReferences = try container.decodeIfPresent([ModuleReference].self, forKey: .moduleReferences) ?? []
        standaloneExercises = try container.decodeIfPresent([WorkoutExercise].self, forKey: .standaloneExercises) ?? []
        estimatedDuration = try container.decodeIfPresent(Int.self, forKey: .estimatedDuration)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, name, moduleReferences, standaloneExercises, estimatedDuration, notes, createdAt, updatedAt, archived, syncStatus
    }

    mutating func addModule(_ moduleId: UUID, isRequired: Bool = true) {
        let order = moduleReferences.count
        let reference = ModuleReference(moduleId: moduleId, order: order, isRequired: isRequired)
        moduleReferences.append(reference)
        updatedAt = Date()
    }

    mutating func removeModule(at index: Int) {
        moduleReferences.remove(at: index)
        // Reorder remaining modules
        for i in 0..<moduleReferences.count {
            moduleReferences[i].order = i
        }
        updatedAt = Date()
    }

    mutating func reorderModules(from source: IndexSet, to destination: Int) {
        moduleReferences.move(fromOffsets: source, toOffset: destination)
        // Update order values
        for i in 0..<moduleReferences.count {
            moduleReferences[i].order = i
        }
        updatedAt = Date()
    }

    // MARK: - Standalone Exercise Management

    mutating func addStandaloneExercise(_ exercise: Exercise) {
        let order = standaloneExercises.count
        let workoutExercise = WorkoutExercise(exercise: exercise, order: order)
        standaloneExercises.append(workoutExercise)
        updatedAt = Date()
    }

    mutating func removeStandaloneExercise(at index: Int) {
        standaloneExercises.remove(at: index)
        // Reorder remaining exercises
        for i in 0..<standaloneExercises.count {
            standaloneExercises[i].order = i
        }
        updatedAt = Date()
    }

    mutating func reorderStandaloneExercises(from source: IndexSet, to destination: Int) {
        standaloneExercises.move(fromOffsets: source, toOffset: destination)
        // Update order values
        for i in 0..<standaloneExercises.count {
            standaloneExercises[i].order = i
        }
        updatedAt = Date()
    }

    /// Whether this workout has any standalone exercises
    var hasStandaloneExercises: Bool {
        !standaloneExercises.isEmpty
    }

    // MARK: - Deep Merge Support

    /// Merges standalone exercises from a cloud workout, keeping the newer version of each.
    /// Module references use simple last-write-wins since they're just references.
    func mergedWith(_ cloudWorkout: Workout) -> Workout {
        var result = self

        // Determine which workout has newer metadata
        let useCloudMetadata = cloudWorkout.updatedAt >= self.updatedAt
        if useCloudMetadata {
            result.name = cloudWorkout.name
            result.notes = cloudWorkout.notes
            result.estimatedDuration = cloudWorkout.estimatedDuration
            result.archived = cloudWorkout.archived
            // Module references use simple replacement from newer source
            result.moduleReferences = cloudWorkout.moduleReferences
        }

        // Deep merge standalone exercises
        result.standaloneExercises = mergeWorkoutExerciseArrays(local: self.standaloneExercises, cloud: cloudWorkout.standaloneExercises)

        result.updatedAt = max(self.updatedAt, cloudWorkout.updatedAt)
        result.syncStatus = .synced

        return result
    }

    /// Merges two arrays of WorkoutExercise, keeping the newer version of each
    private func mergeWorkoutExerciseArrays(local: [WorkoutExercise], cloud: [WorkoutExercise]) -> [WorkoutExercise] {
        var merged: [UUID: WorkoutExercise] = [:]

        for we in local {
            merged[we.id] = we
        }

        for cloudWE in cloud {
            if let localWE = merged[cloudWE.id] {
                // Compare by embedded exercise's updatedAt
                if cloudWE.exercise.updatedAt > localWE.exercise.updatedAt {
                    merged[cloudWE.id] = cloudWE
                }
            } else {
                merged[cloudWE.id] = cloudWE
            }
        }

        return Array(merged.values).sorted { $0.order < $1.order }
    }

    /// Computes a hash of workout content for quick dirty-checking
    var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(notes)
        hasher.combine(estimatedDuration)
        hasher.combine(archived)

        for ref in moduleReferences.sorted(by: { $0.order < $1.order }) {
            hasher.combine(ref.moduleId)
            hasher.combine(ref.order)
        }

        for we in standaloneExercises.sorted(by: { $0.order < $1.order }) {
            hasher.combine(we.id)
            hasher.combine(we.exercise.id)
            hasher.combine(we.exercise.updatedAt)
        }

        return hasher.finalize()
    }

    func needsSync(comparedTo other: Workout) -> Bool {
        self.contentHash != other.contentHash
    }
}

// MARK: - Workout Exercise (Standalone)

/// An exercise added directly to a workout (not via a module)
struct WorkoutExercise: Identifiable, Codable, Hashable {
    var id: UUID
    var exercise: Exercise
    var order: Int
    var notes: String?

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        order: Int,
        notes: String? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.order = order
        self.notes = notes
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exercise = try container.decode(Exercise.self, forKey: .exercise)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exercise, order, notes
    }
}

// MARK: - Module Reference

struct ModuleReference: Identifiable, Codable, Hashable {
    var id: UUID
    var moduleId: UUID
    var order: Int
    var isRequired: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        moduleId: UUID,
        order: Int,
        isRequired: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.moduleId = moduleId
        self.order = order
        self.isRequired = isRequired
        self.notes = notes
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        moduleId = try container.decode(UUID.self, forKey: .moduleId)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? true
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, moduleId, order, isRequired, notes
    }
}

// MARK: - Sample Data

extension Workout {
    static func sampleWorkout(with modules: [Module]) -> Workout {
        var workout = Workout(
            name: "Monday - Lower A",
            estimatedDuration: 90,
            notes: "Main squat day, push top set"
        )

        for (index, module) in modules.enumerated() {
            workout.moduleReferences.append(
                ModuleReference(moduleId: module.id, order: index)
            )
        }

        return workout
    }
}
