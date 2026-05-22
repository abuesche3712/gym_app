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

extension FlatSet {
    /// Returns the previous completed set that represents this same row.
    /// Matching the set group keeps AMRAP and prescribed rows from sharing defaults.
    func lastCompletedMatchingSet(
        in lastSessionExercise: SessionExercise?,
        currentExercise: SessionExercise,
        side: Side? = nil
    ) -> SetData? {
        guard let previousGroup = lastMatchingSetGroup(
            in: lastSessionExercise,
            currentExercise: currentExercise
        ) else {
            return nil
        }

        let completedSets = previousGroup.sets.filter { previousSet in
            previousSet.completed && (side == nil || previousSet.side == side)
        }

        if let sameSetNumber = completedSets.first(where: { $0.setNumber == setData.setNumber }) {
            return sameSetNumber
        }

        if previousGroup.sets.indices.contains(setIndex) {
            let indexedSet = previousGroup.sets[setIndex]
            if indexedSet.completed && (side == nil || indexedSet.side == side) {
                return indexedSet
            }
        }

        return completedSets.first
    }

    /// Exercise-level suggestions belong to AMRAP rows when the exercise uses AMRAP.
    /// Fixed prescription rows keep their template targets in that mixed-mode case.
    func shouldApplyProgressionSuggestion(in exercise: SessionExercise) -> Bool {
        if exercise.completedSetGroups.contains(where: \.isAMRAP) {
            return isAMRAP
        }

        return !isAMRAP
    }

    private func lastMatchingSetGroup(
        in lastSessionExercise: SessionExercise?,
        currentExercise: SessionExercise
    ) -> CompletedSetGroup? {
        guard let lastSessionExercise else { return nil }

        let currentGroup = currentExercise.completedSetGroups.indices.contains(setGroupIndex)
            ? currentExercise.completedSetGroups[setGroupIndex]
            : nil

        if let currentGroup,
           let sameGroup = lastSessionExercise.completedSetGroups.first(where: {
               $0.setGroupId == currentGroup.setGroupId
           }) {
            return sameGroup
        }

        if lastSessionExercise.completedSetGroups.indices.contains(setGroupIndex) {
            let sameIndex = lastSessionExercise.completedSetGroups[setGroupIndex]
            if sameIndex.matchesMode(of: self) {
                return sameIndex
            }
        }

        return lastSessionExercise.completedSetGroups.first(where: { $0.matchesMode(of: self) })
    }
}

private extension CompletedSetGroup {
    func matchesMode(of flatSet: FlatSet) -> Bool {
        isAMRAP == flatSet.isAMRAP && isInterval == flatSet.isInterval
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
