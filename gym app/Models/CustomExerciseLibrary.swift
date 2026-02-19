//
//  CustomExerciseLibrary.swift
//  gym app
//
//  User's local exercise library - persists custom exercises locally
//
//  NOTE: Use ExerciseResolver.shared for all exercise lookups.
//  This class manages persistence of custom exercises.
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
            exercises = entities.map(exerciseTemplate(from:))
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
        category: ExerciseCategory = .fullBody,
        cardioMetric: CardioMetric = .timeOnly,
        mobilityTracking: MobilityTracking = .repsOnly,
        distanceUnit: DistanceUnit = .meters,
        primary: [MuscleGroup] = [],
        secondary: [MuscleGroup] = [],
        isBodyweight: Bool = false,
        isUnilateral: Bool = false,
        recoveryActivityType: RecoveryActivityType? = nil,
        implementIds: Set<UUID> = [],
        defaultSetGroups: [SetGroup] = [],
        defaultNotes: String? = nil,
        isArchived: Bool = false,
        isCustom: Bool = true,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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

        let template = ExerciseTemplate(
            id: id,
            name: trimmedName,
            category: category,
            exerciseType: exerciseType,
            cardioMetric: cardioMetric,
            mobilityTracking: mobilityTracking,
            distanceUnit: distanceUnit,
            primary: primary,
            secondary: secondary,
            isBodyweight: isBodyweight,
            isUnilateral: isUnilateral,
            recoveryActivityType: recoveryActivityType,
            implementIds: implementIds,
            defaultSetGroups: defaultSetGroups,
            defaultNotes: defaultNotes,
            isArchived: isArchived,
            isCustom: isCustom,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = CustomExerciseTemplateEntity(context: viewContext)
        apply(template: template, to: entity)

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
            category: template.category,
            cardioMetric: template.cardioMetric,
            mobilityTracking: template.mobilityTracking,
            distanceUnit: template.distanceUnit,
            primary: template.primaryMuscles,
            secondary: template.secondaryMuscles,
            isBodyweight: template.isBodyweight,
            isUnilateral: template.isUnilateral,
            recoveryActivityType: template.recoveryActivityType,
            implementIds: template.implementIds,
            defaultSetGroups: template.defaultSetGroups,
            defaultNotes: template.defaultNotes,
            isArchived: template.isArchived,
            isCustom: template.isCustom,
            id: template.id,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt
        )
    }

    // MARK: - Update

    func updateExercise(_ template: ExerciseTemplate) {
        let request = NSFetchRequest<CustomExerciseTemplateEntity>(entityName: "CustomExerciseTemplateEntity")
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)

        do {
            if let entity = try viewContext.fetch(request).first {
                apply(template: template, to: entity, preserveCreatedAt: true)
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

                // Track deletion to prevent re-sync from cloud
                DeletionTracker.shared.recordDeletion(entityType: .customExercise, entityId: template.id)
                Logger.debug("Tracked custom exercise deletion: \(template.name)")

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

    /// For duplicate checking during add - still valid to use
    func contains(name: String) -> Bool {
        exercises.contains { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Private

    private func exerciseTemplate(from entity: CustomExerciseTemplateEntity) -> ExerciseTemplate {
        ExerciseTemplate(
            id: entity.id,
            name: entity.name,
            category: entity.category,
            exerciseType: entity.exerciseType,
            cardioMetric: entity.cardioMetric,
            mobilityTracking: entity.mobilityTracking,
            distanceUnit: entity.distanceUnit,
            primary: entity.primaryMuscles,
            secondary: entity.secondaryMuscles,
            isBodyweight: entity.isBodyweight,
            isUnilateral: entity.isUnilateral,
            recoveryActivityType: entity.recoveryActivityType,
            implementIds: entity.implementIds,
            defaultSetGroups: decodeDefaultSetGroups(from: entity.defaultSetGroupsData),
            defaultNotes: entity.defaultNotes,
            isArchived: entity.isArchived,
            isCustom: entity.isCustom,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date()
        )
    }

    private func apply(
        template: ExerciseTemplate,
        to entity: CustomExerciseTemplateEntity,
        preserveCreatedAt: Bool = false
    ) {
        entity.id = template.id
        entity.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.category = template.category
        entity.exerciseType = template.exerciseType
        entity.cardioMetric = template.cardioMetric
        entity.mobilityTracking = template.mobilityTracking
        entity.distanceUnit = template.distanceUnit
        entity.primaryMuscles = template.primaryMuscles
        entity.secondaryMuscles = template.secondaryMuscles
        entity.isBodyweight = template.isBodyweight
        entity.isUnilateral = template.isUnilateral
        entity.recoveryActivityType = template.recoveryActivityType
        entity.implementIds = template.implementIds
        entity.defaultSetGroupsData = encodeDefaultSetGroups(template.defaultSetGroups)
        entity.defaultNotes = template.defaultNotes
        entity.isArchived = template.isArchived
        entity.isCustom = template.isCustom
        if !preserveCreatedAt || entity.createdAt == nil {
            entity.createdAt = template.createdAt
        }
        entity.updatedAt = template.updatedAt
    }

    private func decodeDefaultSetGroups(from data: Data?) -> [SetGroup] {
        guard let data else { return [] }
        do {
            return try JSONDecoder().decode([SetGroup].self, from: data)
        } catch {
            Logger.error(error, context: "decodeCustomExerciseDefaultSetGroups")
            return []
        }
    }

    private func encodeDefaultSetGroups(_ setGroups: [SetGroup]) -> Data? {
        guard !setGroups.isEmpty else { return nil }
        do {
            return try JSONEncoder().encode(setGroups)
        } catch {
            Logger.error(error, context: "encodeCustomExerciseDefaultSetGroups")
            return nil
        }
    }

    private func save() {
        persistence.save()
    }
}
