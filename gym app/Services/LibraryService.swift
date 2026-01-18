//
//  LibraryService.swift
//  gym app
//
//  Service for accessing the exercise library system (muscle groups, implements, measurables)
//

import CoreData
import SwiftUI

@preconcurrency @MainActor
class LibraryService: ObservableObject {
    static let shared = LibraryService()

    private let persistence = PersistenceController.shared
    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published var muscleGroups: [MuscleGroupEntity] = []
    @Published var implements: [ImplementEntity] = []

    init() {
        loadData()
    }

    func loadData() {
        loadMuscleGroups()
        loadImplements()
    }

    // MARK: - Muscle Groups

    private func loadMuscleGroups() {
        let request = NSFetchRequest<MuscleGroupEntity>(entityName: "MuscleGroupEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MuscleGroupEntity.name, ascending: true)]
        muscleGroups = (try? viewContext.fetch(request)) ?? []
    }

    func getMuscleGroup(named name: String) -> MuscleGroupEntity? {
        muscleGroups.first { $0.name == name }
    }

    func getMuscleGroup(id: UUID) -> MuscleGroupEntity? {
        muscleGroups.first { $0.id == id }
    }

    // MARK: - Implements

    private func loadImplements() {
        let request = NSFetchRequest<ImplementEntity>(entityName: "ImplementEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ImplementEntity.name, ascending: true)]
        implements = (try? viewContext.fetch(request)) ?? []
    }

    func getImplement(named name: String) -> ImplementEntity? {
        implements.first { $0.name == name }
    }

    func getImplement(id: UUID) -> ImplementEntity? {
        implements.first { $0.id == id }
    }

    /// Get measurables for a specific implement, optionally filtered by unit preference
    func getMeasurables(for implement: ImplementEntity, preferredWeightUnit: String? = nil) -> [MeasurableEntity] {
        let all = implement.measurableArray

        // If no preference, return all
        guard let preferredUnit = preferredWeightUnit else {
            return all
        }

        // Filter to preferred unit for weight-related measurables
        return all.filter { measurable in
            if measurable.name == "Weight" || measurable.name == "Added Weight" {
                return measurable.unit == preferredUnit
            }
            return true
        }
    }

    // MARK: - Standalone Measurables (Time, Distance, Reps)

    func getStandaloneMeasurables() -> [MeasurableEntity] {
        let request = NSFetchRequest<MeasurableEntity>(entityName: "MeasurableEntity")
        request.predicate = NSPredicate(format: "implement == nil AND exerciseLibrary == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MeasurableEntity.name, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    /// Get distance measurables filtered by unit preference
    func getDistanceMeasurables(preferredUnit: String? = nil) -> [MeasurableEntity] {
        let all = getStandaloneMeasurables().filter { $0.name == "Distance" }

        guard let preferredUnit = preferredUnit else {
            return all
        }

        return all.filter { $0.unit == preferredUnit }
    }

    /// Get time measurable
    func getTimeMeasurable() -> MeasurableEntity? {
        getStandaloneMeasurables().first { $0.name == "Time" }
    }

    /// Get reps measurable
    func getRepsMeasurable() -> MeasurableEntity? {
        getStandaloneMeasurables().first { $0.name == "Reps" }
    }
}
