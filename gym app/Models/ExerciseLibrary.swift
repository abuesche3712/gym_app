//
//  ExerciseLibrary.swift
//  gym app
//
//  Predefined exercise templates for consistent tracking across workouts
//

import Foundation

struct ExerciseTemplate: Identifiable, Codable, Hashable, ExerciseMetrics {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var exerciseType: ExerciseType

    // Tracking configuration
    var cardioMetric: CardioMetric
    var mobilityTracking: MobilityTracking
    var distanceUnit: DistanceUnit

    // Physical attributes - using enum arrays for simplicity
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var isBodyweight: Bool
    var recoveryActivityType: RecoveryActivityType?

    // Equipment
    var implementIds: Set<UUID>

    // Defaults for new instances
    var defaultSetGroups: [SetGroup]
    var defaultNotes: String?

    // Library management
    var isArchived: Bool
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        exerciseType: ExerciseType = .strength,
        cardioMetric: CardioMetric = .timeOnly,
        mobilityTracking: MobilityTracking = .repsOnly,
        distanceUnit: DistanceUnit = .meters,
        primary: [MuscleGroup] = [],
        secondary: [MuscleGroup] = [],
        isBodyweight: Bool = false,
        recoveryActivityType: RecoveryActivityType? = nil,
        implementIds: Set<UUID> = [],
        defaultSetGroups: [SetGroup] = [],
        defaultNotes: String? = nil,
        isArchived: Bool = false,
        isCustom: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.exerciseType = exerciseType
        self.cardioMetric = cardioMetric
        self.mobilityTracking = mobilityTracking
        self.distanceUnit = distanceUnit
        self.primaryMuscles = primary
        self.secondaryMuscles = secondary
        self.isBodyweight = isBodyweight
        self.recoveryActivityType = recoveryActivityType
        self.implementIds = implementIds
        self.defaultSetGroups = defaultSetGroups
        self.defaultNotes = defaultNotes
        self.isArchived = isArchived
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var allMuscles: [MuscleGroup] {
        Array(Set(primaryMuscles + secondaryMuscles))
    }

    // MARK: - ExerciseMetrics Conformance

    /// Templates don't have supersets - that's an instance-level concept
    var supersetGroupId: UUID? { nil }
}

enum ExerciseCategory: String, CaseIterable, Identifiable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
    case fullBody = "Full Body"

    var id: String { rawValue }
}

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .forearms: return "hand.raised"
        case .quads: return "figure.run"
        case .hamstrings: return "figure.cooldown"
        case .glutes: return "figure.hiking"
        case .calves: return "shoeprints.fill"
        case .core: return "figure.core.training"
        }
    }
}

// MARK: - Stable Template IDs
// These UUIDs must NEVER change - they are referenced by ExerciseInstance.templateId
// Adding new exercises is fine, but existing IDs must remain stable forever

private enum BuiltInExerciseId {
    // CHEST
    static let benchPress = UUID(uuidString: "00000001-0001-0001-0001-000000000001")!
    static let inclineBenchPress = UUID(uuidString: "00000001-0001-0001-0001-000000000002")!
    static let dumbbellFly = UUID(uuidString: "00000001-0001-0001-0001-000000000003")!
    static let pushUp = UUID(uuidString: "00000001-0001-0001-0001-000000000004")!
    static let cableCrossover = UUID(uuidString: "00000001-0001-0001-0001-000000000005")!
    static let dipsChest = UUID(uuidString: "00000001-0001-0001-0001-000000000006")!

    // BACK
    static let deadlift = UUID(uuidString: "00000002-0001-0001-0001-000000000001")!
    static let barbellRow = UUID(uuidString: "00000002-0001-0001-0001-000000000002")!
    static let pullUp = UUID(uuidString: "00000002-0001-0001-0001-000000000003")!
    static let chinUp = UUID(uuidString: "00000002-0001-0001-0001-000000000004")!
    static let latPulldown = UUID(uuidString: "00000002-0001-0001-0001-000000000005")!
    static let seatedCableRow = UUID(uuidString: "00000002-0001-0001-0001-000000000006")!
    static let facePull = UUID(uuidString: "00000002-0001-0001-0001-000000000007")!
    static let dumbbellRow = UUID(uuidString: "00000002-0001-0001-0001-000000000008")!

