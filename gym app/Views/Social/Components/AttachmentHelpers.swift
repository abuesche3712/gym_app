//
//  AttachmentHelpers.swift
//  gym app
//
//  Shared types and formatting helpers for attachment cards
//

import SwiftUI

// MARK: - Detected Exercise/Set Type

enum AttachmentDetectedType {
    case strength
    case cardio
    case isometric
    case band
    case unknown
}

// MARK: - Detection

/// Detect exercise type from an array of sets (uses first completed set).
/// Checks cardio before band to match exercise attachment card behavior.
func detectExerciseType(from sets: [SetData]) -> AttachmentDetectedType {
    let firstCompleted = sets.first { $0.completed }
    guard let set = firstCompleted else { return .unknown }

    if let holdTime = set.holdTime, holdTime > 0 {
        return .isometric
    } else if (set.duration != nil && set.duration! > 0) || (set.distance != nil && set.distance! > 0) {
        if set.reps == nil || set.reps == 0 {
            return .cardio
        }
    }
    if let bandColor = set.bandColor, !bandColor.isEmpty {
        return .band
    }
    if set.weight != nil || set.reps != nil {
        return .strength
    }
    return .unknown
}

/// Detect set type from a single set.
/// Checks band before cardio to match set attachment card behavior.
func detectSetType(from set: SetData) -> AttachmentDetectedType {
    if let holdTime = set.holdTime, holdTime > 0 {
        return .isometric
    }
    if let bandColor = set.bandColor, !bandColor.isEmpty {
        return .band
    }
    if (set.duration != nil && set.duration! > 0) || (set.distance != nil && set.distance! > 0) {
        if set.reps == nil || set.reps == 0 {
            return .cardio
        }
    }
    return .strength
}

// MARK: - Icons & Colors

func iconForDetectedType(_ type: AttachmentDetectedType) -> String {
    switch type {
    case .strength, .band: return "dumbbell.fill"
    case .cardio: return "figure.run"
    case .isometric: return "timer"
    case .unknown: return "dumbbell.fill"
    }
}

func colorForDetectedType(_ type: AttachmentDetectedType) -> Color {
    switch type {
    case .strength: return AppColors.dominant
    case .cardio: return AppColors.accent1
    case .isometric: return AppColors.accent2
    case .band: return AppColors.accent3
    case .unknown: return AppColors.dominant
    }
}

// MARK: - Formatting

/// Format duration as "1h 30m", "5m 15s", or "30s"
func formatDurationCompact(_ seconds: Int) -> String {
    if seconds >= 3600 {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        return "\(hours)h \(mins)m"
    } else if seconds >= 60 {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(mins)m"
    } else {
        return "\(seconds)s"
    }
}

/// Format duration as "1h 30m", "5:15", or "30s"
func formatDurationClock(_ seconds: Int) -> String {
    if seconds >= 3600 {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        return "\(hours)h \(mins)m"
    } else if seconds >= 60 {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(mins)m"
    } else {
        return "\(seconds)s"
    }
}

/// Format distance with unit abbreviation (e.g., "5.2 km")
func formatDistanceWithUnit(_ distance: Double, unit: DistanceUnit?) -> String {
    let unitAbbr = unit?.abbreviation ?? "m"
    if distance.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(distance)) \(unitAbbr)"
    }
    return String(format: "%.1f \(unitAbbr)", distance)
}

/// Format distance value only (e.g., "5.2")
func formatDistanceNumeric(_ distance: Double) -> String {
    if distance.truncatingRemainder(dividingBy: 1) == 0 {
        return "\(Int(distance))"
    }
    return String(format: "%.1f", distance)
}
