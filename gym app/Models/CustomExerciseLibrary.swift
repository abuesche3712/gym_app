//
//  CustomExerciseLibrary.swift
//  gym app
//
//  User's local exercise library - persists custom exercises locally
//

import Foundation
import CoreData

@MainActor
class CustomExerciseLibrary: ObservableObject {
    static let shared = CustomExerciseLibrary()

    private let persistence = PersistenceController.shared
    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published var exercises: [ExerciseTemplate] = []

    init() {
        loadExercises()
    }

    // MARK: - Load

    func loadExercises() {
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomExerciseTemplateEntity.name, ascending: true)]

        do {
            let entities = try viewContext.fetch(request)
            exercises = entities.map { entity in
                ExerciseTemplate(
                    id: entity.id,
                    name: entity.name,
                    category: .fullBody,  // Deprecated - always use fullBody
                    exerciseType: entity.exerciseType,
                    muscleGroupIds: entity.muscleGroupIds,
                    implementIds: entity.implementIds
                )
            }
        } catch {
            print("Error loading custom exercises: \(error)")
        }
    }

    // MARK: - Save

    func addExercise(
        name: String,
        exerciseType: ExerciseType,
        muscleGroupIds: Set<UUID> = [],
        implementIds: Set<UUID> = []
    ) {
        // Check if exercise with same name already exists
        guard !exercises.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            return
        }

        let entity = CustomExerciseTemplateEntity(context: viewContext)
        entity.id = UUID()
        entity.name = name
        entity.categoryRaw = ExerciseCategory.fullBody.rawValue  // Deprecated
        entity.exerciseType = exerciseType
        entity.muscleGroupIds = muscleGroupIds
        entity.implementIds = implementIds
        entity.createdAt = Date()

        save()
        loadExercises()
    }

    func addExercise(_ template: ExerciseTemplate) {
        addExercise(
            name: template.name,
            exerciseType: template.exerciseType,
            muscleGroupIds: template.muscleGroupIds,
            implementIds: template.implementIds
        )
    }

    // MARK: - Update

    func updateExercise(_ template: ExerciseTemplate) {
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                entity.name = template.name
                entity.exerciseType = template.exerciseType
                entity.muscleGroupIds = template.muscleGroupIds
                entity.implementIds = template.implementIds
                save()
                loadExercises()
            }
        } catch {
            print("Error updating custom exercise: \(error)")
        }
    }

    // MARK: - Delete

    func deleteExercise(_ template: ExerciseTemplate) {
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                save()
                loadExercises()
            }
        } catch {
            print("Error deleting custom exercise: \(error)")
        }
    }

    func deleteExercise(named name: String) {
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.predicate = NSPredicate(format: "name ==[c] %@", name)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                save()
                loadExercises()
            }
        } catch {
            print("Error deleting custom exercise: \(error)")
        }
    }

    // MARK: - Search

    func search(_ query: String) -> [ExerciseTemplate] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func exercises(for category: ExerciseCategory) -> [ExerciseTemplate] {
        exercises.filter { $0.category == category }
    }

    func template(named name: String) -> ExerciseTemplate? {
        exercises.first { $0.name.lowercased() == name.lowercased() }
    }

    func contains(name: String) -> Bool {
        exercises.contains { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Private

    private func save() {
        persistence.save()
    }
}
