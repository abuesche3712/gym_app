//
//  ExerciseResolver.swift
//  gym app
//
//  Service for resolving ExerciseInstances to ResolvedExercises by fetching templates.
//  Provides caching and batch resolution for efficient UI rendering.
//

import Foundation
import Combine

@MainActor
class ExerciseResolver: ObservableObject {
    static let shared = ExerciseResolver()

    /// Cache of templates by ID for fast lookups
    private var templateCache: [UUID: ExerciseTemplate] = [:]

    /// Published to notify observers when cache is refreshed
    @Published private(set) var lastCacheRefresh: Date = Date()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Initial cache load
        refreshCache()

        // Subscribe to custom library changes
        CustomExerciseLibrary.shared.$exercises
            .sink { [weak self] _ in
                self?.refreshCache()
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache Management

    /// Refreshes the template cache from all sources
    func refreshCache() {
        templateCache.removeAll()

        // Load from built-in library
        for template in ExerciseLibrary.shared.exercises {
            templateCache[template.id] = template
        }

        // Load from custom library
        for template in CustomExerciseLibrary.shared.exercises {
            templateCache[template.id] = template
        }

        lastCacheRefresh = Date()
    }

    /// Gets a template by ID from the cache
    func getTemplate(id: UUID) -> ExerciseTemplate? {
        templateCache[id]
    }

    /// Gets all cached templates
    var allTemplates: [ExerciseTemplate] {
        Array(templateCache.values)
    }

    // MARK: - Single Resolution

    /// Resolves a single instance to a ResolvedExercise
    func resolve(_ instance: ExerciseInstance) -> ResolvedExercise {
        let template = templateCache[instance.templateId]
        return ResolvedExercise(instance: instance, template: template)
    }

    // MARK: - Batch Resolution

    /// Resolves multiple instances to ResolvedExercises
    func resolve(_ instances: [ExerciseInstance]) -> [ResolvedExercise] {
        instances.map { resolve($0) }
    }

    /// Resolves instances grouped by superset (for UI display)
    /// Returns a 2D array where each inner array is either a superset or single exercise
    func resolveGrouped(_ instances: [ExerciseInstance]) -> [[ResolvedExercise]] {
        var groups: [[ResolvedExercise]] = []
        var processedIds: Set<UUID> = []

        for instance in instances {
            guard !processedIds.contains(instance.id) else { continue }

            if let supersetId = instance.supersetGroupId {
                // Find all instances in this superset
                let supersetInstances = instances.filter { $0.supersetGroupId == supersetId }
                let resolved = supersetInstances.map { resolve($0) }
                groups.append(resolved)
                supersetInstances.forEach { processedIds.insert($0.id) }
            } else {
                // Single exercise (not in a superset)
                groups.append([resolve(instance)])
                processedIds.insert(instance.id)
            }
        }

        return groups
    }

    // MARK: - Orphan Handling

    /// Creates a placeholder template for an orphaned instance
    func createPlaceholderTemplate(for instance: ExerciseInstance) -> ExerciseTemplate {
        ExerciseTemplate(
            id: instance.templateId,
            name: instance.nameOverride ?? "Deleted Exercise",
            category: .fullBody,
            exerciseType: instance.exerciseTypeOverride ?? .strength,
            isArchived: true,
            isCustom: true
        )
    }

    /// Resolves an instance, creating a placeholder template if needed
    func resolveWithPlaceholder(_ instance: ExerciseInstance) -> ResolvedExercise {
        if let template = templateCache[instance.templateId] {
            return ResolvedExercise(instance: instance, template: template)
        } else {
            let placeholder = createPlaceholderTemplate(for: instance)
            return ResolvedExercise(instance: instance, template: placeholder)
        }
    }

    /// Finds all orphaned instances (templates that no longer exist)
    func findOrphans(in instances: [ExerciseInstance]) -> [ExerciseInstance] {
        instances.filter { templateCache[$0.templateId] == nil }
    }

    // MARK: - Template Lookup Helpers

    /// Finds a template by name (case-insensitive)
    func findTemplate(named name: String) -> ExerciseTemplate? {
        templateCache.values.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Finds templates matching a search query
    func searchTemplates(_ query: String) -> [ExerciseTemplate] {
        guard !query.isEmpty else { return allTemplates }
        return templateCache.values.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Finds templates by category
    func templates(for category: ExerciseCategory) -> [ExerciseTemplate] {
        templateCache.values.filter { $0.category == category }
    }

    /// Finds templates by exercise type
    func templates(for exerciseType: ExerciseType) -> [ExerciseTemplate] {
        templateCache.values.filter { $0.exerciseType == exerciseType }
    }
}
