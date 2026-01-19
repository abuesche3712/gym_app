//
//  FormattingHelpers.swift
//  gym app
//
//  Shared formatting functions used throughout the app
//

import Foundation

// MARK: - Time Formatting

/// Formats seconds as "M:SS" (e.g., 90 -> "1:30")
func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d", mins, secs)
}

/// Formats duration with context - shows seconds only if under a minute
/// e.g., 45 -> "45s", 90 -> "1:30", 3600 -> "1:00:00", 3665 -> "1:01:05"
func formatDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, mins, secs)
    }
    if mins > 0 {
        return String(format: "%d:%02d", mins, secs)
    }
    return "\(secs)s"
}

/// Formats duration with "min" suffix for longer durations
/// e.g., 45 -> "45s", 120 -> "2 min", 150 -> "2:30"
func formatDurationVerbose(_ seconds: Int) -> String {
    if seconds >= 60 {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(mins) min"
    }
    return "\(seconds)s"
}

// MARK: - Weight Formatting

/// Formats weight, removing decimal if it's a whole number
/// e.g., 135.0 -> "135", 137.5 -> "137.5"
func formatWeight(_ weight: Double) -> String {
    if weight == floor(weight) {
        return "\(Int(weight))"
    }
    return String(format: "%.1f", weight)
}

// MARK: - Distance Formatting

/// Formats distance with unit suffix
/// e.g., 1.0, .miles -> "1 mi", 1.5, .kilometers -> "1.5 km"
func formatDistance(_ distance: Double, unit: DistanceUnit) -> String {
    if distance == floor(distance) {
        return "\(Int(distance)) \(unit.abbreviation)"
    }
    return String(format: "%.1f %@", distance, unit.abbreviation)
}

/// Formats distance value only, no unit
/// e.g., 1.0 -> "1", 1.5 -> "1.5"
func formatDistanceValue(_ distance: Double) -> String {
    if distance == floor(distance) {
        return "\(Int(distance))"
    }
    return String(format: "%.1f", distance)
}

// MARK: - Height Formatting

/// Formats height in inches with unit suffix
/// e.g., 24.0 -> "24 in", 36.5 -> "36.5 in"
func formatHeight(_ height: Double) -> String {
    if height == floor(height) {
        return "\(Int(height)) in"
    }
    return String(format: "%.1f in", height)
}

/// Formats height value only, no unit
/// e.g., 24.0 -> "24", 36.5 -> "36.5"
func formatHeightValue(_ height: Double) -> String {
    if height == floor(height) {
        return "\(Int(height))"
    }
    return String(format: "%.1f", height)
}

// MARK: - Pace Formatting

/// Formats pace in seconds per unit as "M:SS"
/// e.g., 480 -> "8:00", 510 -> "8:30"
func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace) / 60
    let seconds = Int(pace) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Volume Formatting

/// Formats volume with "k" suffix for thousands
/// e.g., 500 -> "500", 1500 -> "1.5k"
func formatVolume(_ volume: Double) -> String {
    if volume >= 1000 {
        return String(format: "%.1fk", volume / 1000)
    }
    return "\(Int(volume))"
}
