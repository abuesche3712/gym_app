//
//  StructuralChange.swift
//  gym app
//
//  Represents structural changes made during a workout session
//  that can optionally be committed back to module templates
//

import Foundation

/// Represents a structural change made during a workout session
enum StructuralChange: Identifiable, Equatable {
    /// Set count changed for an existing exercise
    case setCountChanged(
        exerciseInstanceId: UUID,
        exerciseName: String,
        moduleId: UUID,
        moduleName: String,
        from: Int,
        to: Int
    )

    /// New exercise added mid-session
    case exerciseAdded(
        sessionExercise: SessionExercise,
        moduleId: UUID,
        moduleName: String,
        atIndex: Int
    )

    /// Exercise removed/skipped from the workout
    case exerciseRemoved(
        exerciseInstanceId: UUID,
        exerciseName: String,
        moduleId: UUID,
        moduleName: String
    )

    /// Exercise reordered within the module
    case exerciseReordered(
        exerciseInstanceId: UUID,
        exerciseName: String,
        moduleId: UUID,
        moduleName: String,
        fromIndex: Int,
        toIndex: Int
    )

    /// Exercise substituted (name changed during session)
    case exerciseSubstituted(
        sourceExerciseInstanceId: UUID,
        originalName: String,
        newName: String,
        moduleId: UUID,
        moduleName: String
    )

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .setCountChanged(let id, _, _, _, _, _):
            return "setcount-\(id.uuidString)"
        case .exerciseAdded(let ex, _, _, _):
            return "added-\(ex.id.uuidString)"
        case .exerciseRemoved(let id, _, _, _):
            return "removed-\(id.uuidString)"
        case .exerciseReordered(let id, _, _, _, _, _):
            return "reordered-\(id.uuidString)"
        case .exerciseSubstituted(let id, _, _, _, _):
            return "substituted-\(id.uuidString)"
        }
    }

    // MARK: - Computed Properties

    var moduleId: UUID {
        switch self {
        case .setCountChanged(_, _, let moduleId, _, _, _):
            return moduleId
        case .exerciseAdded(_, let moduleId, _, _):
            return moduleId
        case .exerciseRemoved(_, _, let moduleId, _):
            return moduleId
        case .exerciseReordered(_, _, let moduleId, _, _, _):
            return moduleId
        case .exerciseSubstituted(_, _, _, let moduleId, _):
            return moduleId
        }
    }

    var moduleName: String {
        switch self {
        case .setCountChanged(_, _, _, let name, _, _):
            return name
        case .exerciseAdded(_, _, let name, _):
            return name
        case .exerciseRemoved(_, _, _, let name):
            return name
        case .exerciseReordered(_, _, _, let name, _, _):
            return name
        case .exerciseSubstituted(_, _, _, _, let name):
            return name
        }
    }

    var exerciseName: String {
        switch self {
        case .setCountChanged(_, let name, _, _, _, _):
            return name
        case .exerciseAdded(let ex, _, _, _):
            return ex.exerciseName
        case .exerciseRemoved(_, let name, _, _):
            return name
        case .exerciseReordered(_, let name, _, _, _, _):
            return name
        case .exerciseSubstituted(_, _, let name, _, _):
            return name
        }
    }

    /// Human-readable description of the change
    var description: String {
        switch self {
        case .setCountChanged(_, let name, _, _, let from, let to):
            let direction = to > from ? "Added" : "Removed"
            let diff = abs(to - from)
            let setWord = diff == 1 ? "set" : "sets"
            return "\(direction) \(diff) \(setWord) for \(name) (\(from) → \(to))"

        case .exerciseAdded(let ex, _, _, _):
            return "Added \(ex.exerciseName)"

        case .exerciseRemoved(_, let name, _, _):
            return "Removed \(name)"

        case .exerciseReordered(_, let name, _, _, let from, let to):
            let direction = to < from ? "up" : "down"
            return "Moved \(name) \(direction)"

        case .exerciseSubstituted(_, let originalName, let newName, _, _):
            return "\(originalName) → \(newName)"
        }
    }

    /// SF Symbol icon for UI display
    var icon: String {
        switch self {
        case .setCountChanged(_, _, _, _, let from, let to):
            return to > from ? "plus.circle" : "minus.circle"
        case .exerciseAdded:
            return "plus.square"
        case .exerciseRemoved:
            return "trash"
        case .exerciseReordered:
            return "arrow.up.arrow.down"
        case .exerciseSubstituted:
            return "arrow.triangle.swap"
        }
    }

    /// Color for the change type
    var color: String {
        switch self {
        case .setCountChanged(_, _, _, _, let from, let to):
            return to > from ? "success" : "warning"
        case .exerciseAdded:
            return "success"
        case .exerciseRemoved:
            return "error"
        case .exerciseReordered:
            return "dominant"
        case .exerciseSubstituted:
            return "dominant"
        }
    }

    // MARK: - Equatable

    static func == (lhs: StructuralChange, rhs: StructuralChange) -> Bool {
        lhs.id == rhs.id
    }
}
