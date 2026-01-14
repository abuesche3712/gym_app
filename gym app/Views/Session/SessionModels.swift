//
//  SessionModels.swift
//  gym app
//
//  Helper structs for session views
//

import Foundation

// MARK: - Flat Set

/// Flattened set representation for easier iteration in views
struct FlatSet: Identifiable {
    let id: String
    let setGroupIndex: Int
    let setIndex: Int
    let setNumber: Int
    let setData: SetData
    let targetWeight: Double?
    let targetReps: Int?
    let targetDuration: Int?
    let targetHoldTime: Int?
    let targetDistance: Double?
    let restPeriod: Int?
}

// MARK: - Recent Set

/// Represents a recently completed set for editing
struct RecentSet: Identifiable {
    let id = UUID()
    let moduleIndex: Int
    let exerciseIndex: Int
    let setGroupIndex: Int
    let setIndex: Int
    let exerciseName: String
    let exerciseType: ExerciseType
    let setData: SetData
}

// MARK: - Set Location

/// Location reference for a set within the session hierarchy
struct SetLocation: Identifiable {
    let id = UUID()
    let moduleIndex: Int
    let exerciseIndex: Int
    let setGroupIndex: Int
    let setIndex: Int
    let exerciseName: String
    let exerciseType: ExerciseType
    let setData: SetData
    let setNumber: Int
}
