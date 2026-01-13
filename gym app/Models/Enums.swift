//
//  Enums.swift
//  gym app
//
//  Core enumerations for the gym tracking app
//

import Foundation

// MARK: - Module Types

enum ModuleType: String, Codable, CaseIterable, Identifiable {
    case warmup
    case prehab
    case explosive
    case strength
    case cardioLong = "cardio_long"
    case cardioSpeed = "cardio_speed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: return "Warmup"
        case .prehab: return "Prehab"
        case .explosive: return "Explosive"
        case .strength: return "Strength"
        case .cardioLong: return "Cardio (Long)"
        case .cardioSpeed: return "Cardio (Speed)"
        }
    }

    var icon: String {
        switch self {
        case .warmup: return "flame"
        case .prehab: return "bandage"
        case .explosive: return "bolt"
        case .strength: return "dumbbell"
        case .cardioLong: return "figure.run"
        case .cardioSpeed: return "timer"
        }
    }

    var color: String {
        switch self {
        case .warmup: return "orange"
        case .prehab: return "green"
        case .explosive: return "yellow"
        case .strength: return "red"
        case .cardioLong: return "blue"
        case .cardioSpeed: return "purple"
        }
    }
}

// MARK: - Exercise Types

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case strength
    case cardio
    case mobility
    case isometric
    case explosive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        case .isometric: return "Isometric"
        case .explosive: return "Explosive"
        }
    }
}

// MARK: - Metric Types

enum MetricType: String, Codable, CaseIterable {
    case weight
    case reps
    case sets
    case duration
    case distance
    case pace
    case heartRate
    case holdTime
    case height
    case rpe

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .sets: return "Sets"
        case .duration: return "Duration"
        case .distance: return "Distance"
        case .pace: return "Pace"
        case .heartRate: return "Heart Rate"
        case .holdTime: return "Hold Time"
        case .height: return "Height"
        case .rpe: return "RPE"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "lbs"
        case .reps: return "reps"
        case .sets: return "sets"
        case .duration: return "sec"
        case .distance: return "mi"
        case .pace: return "/mi"
        case .heartRate: return "bpm"
        case .holdTime: return "sec"
        case .height: return "in"
        case .rpe: return "/10"
        }
    }
}

// MARK: - Sync Status

enum SyncStatus: String, Codable {
    case synced
    case pendingSync
    case syncing
    case syncFailed
    case conflict
}

// MARK: - Sync Operation

enum SyncOperation: String, Codable {
    case create
    case update
    case delete
}

// MARK: - Progression Rule Types

enum ProgressionType: String, Codable, CaseIterable {
    case none
    case linear
    case doubleProgression
    case rpeBased
    case wave
    case topSetBackoff
    case durationIncrease
    case intervalProgression
    case qualityGated
    case manualConservative

    var displayName: String {
        switch self {
        case .none: return "None"
        case .linear: return "Linear"
        case .doubleProgression: return "Double Progression"
        case .rpeBased: return "RPE Based"
        case .wave: return "Wave"
        case .topSetBackoff: return "Top Set + Back-off"
        case .durationIncrease: return "Duration Increase"
        case .intervalProgression: return "Interval Progression"
        case .qualityGated: return "Quality Gated"
        case .manualConservative: return "Manual (Conservative)"
        }
    }
}

// MARK: - Weight Unit

enum WeightUnit: String, Codable, CaseIterable {
    case lbs
    case kg

    var displayName: String {
        switch self {
        case .lbs: return "Pounds (lbs)"
        case .kg: return "Kilograms (kg)"
        }
    }

    var abbreviation: String {
        rawValue
    }
}

// MARK: - Distance Unit

enum DistanceUnit: String, Codable, CaseIterable {
    case miles
    case kilometers

    var displayName: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }
}
