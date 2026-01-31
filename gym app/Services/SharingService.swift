//
//  SharingService.swift
//  gym app
//
//  Service for creating share bundles and importing shared content.
//  Handles UUID remapping, conflict detection, and dependency collection.
//

import Foundation

@preconcurrency @MainActor
class SharingService: ObservableObject {
    static let shared = SharingService()

    private let dataRepository = DataRepository.shared
    private let customExerciseLibrary = CustomExerciseLibrary.shared
    private let libraryService = LibraryService.shared
    private let exerciseResolver = ExerciseResolver.shared

    init() {}

    // MARK: - Create Share Bundles

    /// Creates a complete share bundle for a program with all dependencies
    func createProgramBundle(_ program: Program) throws -> ProgramShareBundle {
        // Collect all workouts referenced by the program
        var workouts: [Workout] = []
        var moduleIds = Set<UUID>()

        // Get workouts from legacy workout slots
        for slot in program.workoutSlots {
            if let workout = dataRepository.getWorkout(id: slot.workoutId) {
                workouts.append(workout)
                // Collect module IDs from workout
                for ref in workout.moduleReferences {
                    moduleIds.insert(ref.moduleId)
                }
            }
        }

        // Also check unified slots (workouts and modules)
        for slot in program.moduleSlots {
            switch slot.content {
            case .workout(let id, _):
                if let workout = dataRepository.getWorkout(id: id) {
                    workouts.append(workout)
                    for ref in workout.moduleReferences {
                        moduleIds.insert(ref.moduleId)
                    }
                }
            case .module(let id, _, _):
                moduleIds.insert(id)
            }
        }

        // Collect all modules
        var modules: [Module] = []
        for moduleId in moduleIds {
            if let module = dataRepository.getModule(id: moduleId) {
                modules.append(module)
            }
        }

        // Collect custom templates and implements from modules
        let (customTemplates, customImplements) = collectDependencies(from: modules)

        return ProgramShareBundle(
            program: program,
            workouts: workouts,
            modules: modules,
            customTemplates: customTemplates,
            customImplements: customImplements
        )
    }

    /// Creates a complete share bundle for a workout with all dependencies
    func createWorkoutBundle(_ workout: Workout) throws -> WorkoutShareBundle {
        // Collect all referenced modules
        var modules: [Module] = []
        for ref in workout.moduleReferences {
            if let module = dataRepository.getModule(id: ref.moduleId) {
                modules.append(module)
            }
        }

        // Collect custom templates and implements
        let (customTemplates, customImplements) = collectDependencies(from: modules)

        return WorkoutShareBundle(
            workout: workout,
            modules: modules,
            customTemplates: customTemplates,
            customImplements: customImplements
        )
    }

    /// Creates a complete share bundle for a module with all dependencies
    func createModuleBundle(_ module: Module) throws -> ModuleShareBundle {
        let (customTemplates, customImplements) = collectDependencies(from: [module])

        return ModuleShareBundle(
            module: module,
            customTemplates: customTemplates,
            customImplements: customImplements
        )
    }

    /// Creates a share bundle for a completed session
    func createSessionBundle(_ session: Session, workoutName: String) throws -> SessionShareBundle {
        return SessionShareBundle(
            session: session,
            workoutName: workoutName,
            date: session.date
        )
    }

    /// Creates a share bundle for an exercise performance
    func createExerciseBundle(exerciseName: String, setData: [SetData], workoutName: String? = nil) throws -> ExerciseShareBundle {
        return ExerciseShareBundle(
            exerciseName: exerciseName,
            setData: setData,
            workoutName: workoutName,
            date: Date()
        )
    }

    /// Creates a share bundle for a single set (e.g., a PR)
    func createSetBundle(exerciseName: String, setData: SetData, isPR: Bool = false, workoutName: String? = nil) throws -> SetShareBundle {
        return SetShareBundle(
            exerciseName: exerciseName,
            setData: setData,
            isPR: isPR,
            workoutName: workoutName,
            date: Date()
        )
    }

    // MARK: - Detect Conflicts

