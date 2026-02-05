//
//  ShareBundles.swift
//  gym app
//
//  Self-contained bundles for sharing content between users.
//  Each bundle contains all dependencies needed for the recipient to use the shared content.
//

import Foundation

// MARK: - Program Share Bundle

/// Complete program snapshot with all dependencies for sharing
struct ProgramShareBundle: Codable {
    let schemaVersion: Int
    let program: Program
    let workouts: [Workout]           // All workouts referenced by program slots
    let modules: [Module]             // All modules referenced by workouts
    let customTemplates: [ExerciseTemplate]  // Custom exercise templates used
    let customImplements: [ImplementSnapshot]  // Custom implements used

    init(
        program: Program,
        workouts: [Workout],
        modules: [Module],
        customTemplates: [ExerciseTemplate] = [],
        customImplements: [ImplementSnapshot] = []
    ) {
        self.schemaVersion = SchemaVersions.programShareBundle
        self.program = program
        self.workouts = workouts
        self.modules = modules
        self.customTemplates = customTemplates
        self.customImplements = customImplements
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> ProgramShareBundle {
        try JSONDecoder().decode(ProgramShareBundle.self, from: data)
    }
}

// MARK: - Workout Share Bundle

/// Complete workout snapshot with all dependencies for sharing
struct WorkoutShareBundle: Codable {
    let schemaVersion: Int
    let workout: Workout
    let modules: [Module]             // All modules referenced by workout
    let customTemplates: [ExerciseTemplate]  // Custom exercise templates used
    let customImplements: [ImplementSnapshot]  // Custom implements used

    init(
        workout: Workout,
        modules: [Module],
        customTemplates: [ExerciseTemplate] = [],
        customImplements: [ImplementSnapshot] = []
    ) {
        self.schemaVersion = SchemaVersions.workoutShareBundle
        self.workout = workout
        self.modules = modules
        self.customTemplates = customTemplates
        self.customImplements = customImplements
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> WorkoutShareBundle {
        try JSONDecoder().decode(WorkoutShareBundle.self, from: data)
    }
}

// MARK: - Module Share Bundle

/// Complete module snapshot with all dependencies for sharing
struct ModuleShareBundle: Codable {
    let schemaVersion: Int
    let module: Module
    let customTemplates: [ExerciseTemplate]  // Custom exercise templates used
    let customImplements: [ImplementSnapshot]  // Custom implements used

    init(
        module: Module,
        customTemplates: [ExerciseTemplate] = [],
        customImplements: [ImplementSnapshot] = []
    ) {
        self.schemaVersion = SchemaVersions.moduleShareBundle
        self.module = module
        self.customTemplates = customTemplates
        self.customImplements = customImplements
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> ModuleShareBundle {
        try JSONDecoder().decode(ModuleShareBundle.self, from: data)
    }
}

// MARK: - Session Share Bundle

/// Snapshot of a completed session for sharing workout results
struct SessionShareBundle: Codable {
    let schemaVersion: Int
    let session: Session
    let workoutName: String
    let date: Date

    /// User-selected exercise IDs to feature as highlights (nil = auto-generate)
    let highlightedExerciseIds: [UUID]?
    /// User-selected set IDs to feature as highlights
    let highlightedSetIds: [UUID]?

    init(session: Session, workoutName: String, date: Date, highlightedExerciseIds: [UUID]? = nil, highlightedSetIds: [UUID]? = nil) {
        self.schemaVersion = SchemaVersions.sessionShareBundle
        self.session = session
        self.workoutName = workoutName
        self.date = date
        self.highlightedExerciseIds = highlightedExerciseIds
        self.highlightedSetIds = highlightedSetIds
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> SessionShareBundle {
        try JSONDecoder().decode(SessionShareBundle.self, from: data)
    }
}

// MARK: - Exercise Share Bundle

/// Snapshot of an exercise performance for sharing
struct ExerciseShareBundle: Codable {
    let schemaVersion: Int
    let exerciseName: String
    let setData: [SetData]
    let workoutName: String?
    let date: Date
    let distanceUnit: DistanceUnit?

    init(exerciseName: String, setData: [SetData], workoutName: String? = nil, date: Date = Date(), distanceUnit: DistanceUnit? = nil) {
        self.schemaVersion = SchemaVersions.exerciseShareBundle
        self.exerciseName = exerciseName
        self.setData = setData
        self.workoutName = workoutName
        self.date = date
        self.distanceUnit = distanceUnit
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> ExerciseShareBundle {
        try JSONDecoder().decode(ExerciseShareBundle.self, from: data)
    }
}

// MARK: - Set Share Bundle

/// Snapshot of a single set (typically a PR) for sharing
struct SetShareBundle: Codable {
    let schemaVersion: Int
    let exerciseName: String
    let setData: SetData
    let isPR: Bool
    let workoutName: String?
    let date: Date
    let distanceUnit: DistanceUnit?

