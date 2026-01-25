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

    // Interval mode fields
    let isInterval: Bool
    let workDuration: Int?
    let intervalRestDuration: Int?

    // AMRAP mode fields
    let isAMRAP: Bool
    let amrapTimeLimit: Int?

    // Unilateral mode
    let isUnilateral: Bool

    // RPE tracking
    let trackRPE: Bool

    // Multi-measurable targets (e.g., Height: 24in, Weight: 20lbs for weighted box jumps)
    let implementMeasurables: [ImplementMeasurableTarget]

    init(
        id: String,
        setGroupIndex: Int,
        setIndex: Int,
        setNumber: Int,
        setData: SetData,
        targetWeight: Double? = nil,
        targetReps: Int? = nil,
        targetDuration: Int? = nil,
        targetHoldTime: Int? = nil,
        targetDistance: Double? = nil,
        restPeriod: Int? = nil,
        isInterval: Bool = false,
        workDuration: Int? = nil,
        intervalRestDuration: Int? = nil,
        isAMRAP: Bool = false,
        amrapTimeLimit: Int? = nil,
        isUnilateral: Bool = false,
        trackRPE: Bool = true,
        implementMeasurables: [ImplementMeasurableTarget] = []
    ) {
        self.id = id
        self.setGroupIndex = setGroupIndex
        self.setIndex = setIndex
        self.setNumber = setNumber
        self.setData = setData
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetDuration = targetDuration
        self.targetHoldTime = targetHoldTime
        self.targetDistance = targetDistance
        self.restPeriod = restPeriod
        self.isInterval = isInterval
        self.workDuration = workDuration
        self.intervalRestDuration = intervalRestDuration
        self.isAMRAP = isAMRAP
        self.amrapTimeLimit = amrapTimeLimit
        self.isUnilateral = isUnilateral
        self.trackRPE = trackRPE
        self.implementMeasurables = implementMeasurables
    }
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
