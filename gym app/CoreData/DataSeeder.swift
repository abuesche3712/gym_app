//
//  DataSeeder.swift
//  gym app
//
//  Pre-seeds the database with muscle groups, implements, and intrinsic measurables
//

import CoreData

struct DataSeeder {
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Check if Seeding Needed

    func needsSeeding() -> Bool {
        let request = NSFetchRequest<MuscleGroupEntity>(entityName: "MuscleGroupEntity")
        request.fetchLimit = 1
        do {
            let count = try viewContext.count(for: request)
            return count == 0
        } catch {
            return true
        }
    }

    // MARK: - Seed All Data

    func seedIfNeeded() {
        guard needsSeeding() else { return }

        seedMuscleGroups()
        seedImplements()
        seedIntrinsicMeasurables()

        do {
            try viewContext.save()
            print("DataSeeder: Successfully seeded database")
        } catch {
            print("DataSeeder: Error saving seeded data: \(error)")
        }
    }

    // MARK: - Muscle Groups

    private func seedMuscleGroups() {
        let muscleGroups = [
            "Chest",
            "Back",
            "Shoulders",
            "Biceps",
            "Triceps",
            "Core",
            "Quads",
            "Hamstrings",
            "Glutes",
            "Calves",
            "Cardio"
        ]

        for name in muscleGroups {
            let entity = MuscleGroupEntity(context: viewContext)
            entity.id = UUID()
            entity.name = name
        }
    }

    // MARK: - Implements

    private func seedImplements() {
        // Barbell - weight in lbs or kg
        createImplement(name: "Barbell", measurables: [
            MeasurableSpec(name: "Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Weight", unit: "kg", isStringBased: false)
        ])

        // Dumbbell - weight in lbs or kg
        createImplement(name: "Dumbbell", measurables: [
            MeasurableSpec(name: "Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Weight", unit: "kg", isStringBased: false)
        ])

        // Cable - weight in lbs or kg
        createImplement(name: "Cable", measurables: [
            MeasurableSpec(name: "Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Weight", unit: "kg", isStringBased: false)
        ])

        // Machine - weight in lbs or kg
        createImplement(name: "Machine", measurables: [
            MeasurableSpec(name: "Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Weight", unit: "kg", isStringBased: false)
        ])

        // Kettlebell - weight in lbs or kg
        createImplement(name: "Kettlebell", measurables: [
            MeasurableSpec(name: "Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Weight", unit: "kg", isStringBased: false)
        ])

        // Box - height in inches or cm
        createImplement(name: "Box", measurables: [
            MeasurableSpec(name: "Height", unit: "in", isStringBased: false),
            MeasurableSpec(name: "Height", unit: "cm", isStringBased: false)
        ])

        // Band - color (string-based)
        createImplement(name: "Band", measurables: [
            MeasurableSpec(name: "Color", unit: "", isStringBased: true)
        ])

        // Bodyweight - optional added weight
        createImplement(name: "Bodyweight", measurables: [
            MeasurableSpec(name: "Added Weight", unit: "lbs", isStringBased: false),
            MeasurableSpec(name: "Added Weight", unit: "kg", isStringBased: false)
        ])
    }

    private struct MeasurableSpec {
        let name: String
        let unit: String
        let isStringBased: Bool
    }

    private func createImplement(name: String, measurables: [MeasurableSpec]) {
        let implement = ImplementEntity(context: viewContext)
        implement.id = UUID()
        implement.name = name

        for spec in measurables {
            let measurable = MeasurableEntity(context: viewContext)
            measurable.id = UUID()
            measurable.name = spec.name
            measurable.unit = spec.unit
            measurable.isStringBased = spec.isStringBased
            measurable.hasDefaultValue = false
            measurable.implement = implement
        }
    }

    // MARK: - Intrinsic Measurables (for cardio)

    private func seedIntrinsicMeasurables() {
        // These are standalone measurables that can be added to any exercise
        // They are stored without an implement relationship

        // Time - in seconds
        createStandaloneMeasurable(name: "Time", unit: "seconds", isStringBased: false)

        // Distance - various units
        createStandaloneMeasurable(name: "Distance", unit: "m", isStringBased: false)
        createStandaloneMeasurable(name: "Distance", unit: "km", isStringBased: false)
        createStandaloneMeasurable(name: "Distance", unit: "mi", isStringBased: false)
        createStandaloneMeasurable(name: "Distance", unit: "yd", isStringBased: false)

        // Reps - for standard exercises
        createStandaloneMeasurable(name: "Reps", unit: "reps", isStringBased: false)
    }

    private func createStandaloneMeasurable(name: String, unit: String, isStringBased: Bool) {
        let measurable = MeasurableEntity(context: viewContext)
        measurable.id = UUID()
        measurable.name = name
        measurable.unit = unit
        measurable.isStringBased = isStringBased
        measurable.hasDefaultValue = false
        // implement and exerciseLibrary remain nil for standalone measurables
    }

    // MARK: - Fetch Helpers

    func fetchMuscleGroup(named name: String) -> MuscleGroupEntity? {
        let request = NSFetchRequest<MuscleGroupEntity>(entityName: "MuscleGroupEntity")
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func fetchImplement(named name: String) -> ImplementEntity? {
        let request = NSFetchRequest<ImplementEntity>(entityName: "ImplementEntity")
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func fetchAllMuscleGroups() -> [MuscleGroupEntity] {
        let request = NSFetchRequest<MuscleGroupEntity>(entityName: "MuscleGroupEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MuscleGroupEntity.name, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchAllImplements() -> [ImplementEntity] {
        let request = NSFetchRequest<ImplementEntity>(entityName: "ImplementEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ImplementEntity.name, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchStandaloneMeasurables() -> [MeasurableEntity] {
        let request = NSFetchRequest<MeasurableEntity>(entityName: "MeasurableEntity")
        request.predicate = NSPredicate(format: "implement == nil AND exerciseLibrary == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MeasurableEntity.name, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }
}