    init(exerciseName: String, setData: SetData, isPR: Bool = false, workoutName: String? = nil, date: Date = Date(), distanceUnit: DistanceUnit? = nil) {
        self.schemaVersion = SchemaVersions.setShareBundle
        self.exerciseName = exerciseName
        self.setData = setData
        self.isPR = isPR
        self.workoutName = workoutName
        self.date = date
        self.distanceUnit = distanceUnit
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> SetShareBundle {
        try JSONDecoder().decode(SetShareBundle.self, from: data)
    }
}

// MARK: - Completed Module Share Bundle

/// Snapshot of a completed module (from a session) for sharing
struct CompletedModuleShareBundle: Codable {
    let schemaVersion: Int
    let module: CompletedModule
    let workoutName: String
    let date: Date

    init(module: CompletedModule, workoutName: String, date: Date) {
        self.schemaVersion = SchemaVersions.completedModuleShareBundle
        self.module = module
        self.workoutName = workoutName
        self.date = date
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> CompletedModuleShareBundle {
        try JSONDecoder().decode(CompletedModuleShareBundle.self, from: data)
    }
}

// MARK: - Implement Snapshot

/// Lightweight snapshot of an implement for sharing
/// Used to include custom implements in share bundles
struct ImplementSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let isCustom: Bool
    let measurables: [MeasurableSnapshot]

    init(id: UUID, name: String, isCustom: Bool, measurables: [MeasurableSnapshot] = []) {
        self.id = id
        self.name = name
        self.isCustom = isCustom
        self.measurables = measurables
    }
}

/// Lightweight snapshot of a measurable property
struct MeasurableSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let unit: String
    let isStringBased: Bool

    init(id: UUID, name: String, unit: String, isStringBased: Bool = false) {
        self.id = id
        self.name = name
        self.unit = unit
        self.isStringBased = isStringBased
    }
}

// MARK: - Exercise Instance Share Bundle

/// Complete exercise instance snapshot for sharing (importable)
struct ExerciseInstanceShareBundle: Codable {
    let schemaVersion: Int
    let exerciseInstance: ExerciseInstance
    let customTemplates: [ExerciseTemplate]  // Custom exercise templates used
    let customImplements: [ImplementSnapshot]  // Custom implements used

    init(
        exerciseInstance: ExerciseInstance,
        customTemplates: [ExerciseTemplate] = [],
        customImplements: [ImplementSnapshot] = []
    ) {
        self.schemaVersion = SchemaVersions.exerciseInstanceShareBundle
        self.exerciseInstance = exerciseInstance
        self.customTemplates = customTemplates
        self.customImplements = customImplements
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> ExerciseInstanceShareBundle {
        try JSONDecoder().decode(ExerciseInstanceShareBundle.self, from: data)
    }
}

// MARK: - Set Group Share Bundle

/// Snapshot of a set prescription for sharing (view-only, not importable standalone)
struct SetGroupShareBundle: Codable {
    let schemaVersion: Int
    let setGroup: SetGroup
    let exerciseName: String
    let moduleName: String?

    init(setGroup: SetGroup, exerciseName: String, moduleName: String? = nil) {
        self.schemaVersion = SchemaVersions.setGroupShareBundle
        self.setGroup = setGroup
        self.exerciseName = exerciseName
        self.moduleName = moduleName
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> SetGroupShareBundle {
        try JSONDecoder().decode(SetGroupShareBundle.self, from: data)
    }
}

// MARK: - Completed Set Group Share Bundle

/// Snapshot of completed sets from a session for sharing
struct CompletedSetGroupShareBundle: Codable {
    let schemaVersion: Int
    let completedSetGroup: CompletedSetGroup
    let exerciseName: String
    let workoutName: String
    let date: Date

    init(completedSetGroup: CompletedSetGroup, exerciseName: String, workoutName: String, date: Date) {
        self.schemaVersion = SchemaVersions.completedSetGroupShareBundle
        self.completedSetGroup = completedSetGroup
        self.exerciseName = exerciseName
        self.workoutName = workoutName
        self.date = date
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> CompletedSetGroupShareBundle {
        try JSONDecoder().decode(CompletedSetGroupShareBundle.self, from: data)
    }
}

// MARK: - Highlights Share Bundle

/// Bundle containing multiple exercise/set highlights for sharing
struct HighlightsShareBundle: Codable {
    let schemaVersion: Int
    let workoutName: String
    let date: Date
    let exercises: [ExerciseShareBundle]  // Full exercises with all sets
    let sets: [SetShareBundle]            // Individual sets (not from full exercises)

    init(workoutName: String, date: Date, exercises: [ExerciseShareBundle] = [], sets: [SetShareBundle] = []) {
        self.schemaVersion = SchemaVersions.highlightsShareBundle
        self.workoutName = workoutName
        self.date = date
        self.exercises = exercises
        self.sets = sets
    }

    /// Encodes the bundle to Data for embedding in a message
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a bundle from message data
    static func decode(from data: Data) throws -> HighlightsShareBundle {
        try JSONDecoder().decode(HighlightsShareBundle.self, from: data)
    }
}
