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
    return String(format: "%.2f %@", distance, unit.abbreviation)
}

/// Formats distance value only, no unit
/// e.g., 1.0 -> "1", 1.5 -> "1.5", 1.75 -> "1.75"
func formatDistanceValue(_ distance: Double) -> String {
    if distance == floor(distance) {
        return "\(Int(distance))"
    }
    return String(format: "%.2f", distance)
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

// MARK: - Date Formatting

/// Shared date formatters for consistent styling (cached for performance)
enum DateFormatters {
    /// Medium date style (e.g., "Jan 19, 2026")
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Short date style (e.g., "1/19/26")
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    /// Time only (e.g., "3:45 PM")
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Relative date formatter (e.g., "Today", "Yesterday", "2 days ago")
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Day of week (e.g., "Monday")
    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Month and day (e.g., "Jan 19")
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

/// Formats a date in medium style (e.g., "Jan 19, 2026")
func formatDate(_ date: Date) -> String {
    DateFormatters.mediumDate.string(from: date)
}

/// Formats a date in short style (e.g., "1/19/26")
func formatDateShort(_ date: Date) -> String {
    DateFormatters.shortDate.string(from: date)
}

/// Formats a time (e.g., "3:45 PM")
func formatTime(_ date: Date) -> String {
    DateFormatters.time.string(from: date)
}

/// Formats a date relative to now (e.g., "Today", "Yesterday", "2 days ago")
func formatRelativeDate(_ date: Date) -> String {
    DateFormatters.relative.localizedString(for: date, relativeTo: Date())
}

/// Formats day of week (e.g., "Monday")
func formatDayOfWeek(_ date: Date) -> String {
    DateFormatters.dayOfWeek.string(from: date)
}

/// Formats month and day (e.g., "Jan 19")
func formatMonthDay(_ date: Date) -> String {
    DateFormatters.monthDay.string(from: date)
}

/// Formats a duration in minutes as human-readable string
/// e.g., 45 -> "45 min", 90 -> "1h 30m", 120 -> "2 hours"
func formatDurationMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(hours) hour\(hours > 1 ? "s" : "")"
    }
    return "\(minutes) min"
}

// MARK: - Set Data Formatting

/// Formats set data for display with full details including RPE
/// Handles all exercise types: strength, cardio, isometric, explosive, mobility, recovery
func formatSetData(_ set: SetData, exercise: SessionExercise) -> String {
    switch exercise.exerciseType {
    case .strength:
        if exercise.isBodyweight {
            if let reps = set.reps {
                if let weight = set.weight, weight > 0 {
                    var result = "BW + \(formatWeight(weight)) × \(reps)"
                    if let rpe = set.rpe { result += " @ \(rpe)" }
                    return result
                } else {
                    var result = "BW × \(reps)"
                    if let rpe = set.rpe { result += " @ \(rpe)" }
                    return result
                }
            }
        } else if let band = set.bandColor, !band.isEmpty, let reps = set.reps {
            var result = "\(band) × \(reps)"
            if let rpe = set.rpe { result += " @ \(rpe)" }
            return result
        } else if let weight = set.weight, let reps = set.reps {
            var result = "\(formatWeight(weight)) × \(reps)"
            if let rpe = set.rpe { result += " @ \(rpe)" }
            return result
        } else if let reps = set.reps {
            return "\(reps) reps"
        }

    case .cardio:
        var parts: [String] = []
        if let duration = set.duration, duration > 0 { parts.append(formatDuration(duration)) }
        if let distance = set.distance, distance > 0 {
            parts.append("\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " - ")

    case .isometric:
        if let holdTime = set.holdTime { return "\(formatDuration(holdTime)) hold" }

    case .explosive:
        var parts: [String] = []
        if let reps = set.reps { parts.append("\(reps) reps") }
        if let height = set.height { parts.append("@ \(formatHeight(height))") }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")

    case .mobility:
        if let reps = set.reps { return "\(reps) reps" }

    case .recovery:
        if let duration = set.duration { return formatDuration(duration) }
    }

    return "—"
}

/// Formats top set for compact display (without RPE)
/// e.g., "185 × 8" or "BW × 12" or "5:30" for cardio
func formatTopSet(_ set: SetData, exercise: SessionExercise) -> String {
    switch exercise.exerciseType {
    case .strength:
        if exercise.isBodyweight {
            if let reps = set.reps {
                if let weight = set.weight, weight > 0 {
                    return "BW + \(formatWeight(weight)) × \(reps)"
                } else {
                    return "BW × \(reps)"
                }
            }
        } else if let weight = set.weight, let reps = set.reps {
            return "\(formatWeight(weight)) × \(reps)"
        } else if let band = set.bandColor, let reps = set.reps {
            return "\(band) × \(reps)"
        }
    case .cardio:
        if let distance = set.distance {
            return "\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)"
        } else if let duration = set.duration {
            return formatDuration(duration)
        }
    case .isometric:
        if let holdTime = set.holdTime {
            return "\(formatDuration(holdTime)) hold"
        }
    default:
        if let reps = set.reps {
            return "\(reps) reps"
        }
    }
    return ""
}
