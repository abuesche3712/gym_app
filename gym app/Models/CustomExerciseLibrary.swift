//
//  CustomExerciseLibrary.swift
//  gym app
//
//  User's local exercise library - persists custom exercises locally
//
//  NOTE: Use ExerciseResolver.shared for all exercise lookups.
//  This class manages persistence of custom exercises.
//  Query methods below are deprecated - use ExerciseResolver instead.
//

import Foundation
import CoreData

@preconcurrency @MainActor
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
                    category: .fullBody,
                    exerciseType: entity.exerciseType,
                    primary: entity.primaryMuscles,
                    secondary: entity.secondaryMuscles,
                    implementIds: entity.implementIds,
                    isCustom: true
                )
            }
        } catch {
            Logger.error(error, context: "loadCustomExercises")
        }
    }

    // MARK: - Save

    /// Returns false if validation fails or exercise already exists
    @discardableResult
    func addExercise(
        name: String,
        exerciseType: ExerciseType,
        primary: [MuscleGroup] = [],
        secondary: [MuscleGroup] = [],
        implementIds: Set<UUID> = []
    ) -> Bool {
        // Validate name is not empty
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            Logger.warning("Cannot add custom exercise with empty name")
            return false
        }

        // Check if exercise with same name already exists
        guard !exercises.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) else {
            Logger.debug("Custom exercise '\(trimmedName)' already exists")
            return false
        }

        let entity = CustomExerciseTemplateEntity(context: viewContext)
        entity.id = UUID()
        entity.name = trimmedName
        entity.categoryRaw = ExerciseCategory.fullBody.rawValue
        entity.exerciseType = exerciseType
        entity.primaryMuscles = primary
        entity.secondaryMuscles = secondary
        entity.implementIds = implementIds
        entity.createdAt = Date()
        entity.updatedAt = Date()

        save()
        loadExercises()
        return true
    }

    /// Returns false if validation fails or exercise already exists
    @discardableResult
    func addExercise(_ template: ExerciseTemplate) -> Bool {
        guard !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.warning("Cannot add custom exercise with empty template name")
            return false
        }

        return addExercise(
            name: template.name,
            exerciseType: template.exerciseType,
            primary: template.primaryMuscles,
            secondary: template.secondaryMuscles,
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
                entity.primaryMuscles = template.primaryMuscles
                entity.secondaryMuscles = template.secondaryMuscles
                entity.implementIds = template.implementIds
                entity.updatedAt = Date()
                save()
                loadExercises()
            }
        } catch {
            Logger.error(error, context: "updateCustomExercise")
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

                // Queue deletion for cloud sync if authenticated
                if AuthService.shared.isAuthenticated {
                    SyncManager.shared.queueCustomExercise(template, action: .delete)
                    Logger.debug("Queued custom exercise deletion for cloud sync")
                }
            }
        } catch {
            Logger.error(error, context: "deleteCustomExercise")
        }
    }

    func deleteExercise(named name: String) {
        // Find the template first to get the full object for sync
        if let template = exercises.first(where: { $0.name.lowercased() == name.lowercased() }) {
            deleteExercise(template)
            return
        }

        // Fallback to old behavior if template not found
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.predicate = NSPredicate(format: "name ==[c] %@", name)

        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                save()
                loadExercises()
            }
        } catch {
            Logger.error(error, context: "deleteCustomExerciseByName")
        }
    }

    // MARK: - Search (Deprecated - Use ExerciseResolver)

    /// Deprecated: Use ExerciseResolver.shared.search() instead
    @available(*, deprecated, message: "Use ExerciseResolver.shared.search() instead")
    func search(_ query: String) -> [ExerciseTemplate] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Deprecated: Use ExerciseResolver.shared.exercises(for:) instead
    @available(*, deprecated, message: "Use ExerciseResolver.shared.exercises(for:) instead")
    func exercises(for category: ExerciseCategory) -> [ExerciseTemplate] {
        exercises.filter { $0.category == category }
    }

    /// Deprecated: Use ExerciseResolver.shared.findTemplate(named:) instead
    @available(*, deprecated, message: "Use ExerciseResolver.shared.findTemplate(named:) instead")
    func template(named name: String) -> ExerciseTemplate? {
        exercises.first { $0.name.lowercased() == name.lowercased() }
    }

    /// For duplicate checking during add - still valid to use
    func contains(name: String) -> Bool {
        exercises.contains { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Private

    private func save() {
        persistence.save()
    }
}
