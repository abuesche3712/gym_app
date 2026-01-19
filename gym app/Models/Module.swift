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
    var exercises: [Exercise]  // Legacy - kept for backward compatibility
    var exerciseInstances: [ExerciseInstance]  // New normalized model
    var notes: String?
    var estimatedDuration: Int? // minutes
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        name: String,
        type: ModuleType,
        exercises: [Exercise] = [],
        exerciseInstances: [ExerciseInstance] = [],
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
        self.exerciseInstances = exerciseInstances
        self.notes = notes
        self.estimatedDuration = estimatedDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }

    // Custom decoder to handle missing fields from older Firebase documents
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode schema version (default to 1 for backward compatibility)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = SchemaVersions.module  // Always store current version

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
        type = try container.decode(ModuleType.self, forKey: .type)
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        exerciseInstances = try container.decodeIfPresent([ExerciseInstance].self, forKey: .exerciseInstances) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        estimatedDuration = try container.decodeIfPresent(Int.self, forKey: .estimatedDuration)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id, name, type, exercises, exerciseInstances, notes, estimatedDuration, createdAt, updatedAt, syncStatus
    }

    mutating func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
        updatedAt = Date()
    }

    mutating func removeExercise(at index: Int) {
        exercises.remove(at: index)
        updatedAt = Date()
    }

    mutating func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            updatedAt = Date()
        }
    }

    /// Groups exercises by superset, maintaining original order
    /// Non-superset exercises are single-item arrays
    var groupedExercises: [[Exercise]] {
        var groups: [[Exercise]] = []
        var processedIds: Set<UUID> = []

        for exercise in exercises {
            guard !processedIds.contains(exercise.id) else { continue }

            if let supersetId = exercise.supersetGroupId {
                // Find all exercises in this superset
                let supersetExercises = exercises.filter { $0.supersetGroupId == supersetId }
                groups.append(supersetExercises)
                supersetExercises.forEach { processedIds.insert($0.id) }
            } else {
                // Single exercise (not in a superset)
                groups.append([exercise])
                processedIds.insert(exercise.id)
            }
        }

        return groups
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

    // MARK: - ExerciseInstance Methods (New Normalized Model)

    mutating func addExerciseInstance(_ instance: ExerciseInstance) {
        var newInstance = instance
        newInstance.order = exerciseInstances.count
        exerciseInstances.append(newInstance)
        updatedAt = Date()
    }

    mutating func removeExerciseInstance(at index: Int) {
        exerciseInstances.remove(at: index)
        // Reorder remaining instances
        for i in exerciseInstances.indices {
            exerciseInstances[i].order = i
        }
        updatedAt = Date()
    }

    mutating func updateExerciseInstance(_ instance: ExerciseInstance) {
        if let index = exerciseInstances.firstIndex(where: { $0.id == instance.id }) {
            exerciseInstances[index] = instance
            updatedAt = Date()
        }
    }

    /// Groups exercise instances by superset, maintaining original order
    var groupedExerciseInstances: [[ExerciseInstance]] {
        var groups: [[ExerciseInstance]] = []
        var processedIds: Set<UUID> = []

        for instance in exerciseInstances.sorted(by: { $0.order < $1.order }) {
            guard !processedIds.contains(instance.id) else { continue }

            if let supersetId = instance.supersetGroupId {
                // Find all instances in this superset
                let supersetInstances = exerciseInstances.filter { $0.supersetGroupId == supersetId }
                    .sorted(by: { $0.order < $1.order })
                groups.append(supersetInstances)
                supersetInstances.forEach { processedIds.insert($0.id) }
            } else {
                // Single instance (not in a superset)
                groups.append([instance])
                processedIds.insert(instance.id)
            }
        }

        return groups
    }

    /// Link exercise instances together as a superset
    mutating func createInstanceSuperset(instanceIds: [UUID]) {
        guard instanceIds.count >= 2 else { return }
        let supersetId = UUID()

        for i in exerciseInstances.indices {
            if instanceIds.contains(exerciseInstances[i].id) {
                exerciseInstances[i].supersetGroupId = supersetId
            }
        }
        updatedAt = Date()
    }

    /// Remove an exercise instance from its superset
    mutating func breakInstanceSuperset(instanceId: UUID) {
        if let index = exerciseInstances.firstIndex(where: { $0.id == instanceId }) {
            exerciseInstances[index].supersetGroupId = nil
            updatedAt = Date()
        }
    }

    /// Break all exercise instances in a superset
    mutating func breakInstanceSupersetGroup(supersetGroupId: UUID) {
        for i in exerciseInstances.indices {
            if exerciseInstances[i].supersetGroupId == supersetGroupId {
                exerciseInstances[i].supersetGroupId = nil
            }
        }
        updatedAt = Date()
    }

    /// Resolves exercise instances using the ExerciseResolver
    /// Returns ResolvedExercise objects that combine instance + template data
    /// Note: Must be called from MainActor context since ExerciseResolver is MainActor-isolated
    @MainActor
    func resolvedExercises(using resolver: ExerciseResolver? = nil) -> [ResolvedExercise] {
        let r = resolver ?? ExerciseResolver.shared
        return r.resolve(exerciseInstances)
    }

    /// Resolves exercise instances grouped by superset
    /// Note: Must be called from MainActor context since ExerciseResolver is MainActor-isolated
    @MainActor
    func resolvedExercisesGrouped(using resolver: ExerciseResolver? = nil) -> [[ResolvedExercise]] {
        let r = resolver ?? ExerciseResolver.shared
        return r.resolveGrouped(exerciseInstances)
    }

    // MARK: - Unified Superset Methods (Works with either model)

    /// Creates a superset from exercise IDs, using the appropriate model
    mutating func createSupersetUnified(exerciseIds: [UUID]) {
        if usesNormalizedModel {
            createInstanceSuperset(instanceIds: exerciseIds)
        } else {
            createSuperset(exerciseIds: exerciseIds)
        }
    }

    /// Breaks a single exercise from its superset, using the appropriate model
    mutating func breakSupersetUnified(exerciseId: UUID) {
        if usesNormalizedModel {
            breakInstanceSuperset(instanceId: exerciseId)
        } else {
            breakSuperset(exerciseId: exerciseId)
        }
    }

    /// Breaks all exercises in a superset group, using the appropriate model
    mutating func breakSupersetGroupUnified(supersetGroupId: UUID) {
        if usesNormalizedModel {
            breakInstanceSupersetGroup(supersetGroupId: supersetGroupId)
        } else {
            breakSupersetGroup(supersetGroupId: supersetGroupId)
        }
    }

    /// Cleans up orphaned superset IDs (exercises with a supersetGroupId that no other exercise shares)
    /// This fixes data corruption where an exercise appears to be in a superset but is actually alone
    mutating func cleanupOrphanedSupersets() {
        var changed = false

        // Cleanup legacy exercises
        var supersetCounts: [UUID: Int] = [:]
        for exercise in exercises {
            if let supersetId = exercise.supersetGroupId {
                supersetCounts[supersetId, default: 0] += 1
            }
        }

        for i in exercises.indices {
            if let supersetId = exercises[i].supersetGroupId,
               supersetCounts[supersetId] ?? 0 < 2 {
                exercises[i].supersetGroupId = nil
                changed = true
            }
        }

        // Cleanup exercise instances
        var instanceSupersetCounts: [UUID: Int] = [:]
        for instance in exerciseInstances {
            if let supersetId = instance.supersetGroupId {
                instanceSupersetCounts[supersetId, default: 0] += 1
            }
        }

        for i in exerciseInstances.indices {
            if let supersetId = exerciseInstances[i].supersetGroupId,
               instanceSupersetCounts[supersetId] ?? 0 < 2 {
                exerciseInstances[i].supersetGroupId = nil
                changed = true
            }
        }

        if changed {
            updatedAt = Date()
        }
    }

    /// Returns grouped exercises using the appropriate model
    /// Must be called from MainActor context since ExerciseResolver may be needed
    @MainActor
    var groupedExercisesUnified: [[Exercise]] {
        if usesNormalizedModel {
            // Convert resolved exercise instances to legacy Exercise for UI
            let resolved = resolvedExercises()
            var groups: [[Exercise]] = []
            var processedIds: Set<UUID> = []

            for resolvedExercise in resolved {
                guard !processedIds.contains(resolvedExercise.id) else { continue }

                if let supersetId = resolvedExercise.supersetGroupId {
                    let supersetExercises = resolved
                        .filter { $0.supersetGroupId == supersetId }
                        .map { $0.toLegacyExercise() }
                    groups.append(supersetExercises)
                    resolved.filter { $0.supersetGroupId == supersetId }.forEach { processedIds.insert($0.id) }
                } else {
                    groups.append([resolvedExercise.toLegacyExercise()])
                    processedIds.insert(resolvedExercise.id)
                }
            }
            return groups
        }
        return groupedExercises
    }

    /// Whether this module uses the new normalized model
    var usesNormalizedModel: Bool {
        !exerciseInstances.isEmpty
    }

    /// Whether this module uses the legacy model
    var usesLegacyModel: Bool {
        !exercises.isEmpty && exerciseInstances.isEmpty
    }

    /// Number of exercises in this module (works with either storage model)
    var exerciseCount: Int {
        if usesNormalizedModel {
            return exerciseInstances.count
        }
        return exercises.count
    }

    /// Whether this module has any exercises (works with either storage model)
    var hasExercises: Bool {
        exerciseCount > 0
    }

    // MARK: - Unified Exercise Access

    /// Returns all exercises as legacy Exercise objects, regardless of storage model.
    /// - If using normalized model: resolves instances and converts to Exercise
    /// - If using legacy model: returns exercises directly
    /// - Falls back to legacy exercises if:
    ///   - Resolution fails (returns "Unknown Exercise")
    ///   - Legacy model has more exercises (partial migration)
    /// Must be called from MainActor context since ExerciseResolver is MainActor-isolated.
    @MainActor
    func allExercisesAsLegacy(using resolver: ExerciseResolver? = nil) -> [Exercise] {
        if usesNormalizedModel {
            let r = resolver ?? ExerciseResolver.shared
            let resolved = r.resolve(exerciseInstances).map { $0.toLegacyExercise() }

            // Check if resolution failed (any "Unknown Exercise" names)
            let hasUnknown = resolved.contains { $0.name == "Unknown Exercise" }

            // Fall back to legacy exercises if we have them and resolution failed
            if hasUnknown && !exercises.isEmpty {
                Logger.warning("Module '\(name)': Falling back to legacy exercises due to resolution failure")
                return exercises
            }

            // Fall back to legacy if it has more exercises (partial migration)
            if exercises.count > resolved.count {
                Logger.warning("Module '\(name)': Falling back to legacy exercises (\(exercises.count) vs \(resolved.count) normalized)")
                return exercises
            }

            return resolved
        }
        return exercises
    }

    /// Returns all exercises as ResolvedExercise objects, regardless of storage model.
    /// - If using normalized model: resolves instances
    /// - If using legacy model: converts exercises to ResolvedExercise (via synthetic instances)
    /// Must be called from MainActor context since ExerciseResolver is MainActor-isolated.
    @MainActor
    func allExercisesResolved(using resolver: ExerciseResolver? = nil) -> [ResolvedExercise] {
        let r = resolver ?? ExerciseResolver.shared
        if usesNormalizedModel {
            return r.resolve(exerciseInstances)
        }
        // Convert legacy exercises to ResolvedExercise by creating synthetic instances
        return exercises.map { exercise in
            let syntheticInstance = ExerciseInstance(
                id: exercise.id,
                templateId: exercise.templateId ?? UUID(),  // Use existing templateId if available
                setGroups: exercise.setGroups,
                supersetGroupId: exercise.supersetGroupId,
                order: 0,
                notes: exercise.notes,
                nameOverride: exercise.name,
                exerciseTypeOverride: exercise.exerciseType
            )
            // Resolve with nil template since legacy exercises have all data inline
            return syntheticInstance.resolved(with: nil)
        }
    }

    // MARK: - Deep Merge Support

    /// Merges exercises from a cloud module, keeping the newer version of each exercise.
    /// This enables conflict resolution when different exercises are edited on different devices.
    /// - Parameter cloudModule: The module from cloud to merge from
    /// - Returns: A new module with merged exercises and the latest module-level metadata
    func mergedWith(_ cloudModule: Module) -> Module {
        var result = self

        // Determine which module has newer module-level changes (name, type, notes, duration)
        let useCloudMetadata = cloudModule.updatedAt >= self.updatedAt
        if useCloudMetadata {
            result.name = cloudModule.name
            result.type = cloudModule.type
            result.notes = cloudModule.notes
            result.estimatedDuration = cloudModule.estimatedDuration
        }

        // Merge legacy exercises by ID, keeping newer version of each
        result.exercises = mergeExerciseArrays(local: self.exercises, cloud: cloudModule.exercises)

        // Merge exercise instances by ID, keeping newer version of each
        result.exerciseInstances = mergeExerciseInstanceArrays(local: self.exerciseInstances, cloud: cloudModule.exerciseInstances)

        // Set updatedAt to the latest of either module or any nested entity
        result.updatedAt = max(self.updatedAt, cloudModule.updatedAt)
        result.syncStatus = .synced

        return result
    }

    /// Merges two arrays of legacy Exercise, keeping the newer version of each by ID
    private func mergeExerciseArrays(local: [Exercise], cloud: [Exercise]) -> [Exercise] {
        var merged: [UUID: Exercise] = [:]

        // Add all local exercises
        for exercise in local {
            merged[exercise.id] = exercise
        }

        // Merge cloud exercises - keep newer version or add new ones
        for cloudExercise in cloud {
            if let localExercise = merged[cloudExercise.id] {
                // Keep the newer one
                if cloudExercise.updatedAt > localExercise.updatedAt {
                    merged[cloudExercise.id] = cloudExercise
                }
                // If local is newer or same, keep local (already in merged)
            } else {
                // New from cloud - add it
                merged[cloudExercise.id] = cloudExercise
            }
        }

        // Return sorted by some stable order (use order if available, otherwise creation date)
        return Array(merged.values).sorted { $0.createdAt < $1.createdAt }
    }

    /// Merges two arrays of ExerciseInstance, keeping the newer version of each by ID
    private func mergeExerciseInstanceArrays(local: [ExerciseInstance], cloud: [ExerciseInstance]) -> [ExerciseInstance] {
        var merged: [UUID: ExerciseInstance] = [:]

        // Add all local instances
        for instance in local {
            merged[instance.id] = instance
        }

        // Merge cloud instances - keep newer version or add new ones
        for cloudInstance in cloud {
            if let localInstance = merged[cloudInstance.id] {
                // Keep the newer one
                if cloudInstance.updatedAt > localInstance.updatedAt {
                    merged[cloudInstance.id] = cloudInstance
                }
                // If local is newer or same, keep local (already in merged)
            } else {
                // New from cloud - add it
                merged[cloudInstance.id] = cloudInstance
            }
        }

        // Return sorted by order field
        return Array(merged.values).sorted { $0.order < $1.order }
    }

    /// Computes a hash of all content for quick dirty-checking during sync.
    /// If two modules have the same contentHash, they have identical content.
    var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(notes)
        hasher.combine(estimatedDuration)

        // Hash legacy exercises
        for exercise in exercises.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(exercise.id)
            hasher.combine(exercise.name)
            hasher.combine(exercise.exerciseType)
            hasher.combine(exercise.updatedAt)
            // Hash set groups
            for setGroup in exercise.setGroups {
                hasher.combine(setGroup.id)
                hasher.combine(setGroup.sets)
                hasher.combine(setGroup.targetReps)
                hasher.combine(setGroup.targetWeight)
            }
        }

        // Hash exercise instances
        for instance in exerciseInstances.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(instance.id)
            hasher.combine(instance.templateId)
            hasher.combine(instance.order)
            hasher.combine(instance.updatedAt)
            // Hash set groups
            for setGroup in instance.setGroups {
                hasher.combine(setGroup.id)
                hasher.combine(setGroup.sets)
                hasher.combine(setGroup.targetReps)
                hasher.combine(setGroup.targetWeight)
            }
        }

        return hasher.finalize()
    }

    /// Returns true if this module needs to be synced (has changes compared to another version)
    func needsSync(comparedTo other: Module) -> Bool {
        self.contentHash != other.contentHash
    }
}