    // SHOULDERS
    static let overheadPress = UUID(uuidString: "00000003-0001-0001-0001-000000000001")!
    static let dumbbellShoulderPress = UUID(uuidString: "00000003-0001-0001-0001-000000000002")!
    static let lateralRaise = UUID(uuidString: "00000003-0001-0001-0001-000000000003")!
    static let frontRaise = UUID(uuidString: "00000003-0001-0001-0001-000000000004")!
    static let reverseFly = UUID(uuidString: "00000003-0001-0001-0001-000000000005")!
    static let uprightRow = UUID(uuidString: "00000003-0001-0001-0001-000000000006")!
    static let shrugs = UUID(uuidString: "00000003-0001-0001-0001-000000000007")!

    // BICEPS
    static let barbellCurl = UUID(uuidString: "00000004-0001-0001-0001-000000000001")!
    static let dumbbellCurl = UUID(uuidString: "00000004-0001-0001-0001-000000000002")!
    static let hammerCurl = UUID(uuidString: "00000004-0001-0001-0001-000000000003")!
    static let preacherCurl = UUID(uuidString: "00000004-0001-0001-0001-000000000004")!
    static let inclineDumbbellCurl = UUID(uuidString: "00000004-0001-0001-0001-000000000005")!

    // TRICEPS
    static let tricepPushdown = UUID(uuidString: "00000005-0001-0001-0001-000000000001")!
    static let skullCrusher = UUID(uuidString: "00000005-0001-0001-0001-000000000002")!
    static let tricepDip = UUID(uuidString: "00000005-0001-0001-0001-000000000003")!
    static let closeGripBenchPress = UUID(uuidString: "00000005-0001-0001-0001-000000000004")!
    static let overheadTricepExtension = UUID(uuidString: "00000005-0001-0001-0001-000000000005")!

    // LEGS
    static let backSquat = UUID(uuidString: "00000006-0001-0001-0001-000000000001")!
    static let frontSquat = UUID(uuidString: "00000006-0001-0001-0001-000000000002")!
    static let romanianDeadlift = UUID(uuidString: "00000006-0001-0001-0001-000000000003")!
    static let legPress = UUID(uuidString: "00000006-0001-0001-0001-000000000004")!
    static let lunge = UUID(uuidString: "00000006-0001-0001-0001-000000000005")!
    static let bulgarianSplitSquat = UUID(uuidString: "00000006-0001-0001-0001-000000000006")!
    static let legCurl = UUID(uuidString: "00000006-0001-0001-0001-000000000007")!
    static let legExtension = UUID(uuidString: "00000006-0001-0001-0001-000000000008")!
    static let calfRaise = UUID(uuidString: "00000006-0001-0001-0001-000000000009")!
    static let hipThrust = UUID(uuidString: "00000006-0001-0001-0001-000000000010")!
    static let gobletSquat = UUID(uuidString: "00000006-0001-0001-0001-000000000011")!
    static let sumoDeadlift = UUID(uuidString: "00000006-0001-0001-0001-000000000012")!

    // CORE
    static let plank = UUID(uuidString: "00000007-0001-0001-0001-000000000001")!
    static let crunch = UUID(uuidString: "00000007-0001-0001-0001-000000000002")!
    static let hangingLegRaise = UUID(uuidString: "00000007-0001-0001-0001-000000000003")!
    static let russianTwist = UUID(uuidString: "00000007-0001-0001-0001-000000000004")!
    static let cableWoodchop = UUID(uuidString: "00000007-0001-0001-0001-000000000005")!
    static let abWheelRollout = UUID(uuidString: "00000007-0001-0001-0001-000000000006")!
    static let deadBug = UUID(uuidString: "00000007-0001-0001-0001-000000000007")!