    /// Detects conflicts between imported content and existing library
    func detectConflicts(from bundle: ProgramShareBundle) -> [ImportConflict] {
        var conflicts: [ImportConflict] = []

        // Check custom templates
        for template in bundle.customTemplates {
            if let existing = findExistingTemplate(matching: template) {
                conflicts.append(.template(TemplateConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedTemplate: template
                )))
            }
        }

        // Check custom implements
        for implement in bundle.customImplements where implement.isCustom {
            if let existing = findExistingImplement(matching: implement) {
                conflicts.append(.implement(ImplementConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedImplement: implement
                )))
            }
        }

        return conflicts
    }

    func detectConflicts(from bundle: WorkoutShareBundle) -> [ImportConflict] {
        var conflicts: [ImportConflict] = []

        for template in bundle.customTemplates {
            if let existing = findExistingTemplate(matching: template) {
                conflicts.append(.template(TemplateConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedTemplate: template
                )))
            }
        }

        for implement in bundle.customImplements where implement.isCustom {
            if let existing = findExistingImplement(matching: implement) {
                conflicts.append(.implement(ImplementConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedImplement: implement
                )))
            }
        }

        return conflicts
    }

    func detectConflicts(from bundle: ModuleShareBundle) -> [ImportConflict] {
        var conflicts: [ImportConflict] = []

        for template in bundle.customTemplates {
            if let existing = findExistingTemplate(matching: template) {
                conflicts.append(.template(TemplateConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedTemplate: template
                )))
            }
        }

        for implement in bundle.customImplements where implement.isCustom {
            if let existing = findExistingImplement(matching: implement) {
                conflicts.append(.implement(ImplementConflict(
                    existingId: existing.id,
                    existingName: existing.name,
                    importedImplement: implement
                )))
            }
        }

        return conflicts
    }

    // MARK: - Import Content

    /// Imports a program bundle with conflict resolution
    func importProgram(from bundle: ProgramShareBundle, options: ImportOptions = ImportOptions()) -> ImportResult {
        // Build UUID remapping based on conflict resolutions
        var idMapping: [UUID: UUID] = [:]

        // First, import or remap custom templates
        for template in bundle.customTemplates {
            let newId = importTemplate(template, options: options)
            if newId != template.id {
                idMapping[template.id] = newId
            }
        }

        // Import or remap custom implements
        for implement in bundle.customImplements where implement.isCustom {
            let newId = importImplement(implement, options: options)
            if newId != implement.id {
                idMapping[implement.id] = newId
            }
        }

        // Import modules with remapped IDs
        var moduleMapping: [UUID: UUID] = [:]
        for module in bundle.modules {
            let (newModule, newId) = remapModule(module, idMapping: idMapping)
            moduleMapping[module.id] = newId
            dataRepository.saveModule(newModule)
        }

        // Import workouts with remapped module references
        var workoutMapping: [UUID: UUID] = [:]
        for workout in bundle.workouts {
            let (newWorkout, newId) = remapWorkout(workout, moduleMapping: moduleMapping, idMapping: idMapping)
            workoutMapping[workout.id] = newId
            dataRepository.saveWorkout(newWorkout)
        }

        // Import program with remapped workout references
        let (newProgram, _) = remapProgram(bundle.program, workoutMapping: workoutMapping, moduleMapping: moduleMapping)
        dataRepository.saveProgram(newProgram)

        return .success(id: newProgram.id, name: newProgram.name)
    }

    /// Imports a workout bundle with conflict resolution
    func importWorkout(from bundle: WorkoutShareBundle, options: ImportOptions = ImportOptions()) -> ImportResult {
        var idMapping: [UUID: UUID] = [:]

        // Import custom templates
        for template in bundle.customTemplates {
            let newId = importTemplate(template, options: options)
            if newId != template.id {
                idMapping[template.id] = newId
            }
        }

        // Import custom implements
        for implement in bundle.customImplements where implement.isCustom {
            let newId = importImplement(implement, options: options)
            if newId != implement.id {
                idMapping[implement.id] = newId
            }
        }

        // Import modules
        var moduleMapping: [UUID: UUID] = [:]
        for module in bundle.modules {
            let (newModule, newId) = remapModule(module, idMapping: idMapping)
            moduleMapping[module.id] = newId
            dataRepository.saveModule(newModule)
        }

        // Import workout
        let (newWorkout, _) = remapWorkout(bundle.workout, moduleMapping: moduleMapping, idMapping: idMapping)
        dataRepository.saveWorkout(newWorkout)

        return .success(id: newWorkout.id, name: newWorkout.name)
    }

    /// Imports a module bundle with conflict resolution
    func importModule(from bundle: ModuleShareBundle, options: ImportOptions = ImportOptions()) -> ImportResult {
        var idMapping: [UUID: UUID] = [:]

        // Import custom templates
        for template in bundle.customTemplates {
            let newId = importTemplate(template, options: options)
            if newId != template.id {
                idMapping[template.id] = newId
            }
        }

        // Import custom implements
        for implement in bundle.customImplements where implement.isCustom {
            let newId = importImplement(implement, options: options)
            if newId != implement.id {
                idMapping[implement.id] = newId
            }
        }

        // Import module
        let (newModule, _) = remapModule(bundle.module, idMapping: idMapping)
        dataRepository.saveModule(newModule)

        return .success(id: newModule.id, name: newModule.name)
    }

    // MARK: - Private Helpers

    private func collectDependencies(from modules: [Module]) -> ([ExerciseTemplate], [ImplementSnapshot]) {
        var customTemplates: [ExerciseTemplate] = []
        var customImplementSnapshots: [ImplementSnapshot] = []
        var seenTemplateIds = Set<UUID>()
        var seenImplementIds = Set<UUID>()

        for module in modules {
            for exercise in module.exercises {
                // Check if using a custom template
                if let templateId = exercise.templateId {
                    if !seenTemplateIds.contains(templateId) {
                        seenTemplateIds.insert(templateId)

                        // Check if it's a custom template (not built-in)
                        if let customTemplate = customExerciseLibrary.exercises.first(where: { $0.id == templateId }) {
                            customTemplates.append(customTemplate)
                        }
                    }
                }

                // Collect implement IDs
                for implementId in exercise.implementIds {
                    if !seenImplementIds.contains(implementId) {
                        seenImplementIds.insert(implementId)

                        // Create snapshot of implement
                        if let implementEntity = libraryService.getImplement(id: implementId) {
                            let measurables = implementEntity.measurableArray.map { measurable in
                                MeasurableSnapshot(
                                    id: measurable.id,
                                    name: measurable.name,
                                    unit: measurable.unit,
                                    isStringBased: measurable.isStringBased
                                )
                            }
                            customImplementSnapshots.append(ImplementSnapshot(
                                id: implementEntity.id,
                                name: implementEntity.name,
                                isCustom: implementEntity.isCustom,
                                measurables: measurables
                            ))
                        }
                    }
                }
            }
        }

        return (customTemplates, customImplementSnapshots)
    }

    private func findExistingTemplate(matching template: ExerciseTemplate) -> ExerciseTemplate? {
        // Check by name (case-insensitive)
        if let existing = customExerciseLibrary.exercises.first(where: {
            $0.name.lowercased() == template.name.lowercased()
        }) {
            return existing
        }
        return nil
    }

    private func findExistingImplement(matching implement: ImplementSnapshot) -> ImplementEntity? {
        // Check by name
        return libraryService.getImplement(named: implement.name)
    }

    private func importTemplate(_ template: ExerciseTemplate, options: ImportOptions) -> UUID {
        // Check if already exists
        if let existing = findExistingTemplate(matching: template) {
            // Use existing by default
            return existing.id
        }

        // Create new template
        customExerciseLibrary.addExercise(template)
        return template.id
    }

    private func importImplement(_ implement: ImplementSnapshot, options: ImportOptions) -> UUID {
        // Check if already exists
        if let existing = findExistingImplement(matching: implement) {
            return existing.id
        }

        // For now, just return the original ID - implements are typically built-in
        // Custom implement creation would go here if supported
        return implement.id
    }

    private func remapModule(_ module: Module, idMapping: [UUID: UUID]) -> (Module, UUID) {
        let newId = UUID()
        var newModule = module
        newModule.id = newId
        newModule.syncStatus = .pendingSync
        newModule.createdAt = Date()
        newModule.updatedAt = Date()

        // Remap exercise template IDs
        for i in newModule.exercises.indices {
            newModule.exercises[i].id = UUID()
            if let templateId = newModule.exercises[i].templateId,
               let newTemplateId = idMapping[templateId] {
                newModule.exercises[i].templateId = newTemplateId
            }

            // Remap implement IDs
            var newImplementIds = Set<UUID>()
            for implementId in newModule.exercises[i].implementIds {
                if let newImplementId = idMapping[implementId] {
                    newImplementIds.insert(newImplementId)
                } else {
                    newImplementIds.insert(implementId)
                }
            }
            newModule.exercises[i].implementIds = newImplementIds
        }

        return (newModule, newId)
    }

    private func remapWorkout(_ workout: Workout, moduleMapping: [UUID: UUID], idMapping: [UUID: UUID]) -> (Workout, UUID) {
        let newId = UUID()
        var newWorkout = workout
        newWorkout.id = newId
        newWorkout.syncStatus = .pendingSync
        newWorkout.createdAt = Date()
        newWorkout.updatedAt = Date()

        // Remap module references
        for i in newWorkout.moduleReferences.indices {
            newWorkout.moduleReferences[i].id = UUID()
            if let newModuleId = moduleMapping[newWorkout.moduleReferences[i].moduleId] {
                newWorkout.moduleReferences[i].moduleId = newModuleId
            }
        }

        // Remap standalone exercises
        for i in newWorkout.standaloneExercises.indices {
            newWorkout.standaloneExercises[i].id = UUID()
            newWorkout.standaloneExercises[i].exercise.id = UUID()

            if let templateId = newWorkout.standaloneExercises[i].exercise.templateId,
               let newTemplateId = idMapping[templateId] {
                newWorkout.standaloneExercises[i].exercise.templateId = newTemplateId
            }

            var newImplementIds = Set<UUID>()
            for implementId in newWorkout.standaloneExercises[i].exercise.implementIds {
                if let newImplementId = idMapping[implementId] {
                    newImplementIds.insert(newImplementId)
                } else {
                    newImplementIds.insert(implementId)
                }
            }
            newWorkout.standaloneExercises[i].exercise.implementIds = newImplementIds
        }

        return (newWorkout, newId)
    }

    private func remapProgram(_ program: Program, workoutMapping: [UUID: UUID], moduleMapping: [UUID: UUID]) -> (Program, UUID) {
        let newId = UUID()
        var newProgram = program
        newProgram.id = newId
        newProgram.isActive = false  // Don't auto-activate imported programs
        newProgram.syncStatus = .pendingSync
        newProgram.createdAt = Date()
        newProgram.updatedAt = Date()

        // Remap workout slots
        for i in newProgram.workoutSlots.indices {
            newProgram.workoutSlots[i].id = UUID()
            if let newWorkoutId = workoutMapping[newProgram.workoutSlots[i].workoutId] {
                newProgram.workoutSlots[i].workoutId = newWorkoutId
            }
        }

        // Remap unified slots (workouts and modules)
        for i in newProgram.moduleSlots.indices {
            newProgram.moduleSlots[i].id = UUID()
            switch newProgram.moduleSlots[i].content {
            case .workout(let id, let name):
                if let newWorkoutId = workoutMapping[id] {
                    newProgram.moduleSlots[i].content = .workout(id: newWorkoutId, name: name)
                }
            case .module(let id, let name, let type):
                if let newModuleId = moduleMapping[id] {
                    newProgram.moduleSlots[i].content = .module(id: newModuleId, name: name, type: type)
                }
            }
        }

        return (newProgram, newId)
    }
}

// MARK: - MessageContent Extension

extension MessageContent {
    /// Whether this message content can be imported (contains importable templates)
    var isImportable: Bool {
        switch self {
        case .sharedProgram, .sharedWorkout, .sharedModule:
            return true
        case .text, .sharedSession, .sharedExercise, .sharedSet:
            return false
        }
    }

    /// Whether this content is shared content (not plain text)
    var isSharedContent: Bool {
        switch self {
        case .text:
            return false
        default:
            return true
        }
    }
}
