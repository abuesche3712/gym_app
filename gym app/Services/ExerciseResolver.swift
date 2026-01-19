//
//  ExerciseResolver.swift
//  gym app
//
//  **SINGLE SOURCE OF TRUTH FOR EXERCISE LOOKUPS**
//
//  Service for resolving ExerciseInstances to ResolvedExercises by fetching templates.
//  Provides caching, search, and batch resolution for efficient UI rendering.
//
//  Use ExerciseResolver.shared for all exercise lookups instead of
//  ExerciseLibrary or CustomExerciseLibrary directly.
//

import Foundation
import Combine

@preconcurrency @MainActor
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

    // MARK: - All Exercises Access

    /// All exercises combined (built-in + custom)
    var allExercises: [ExerciseTemplate] {
        Array(templateCache.values)
    }

    /// Legacy alias for allExercises
    @available(*, deprecated, renamed: "allExercises")
    var allTemplates: [ExerciseTemplate] {
        allExercises
    }

    /// Built-in exercises only
    var builtInExercises: [ExerciseTemplate] {
        allExercises.filter { !$0.isCustom }
    }

    /// Custom/user-created exercises only
    var customExercises: [ExerciseTemplate] {
        allExercises.filter { $0.isCustom }
    }

    // MARK: - Single Resolution

    /// Resolves a single instance to a ResolvedExercise
    /// Template lookup is optional now since instance contains all needed data
    func resolve(_ instance: ExerciseInstance) -> ResolvedExercise {
        let template = instance.templateId.flatMap { templateCache[$0] }
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
    /// Note: With self-contained instances, this is rarely needed
    func createPlaceholderTemplate(for instance: ExerciseInstance) -> ExerciseTemplate {
        ExerciseTemplate(
            id: instance.templateId ?? UUID(),
            name: instance.name,
            category: .fullBody,
            exerciseType: instance.exerciseType,
            isArchived: true,
            isCustom: true
        )
    }

    /// Resolves an instance, creating a placeholder template if needed
    /// Note: Template is optional now since instance has all data
    func resolveWithPlaceholder(_ instance: ExerciseInstance) -> ResolvedExercise {
        if let templateId = instance.templateId, let template = templateCache[templateId] {
            return ResolvedExercise(instance: instance, template: template)
        } else {
            // Instance already has all needed data, template is optional
            return ResolvedExercise(instance: instance, template: nil)
        }
    }

    /// Finds all orphaned instances (templates that no longer exist)
    /// Note: Less critical now since instances are self-contained
    func findOrphans(in instances: [ExerciseInstance]) -> [ExerciseInstance] {
        instances.filter { instance in
            guard let templateId = instance.templateId else { return false }
            return templateCache[templateId] == nil
        }
    }

    // MARK: - Search & Filtering

    /// Primary search - searches all exercises by name (case-insensitive)
    func search(_ query: String) -> [ExerciseTemplate] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return allExercises.sorted { $0.name < $1.name }
        }
        return allExercises
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
    }

    /// Finds exercises by category
    func exercises(for category: ExerciseCategory) -> [ExerciseTemplate] {
        allExercises
            .filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }

    /// Finds exercises by exercise type
    func exercises(for type: ExerciseType) -> [ExerciseTemplate] {
        allExercises
            .filter { $0.exerciseType == type }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Template Lookup Helpers

    /// Finds a template by name (case-insensitive)
    func findTemplate(named name: String) -> ExerciseTemplate? {
        templateCache.values.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Legacy alias for search()
    @available(*, deprecated, renamed: "search")
    func searchTemplates(_ query: String) -> [ExerciseTemplate] {
        search(query)
    }

    /// Legacy alias for exercises(for category:)
    @available(*, deprecated, message: "Use exercises(for:) instead")
    func templates(for category: ExerciseCategory) -> [ExerciseTemplate] {
        exercises(for: category)
    }

    /// Legacy alias for exercises(for type:)
    @available(*, deprecated, message: "Use exercises(for:) instead")
    func templates(for exerciseType: ExerciseType) -> [ExerciseTemplate] {
        exercises(for: exerciseType)
    }
}
