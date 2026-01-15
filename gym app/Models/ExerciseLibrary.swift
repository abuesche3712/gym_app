//
//  ExerciseLibrary.swift
//  gym app
//
//  Predefined exercise templates for consistent tracking across workouts
//

import Foundation

struct ExerciseTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var exerciseType: ExerciseType

    // Tracking configuration
    var cardioMetric: CardioMetric
    var mobilityTracking: MobilityTracking
    var distanceUnit: DistanceUnit

    // Physical attributes
    var muscleGroupIds: Set<UUID>
    var implementIds: Set<UUID>
    var isBodyweight: Bool
    var recoveryActivityType: RecoveryActivityType?

    // Defaults for new instances
    var defaultSetGroups: [SetGroup]
    var defaultNotes: String?

    // Library management
    var isArchived: Bool
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date

    // Legacy muscle data (for backward compatibility)
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]

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
        muscleGroupIds: Set<UUID> = [],
        implementIds: Set<UUID> = [],
        isBodyweight: Bool = false,
        recoveryActivityType: RecoveryActivityType? = nil,
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
        self.muscleGroupIds = muscleGroupIds
        self.implementIds = implementIds
        self.isBodyweight = isBodyweight
        self.recoveryActivityType = recoveryActivityType
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

    /// Whether this cardio exercise should log time
    var tracksTime: Bool {
        exerciseType == .cardio && cardioMetric.tracksTime
    }

    /// Whether this cardio exercise should log distance
    var tracksDistance: Bool {
        exerciseType == .cardio && cardioMetric.tracksDistance
    }

    /// Whether this mobility exercise should log reps
    var mobilityTracksReps: Bool {
        exerciseType == .mobility && mobilityTracking.tracksReps
    }

    /// Whether this mobility exercise should log duration
    var mobilityTracksDuration: Bool {
        exerciseType == .mobility && mobilityTracking.tracksDuration
    }
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

// MARK: - Exercise Library

struct ExerciseLibrary {
    static let shared = ExerciseLibrary()

    let exercises: [ExerciseTemplate]

