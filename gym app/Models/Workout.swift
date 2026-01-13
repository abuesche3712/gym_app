//
//  Workout.swift
//  gym app
//
//  A template combining multiple modules for a training session
//

import Foundation

struct Workout: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var moduleReferences: [ModuleReference]
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
        self.estimatedDuration = estimatedDuration
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archived = archived
        self.syncStatus = syncStatus
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