// MARK: - Sample Data

extension Module {
    static let sampleWarmup = Module(
        name: "Standard Warmup",
        type: .warmup,
        exercises: [
            Exercise(name: "Light Jog", exerciseType: .cardio, setGroups: [
                SetGroup(sets: 1, targetDuration: 300, notes: "5 minutes easy")
            ]),
            Exercise(name: "Leg Swings", exerciseType: .mobility, setGroups: [
                SetGroup(sets: 1, targetReps: 10, notes: "Each direction")
            ]),
            Exercise(name: "Hip Circles", exerciseType: .mobility, setGroups: [
                SetGroup(sets: 1, targetReps: 10, notes: "Each direction")
            ])
        ],
        estimatedDuration: 10
    )

    static let samplePrehab = Module(
        name: "Knee Care",
        type: .prehab,
        exercises: [
            Exercise(name: "VMO Iso Hold", exerciseType: .isometric, setGroups: [
                SetGroup(sets: 3, targetHoldTime: 30, restPeriod: 30)
            ]),
            Exercise(name: "Terminal Knee Extensions", exerciseType: .strength, setGroups: [
                SetGroup(sets: 2, targetReps: 15, restPeriod: 60, notes: "Banded")
            ])
        ],
        notes: "Do before every lower session",
        estimatedDuration: 10
    )