    private init() {
        exercises = [
            // CHEST
            ExerciseTemplate(
                name: "Bench Press", category: .chest,
                primary: [.chest], secondary: [.shoulders, .triceps]
            ),
            ExerciseTemplate(
                name: "Incline Bench Press", category: .chest,
                primary: [.chest], secondary: [.shoulders, .triceps]
            ),
            ExerciseTemplate(
                name: "Dumbbell Fly", category: .chest,
                primary: [.chest], secondary: []
            ),
            ExerciseTemplate(
                name: "Push-Up", category: .chest,
                primary: [.chest], secondary: [.triceps, .shoulders]
            ),
            ExerciseTemplate(
                name: "Cable Crossover", category: .chest,
                primary: [.chest], secondary: []
            ),
            ExerciseTemplate(
                name: "Dips (Chest)", category: .chest,
                primary: [.chest], secondary: [.triceps, .shoulders]
            ),

            // BACK
            ExerciseTemplate(
                name: "Deadlift", category: .back,
                primary: [.back, .hamstrings, .glutes], secondary: [.forearms, .core]
            ),
            ExerciseTemplate(
                name: "Barbell Row", category: .back,
                primary: [.back], secondary: [.biceps, .forearms]
            ),
            ExerciseTemplate(
                name: "Pull-Up", category: .back,
                primary: [.back], secondary: [.biceps, .forearms]
            ),
            ExerciseTemplate(
                name: "Chin-Up", category: .back,
                primary: [.back, .biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                name: "Lat Pulldown", category: .back,
                primary: [.back], secondary: [.biceps]
            ),
            ExerciseTemplate(
                name: "Seated Cable Row", category: .back,
                primary: [.back], secondary: [.biceps]
            ),
            ExerciseTemplate(
                name: "Face Pull", category: .back,
                primary: [.shoulders, .back], secondary: []
            ),
            ExerciseTemplate(
                name: "Dumbbell Row", category: .back,
                primary: [.back], secondary: [.biceps]
            ),

            // SHOULDERS
            ExerciseTemplate(
                name: "Overhead Press", category: .shoulders,
                primary: [.shoulders], secondary: [.triceps]
            ),
            ExerciseTemplate(
                name: "Dumbbell Shoulder Press", category: .shoulders,
                primary: [.shoulders], secondary: [.triceps]
            ),
            ExerciseTemplate(
                name: "Lateral Raise", category: .shoulders,
                primary: [.shoulders], secondary: []
            ),
            ExerciseTemplate(
                name: "Front Raise", category: .shoulders,
                primary: [.shoulders], secondary: []
            ),
            ExerciseTemplate(
                name: "Reverse Fly", category: .shoulders,
                primary: [.shoulders, .back], secondary: []
            ),
            ExerciseTemplate(
                name: "Upright Row", category: .shoulders,
                primary: [.shoulders], secondary: [.biceps]
            ),
            ExerciseTemplate(
                name: "Shrugs", category: .shoulders,
                primary: [.shoulders, .back], secondary: [.forearms]
            ),

            // BICEPS
            ExerciseTemplate(
                name: "Barbell Curl", category: .biceps,
                primary: [.biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                name: "Dumbbell Curl", category: .biceps,
                primary: [.biceps], secondary: [.forearms]
            ),
            ExerciseTemplate(
                name: "Hammer Curl", category: .biceps,
                primary: [.biceps, .forearms], secondary: []
            ),
            ExerciseTemplate(
                name: "Preacher Curl", category: .biceps,
                primary: [.biceps], secondary: []
            ),
            ExerciseTemplate(
                name: "Incline Dumbbell Curl", category: .biceps,
                primary: [.biceps], secondary: []
            ),

            // TRICEPS
            ExerciseTemplate(
                name: "Tricep Pushdown", category: .triceps,
                primary: [.triceps], secondary: []
            ),
            ExerciseTemplate(
                name: "Skull Crusher", category: .triceps,
                primary: [.triceps], secondary: []
            ),
            ExerciseTemplate(
                name: "Tricep Dip", category: .triceps,
                primary: [.triceps], secondary: [.chest, .shoulders]
            ),
            ExerciseTemplate(
                name: "Close Grip Bench Press", category: .triceps,
                primary: [.triceps], secondary: [.chest, .shoulders]
            ),
            ExerciseTemplate(
                name: "Overhead Tricep Extension", category: .triceps,
                primary: [.triceps], secondary: []
            ),

            // LEGS
            ExerciseTemplate(
                name: "Back Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings, .core]
            ),
            ExerciseTemplate(
                name: "Front Squat", category: .legs,
                primary: [.quads], secondary: [.glutes, .core]
            ),
            ExerciseTemplate(
                name: "Romanian Deadlift", category: .legs,
                primary: [.hamstrings, .glutes], secondary: [.back]
            ),
            ExerciseTemplate(
                name: "Leg Press", category: .legs,
                primary: [.quads, .glutes], secondary: []
            ),
            ExerciseTemplate(
                name: "Lunge", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                name: "Bulgarian Split Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                name: "Leg Curl", category: .legs,
                primary: [.hamstrings], secondary: []
            ),
            ExerciseTemplate(
                name: "Leg Extension", category: .legs,
                primary: [.quads], secondary: []
            ),
            ExerciseTemplate(
                name: "Calf Raise", category: .legs,
                primary: [.calves], secondary: []
            ),
            ExerciseTemplate(
                name: "Hip Thrust", category: .legs,
                primary: [.glutes], secondary: [.hamstrings]
            ),
            ExerciseTemplate(
                name: "Goblet Squat", category: .legs,
                primary: [.quads, .glutes], secondary: [.core]
            ),
            ExerciseTemplate(
                name: "Sumo Deadlift", category: .legs,
                primary: [.glutes, .hamstrings, .quads], secondary: [.back]
            ),

            // CORE
            ExerciseTemplate(
                name: "Plank", category: .core, exerciseType: .isometric,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                name: "Crunch", category: .core,
                primary: [.core], secondary: []
            ),
            ExerciseTemplate(
                name: "Hanging Leg Raise", category: .core,
                primary: [.core], secondary: [.forearms]
            ),
            ExerciseTemplate(
                name: "Russian Twist", category: .core,
                primary: [.core], secondary: []
            ),
            ExerciseTemplate(
                name: "Cable Woodchop", category: .core,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                name: "Ab Wheel Rollout", category: .core,
                primary: [.core], secondary: [.shoulders]
            ),
            ExerciseTemplate(
                name: "Dead Bug", category: .core,
                primary: [.core], secondary: []
            ),

            // CARDIO
            ExerciseTemplate(
                name: "Treadmill Run", category: .cardio, exerciseType: .cardio,
                primary: [.quads, .hamstrings, .calves], secondary: [.glutes, .core]
            ),
            ExerciseTemplate(
                name: "Cycling", category: .cardio, exerciseType: .cardio,
                primary: [.quads], secondary: [.hamstrings, .calves]
            ),
            ExerciseTemplate(
                name: "Rowing", category: .cardio, exerciseType: .cardio,
                primary: [.back, .quads], secondary: [.biceps, .core]
            ),
            ExerciseTemplate(
                name: "Jump Rope", category: .cardio, exerciseType: .cardio,
                primary: [.calves], secondary: [.shoulders, .core]
            ),
            ExerciseTemplate(
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
