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
/// e.g., 45 -> "45s", 90 -> "1:30", 3600 -> "60:00"
func formatDuration(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
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

/// Formats distance, removing decimal if it's a whole number
/// e.g., 1.0 -> "1", 1.5 -> "1.50"
func formatDistance(_ distance: Double) -> String {
    if distance == floor(distance) {
        return "\(Int(distance))"
    }
    return String(format: "%.2f", distance)
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