    static let sampleStrength = Module(
        name: "Lower Body A",
        type: .strength,
        exercises: [
            Exercise(name: "Back Squat", exerciseType: .strength, setGroups: [
                SetGroup(sets: 1, targetReps: 3, targetRPE: 8, restPeriod: 240, notes: "Top set"),
                SetGroup(sets: 3, targetReps: 6, restPeriod: 180, notes: "Back-off sets")
            ]),
            Exercise(name: "Romanian Deadlift", exerciseType: .strength, setGroups: [
                SetGroup(sets: 4, targetReps: 8, restPeriod: 120)
            ]),
            Exercise(name: "Bulgarian Split Squat", exerciseType: .strength, setGroups: [
                SetGroup(sets: 3, targetReps: 10, restPeriod: 90, notes: "Each leg")
            ])
        ],
        estimatedDuration: 60
    )

    static let sampleRecovery = Module(
        name: "Post-Workout Recovery",
        type: .recovery,
        exercises: [
            Exercise(
                name: "Cool Down Walk",
                exerciseType: .recovery,
                setGroups: [SetGroup(sets: 1, targetDuration: 300)],
                recoveryActivityType: .cooldown
            ),
            Exercise(
                name: "Foam Rolling",
                exerciseType: .recovery,
                setGroups: [SetGroup(sets: 1, targetDuration: 600)],
                notes: "Focus on quads, hamstrings, glutes",
                recoveryActivityType: .foamRolling
            ),
            Exercise(
                name: "Static Stretching",
                exerciseType: .recovery,
                setGroups: [SetGroup(sets: 1, targetDuration: 300)],
                notes: "Hold each stretch 30s",
                recoveryActivityType: .stretching
            )
        ],
        notes: "Complete after every workout",
        estimatedDuration: 20
    )
}