    // CARDIO
    static let treadmillRun = UUID(uuidString: "00000008-0001-0001-0001-000000000001")!
    static let cycling = UUID(uuidString: "00000008-0001-0001-0001-000000000002")!
    static let rowing = UUID(uuidString: "00000008-0001-0001-0001-000000000003")!
    static let jumpRope = UUID(uuidString: "00000008-0001-0001-0001-000000000004")!
    static let stairClimber = UUID(uuidString: "00000008-0001-0001-0001-000000000005")!
}

// MARK: - Exercise Library
//
// NOTE: Use ExerciseResolver.shared for all exercise lookups.
// This struct provides the static exercise definitions.
// Query methods below are for internal/migration use only.
//

struct ExerciseLibrary {
    static let shared = ExerciseLibrary()

    /// The built-in exercise definitions. Use ExerciseResolver for lookups.
    let exercises: [ExerciseTemplate]

    private init() {
        exercises = [
            // CHEST
            ExerciseTemplate(
                id: BuiltInExerciseId.benchPress,
                name: "Bench Press", category: .chest,
                primary: [.chest], secondary: [.shoulders, .triceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.inclineBenchPress,
                name: "Incline Bench Press", category: .chest,
                primary: [.chest], secondary: [.shoulders, .triceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.dumbbellFly,
                name: "Dumbbell Fly", category: .chest,
                primary: [.chest], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.pushUp,
                name: "Push-Up", category: .chest,
                primary: [.chest], secondary: [.triceps, .shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.cableCrossover,
                name: "Cable Crossover", category: .chest,
                primary: [.chest], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.dipsChest,
                name: "Dips (Chest)", category: .chest,
                primary: [.chest], secondary: [.triceps, .shoulders]
            ),

            // BACK
            ExerciseTemplate(
                id: BuiltInExerciseId.deadlift,
                name: "Deadlift", category: .back,
                primary: [.back, .hamstrings, .glutes], secondary: [.forearms, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.barbellRow,
                name: "Barbell Row", category: .back,
                primary: [.back], secondary: [.biceps, .forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.pullUp,
                name: "Pull-Up", category: .back,
                primary: [.back], secondary: [.biceps, .forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.chinUp,
                name: "Chin-Up", category: .back,
                primary: [.back, .biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.latPulldown,
                name: "Lat Pulldown", category: .back,
                primary: [.back], secondary: [.biceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.seatedCableRow,
                name: "Seated Cable Row", category: .back,
                primary: [.back], secondary: [.biceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.facePull,
                name: "Face Pull", category: .back,
                primary: [.shoulders, .back], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.dumbbellRow,
                name: "Dumbbell Row", category: .back,
                primary: [.back], secondary: [.biceps]
            ),

            // SHOULDERS
            ExerciseTemplate(
                id: BuiltInExerciseId.overheadPress,
                name: "Overhead Press", category: .shoulders,
                primary: [.shoulders], secondary: [.triceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.dumbbellShoulderPress,
                name: "Dumbbell Shoulder Press", category: .shoulders,
                primary: [.shoulders], secondary: [.triceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.lateralRaise,
                name: "Lateral Raise", category: .shoulders,
                primary: [.shoulders], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.frontRaise,
                name: "Front Raise", category: .shoulders,
                primary: [.shoulders], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.reverseFly,
                name: "Reverse Fly", category: .shoulders,
                primary: [.shoulders, .back], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.uprightRow,
                name: "Upright Row", category: .shoulders,
                primary: [.shoulders], secondary: [.biceps]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.shrugs,
                name: "Shrugs", category: .shoulders,
                primary: [.shoulders, .back], secondary: [.forearms]
            ),

            // BICEPS
            ExerciseTemplate(
                id: BuiltInExerciseId.barbellCurl,
                name: "Barbell Curl", category: .biceps,
                primary: [.biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.dumbbellCurl,
                name: "Dumbbell Curl", category: .biceps,
                primary: [.biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.hammerCurl,
                name: "Hammer Curl", category: .biceps,
                primary: [.biceps, .forearms], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.preacherCurl,
                name: "Preacher Curl", category: .biceps,
                primary: [.biceps], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.inclineDumbbellCurl,
                name: "Incline Dumbbell Curl", category: .biceps,
                primary: [.biceps], secondary: []
            ),

            // TRICEPS
            ExerciseTemplate(
                id: BuiltInExerciseId.tricepPushdown,
                name: "Tricep Pushdown", category: .triceps,
                primary: [.triceps], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.skullCrusher,
                name: "Skull Crusher", category: .triceps,
                primary: [.triceps], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.tricepDip,
                name: "Tricep Dip", category: .triceps,
                primary: [.triceps], secondary: [.chest, .shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.closeGripBenchPress,
                name: "Close Grip Bench Press", category: .triceps,
                primary: [.triceps], secondary: [.chest, .shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.overheadTricepExtension,
                name: "Overhead Tricep Extension", category: .triceps,
                primary: [.triceps], secondary: []
            ),

            // LEGS
            ExerciseTemplate(
                id: BuiltInExerciseId.backSquat,
                name: "Back Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.frontSquat,
                name: "Front Squat", category: .legs,
                primary: [.quads], secondary: [.glutes, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.romanianDeadlift,
                name: "Romanian Deadlift", category: .legs,
                primary: [.hamstrings, .glutes], secondary: [.back]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.legPress,
                name: "Leg Press", category: .legs,
                primary: [.quads, .glutes], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.lunge,
                name: "Lunge", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.bulgarianSplitSquat,
                name: "Bulgarian Split Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.legCurl,
                name: "Leg Curl", category: .legs,
                primary: [.hamstrings], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.legExtension,
                name: "Leg Extension", category: .legs,
                primary: [.quads], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.calfRaise,
                name: "Calf Raise", category: .legs,
                primary: [.calves], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.hipThrust,
                name: "Hip Thrust", category: .legs,
                primary: [.glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.gobletSquat,
                name: "Goblet Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.sumoDeadlift,
                name: "Sumo Deadlift", category: .legs,
                primary: [.glutes, .hamstrings, .quads], secondary: [.back]
            ),

            // CORE
            ExerciseTemplate(
                id: BuiltInExerciseId.plank,
                name: "Plank", category: .core, exerciseType: .isometric,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.crunch,
                name: "Crunch", category: .core,
                primary: [.core], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.hangingLegRaise,
                name: "Hanging Leg Raise", category: .core,
                primary: [.core], secondary: [.forearms]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.russianTwist,
                name: "Russian Twist", category: .core,
                primary: [.core], secondary: []
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.cableWoodchop,
                name: "Cable Woodchop", category: .core,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.abWheelRollout,
                name: "Ab Wheel Rollout", category: .core,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.deadBug,
                name: "Dead Bug", category: .core,
                primary: [.core], secondary: []
            ),

            // CARDIO
            ExerciseTemplate(
                id: BuiltInExerciseId.treadmillRun,
                name: "Treadmill Run", category: .cardio, exerciseType: .cardio,
                primary: [.quads, .hamstrings, .calves], secondary: [.glutes, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.cycling,
                name: "Cycling", category: .cardio, exerciseType: .cardio,
                primary: [.quads], secondary: [.hamstrings, .calves]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.rowing,
                name: "Rowing", category: .cardio, exerciseType: .cardio,
                primary: [.back, .quads], secondary: [.biceps, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.jumpRope,
                name: "Jump Rope", category: .cardio, exerciseType: .cardio,
                primary: [.calves], secondary: [.shoulders, .core]
            ),
            ExerciseTemplate(
                id: BuiltInExerciseId.stairClimber,
                name: "Stair Climber", category: .cardio, exerciseType: .cardio,
                primary: [.quads, .glutes], secondary: [.calves]
            ),
        ]
    }

    func search(_ query: String) -> [ExerciseTemplate] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func exercises(for category: ExerciseCategory) -> [ExerciseTemplate] {
        exercises.filter { $0.category == category }
    }

    func exercises(for muscle: MuscleGroup) -> [ExerciseTemplate] {
        exercises.filter { $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle) }
    }

    func template(named name: String) -> ExerciseTemplate? {
        exercises.first { $0.name.lowercased() == name.lowercased() }
    }

    func template(id: UUID) -> ExerciseTemplate? {
        exercises.first { $0.id == id }
    }
}
