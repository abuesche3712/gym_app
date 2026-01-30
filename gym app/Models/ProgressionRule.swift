//
//  ProgressionRule.swift
//  gym app
//
//  Defines progression rules for automatic weight/rep suggestions
//

import Foundation

// MARK: - Progression Metric

/// The metric to apply progression to
enum ProgressionMetric: String, Codable, CaseIterable, Identifiable {
    case weight
    case reps

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "lbs"
        case .reps: return "reps"
        }
    }
}

// MARK: - Progression Rule

/// Defines how to calculate progression for an exercise
struct ProgressionRule: Codable, Hashable, Identifiable {
    var id: UUID
    var targetMetric: ProgressionMetric
    var percentageIncrease: Double      // e.g., 2.5 for 2.5%
    var roundingIncrement: Double       // e.g., 5.0 for nearest 5 lbs
    var minimumIncrease: Double?        // Optional floor (e.g., minimum 5 lbs increase)

    init(
        id: UUID = UUID(),
        targetMetric: ProgressionMetric = .weight,
        percentageIncrease: Double = 2.5,
        roundingIncrement: Double = 5.0,
        minimumIncrease: Double? = 5.0
    ) {
        self.id = id
        self.targetMetric = targetMetric
        self.percentageIncrease = percentageIncrease
        self.roundingIncrement = roundingIncrement
        self.minimumIncrease = minimumIncrease
    }

    // MARK: - Presets

    /// Conservative progression: 2.5% increase, 5 lb rounding, 5 lb minimum
    static let conservative = ProgressionRule(
        targetMetric: .weight,
        percentageIncrease: 2.5,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Moderate progression: 5% increase, 5 lb rounding, 5 lb minimum
    static let moderate = ProgressionRule(
        targetMetric: .weight,
        percentageIncrease: 5.0,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Aggressive progression: 7.5% increase, 5 lb rounding, 5 lb minimum
    static let aggressive = ProgressionRule(
        targetMetric: .weight,
        percentageIncrease: 7.5,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Fine-grained progression: 2.5% increase, 2.5 lb rounding (for dumbbells/isolation)
    static let fineGrained = ProgressionRule(
        targetMetric: .weight,
        percentageIncrease: 2.5,
        roundingIncrement: 2.5,
        minimumIncrease: 2.5
    )

    /// Rep-based progression: increase reps by 5%
    static let repProgression = ProgressionRule(
        targetMetric: .reps,
        percentageIncrease: 5.0,
        roundingIncrement: 1.0,
        minimumIncrease: 1.0
    )

    // MARK: - Display

    var displayDescription: String {
        let percentFormatted = percentageIncrease.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", percentageIncrease)
            : String(format: "%.1f", percentageIncrease)

        switch targetMetric {
        case .weight:
            return "+\(percentFormatted)%, round to \(Int(roundingIncrement)) lbs"
        case .reps:
            return "+\(percentFormatted)%, round to \(Int(roundingIncrement)) reps"
        }
    }
}

// MARK: - Progression Suggestion

/// A calculated progression suggestion for an exercise
struct ProgressionSuggestion: Codable, Hashable {
    let baseValue: Double           // Previous session value (e.g., 130 lbs)
    let suggestedValue: Double      // Calculated value (e.g., 135 lbs)
    let metric: ProgressionMetric
    let percentageApplied: Double   // Actual % increase after rounding

    init(
        baseValue: Double,
        suggestedValue: Double,
        metric: ProgressionMetric,
        percentageApplied: Double
    ) {
        self.baseValue = baseValue
        self.suggestedValue = suggestedValue
        self.metric = metric
        self.percentageApplied = percentageApplied
    }

    /// Formatted string for display (e.g., "135 lbs (+3.8%)")
    var formattedSuggestion: String {
        let percentFormatted = String(format: "%.1f", percentageApplied)

        switch metric {
        case .weight:
            return "\(formatWeight(suggestedValue)) (+\(percentFormatted)%)"
        case .reps:
            return "\(Int(suggestedValue)) reps (+\(percentFormatted)%)"
        }
    }

    /// Just the value without percentage
    var formattedValue: String {
        switch metric {
        case .weight:
            return formatWeight(suggestedValue)
        case .reps:
            return "\(Int(suggestedValue))"
        }
    }
}
