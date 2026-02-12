//
//  ProgressionRule.swift
//  gym app
//
//  Defines progression rules for automatic weight/rep suggestions
//

import Foundation

// MARK: - Program Progression Policy

/// Controls which progression engine a program uses.
enum ProgressionPolicy: String, Codable, CaseIterable, Identifiable {
    case legacy
    case adaptive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .legacy: return "Legacy"
        case .adaptive: return "Adaptive"
        }
    }

    var shortDescription: String {
        switch self {
        case .legacy:
            return "Uses default progression for all strength exercises."
        case .adaptive:
            return "Uses per-exercise rules and prior session outcomes."
        }
    }
}

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

// MARK: - Progression Strategy

/// Strategy for deciding when/how progression should be applied.
enum ProgressionStrategy: String, Codable, CaseIterable, Identifiable {
    case linear
    case doubleProgression = "double_progression"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .doubleProgression: return "Double Progression"
        }
    }
}

// MARK: - Progression Rule

/// Defines how to calculate progression for an exercise
struct ProgressionRule: Codable, Hashable, Identifiable {
    var id: UUID
    var targetMetric: ProgressionMetric
    var strategy: ProgressionStrategy
    var percentageIncrease: Double      // e.g., 2.5 for 2.5%
    var roundingIncrement: Double       // e.g., 5.0 for nearest 5 lbs
    var minimumIncrease: Double?        // Optional floor (e.g., minimum 5 lbs increase)

    init(
        id: UUID = UUID(),
        targetMetric: ProgressionMetric = .weight,
        strategy: ProgressionStrategy = .linear,
        percentageIncrease: Double = 2.5,
        roundingIncrement: Double = 5.0,
        minimumIncrease: Double? = 5.0
    ) {
        self.id = id
        self.targetMetric = targetMetric
        self.strategy = strategy
        self.percentageIncrease = percentageIncrease
        self.roundingIncrement = roundingIncrement
        self.minimumIncrease = minimumIncrease
    }

    private enum CodingKeys: String, CodingKey {
        case id, targetMetric, strategy, percentageIncrease, roundingIncrement, minimumIncrease
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        targetMetric = try container.decodeIfPresent(ProgressionMetric.self, forKey: .targetMetric) ?? .weight
        strategy = try container.decodeIfPresent(ProgressionStrategy.self, forKey: .strategy) ?? .linear
        percentageIncrease = try container.decodeIfPresent(Double.self, forKey: .percentageIncrease) ?? 2.5
        roundingIncrement = try container.decodeIfPresent(Double.self, forKey: .roundingIncrement) ?? 5.0
        minimumIncrease = try container.decodeIfPresent(Double.self, forKey: .minimumIncrease)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(targetMetric, forKey: .targetMetric)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(percentageIncrease, forKey: .percentageIncrease)
        try container.encode(roundingIncrement, forKey: .roundingIncrement)
        try container.encodeIfPresent(minimumIncrease, forKey: .minimumIncrease)
    }

    // MARK: - Presets

    /// Conservative progression: 2.5% increase, 5 lb rounding, 5 lb minimum
    static let conservative = ProgressionRule(
        targetMetric: .weight,
        strategy: .linear,
        percentageIncrease: 2.5,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Moderate progression: 5% increase, 5 lb rounding, 5 lb minimum
    static let moderate = ProgressionRule(
        targetMetric: .weight,
        strategy: .linear,
        percentageIncrease: 5.0,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Aggressive progression: 7.5% increase, 5 lb rounding, 5 lb minimum
    static let aggressive = ProgressionRule(
        targetMetric: .weight,
        strategy: .linear,
        percentageIncrease: 7.5,
        roundingIncrement: 5.0,
        minimumIncrease: 5.0
    )

    /// Fine-grained progression: 2.5% increase, 2.5 lb rounding (for dumbbells/isolation)
    static let fineGrained = ProgressionRule(
        targetMetric: .weight,
        strategy: .linear,
        percentageIncrease: 2.5,
        roundingIncrement: 2.5,
        minimumIncrease: 2.5
    )

    /// Rep-based progression: increase reps by 5%
    static let repProgression = ProgressionRule(
        targetMetric: .reps,
        strategy: .linear,
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
            if strategy == .doubleProgression {
                return "Double progression, +\(percentFormatted)% when rep goal is met"
            }
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
    let appliedOutcome: ProgressionRecommendation?
    let isOutcomeAdjusted: Bool

    init(
        baseValue: Double,
        suggestedValue: Double,
        metric: ProgressionMetric,
        percentageApplied: Double,
        appliedOutcome: ProgressionRecommendation? = nil,
        isOutcomeAdjusted: Bool = false
    ) {
        self.baseValue = baseValue
        self.suggestedValue = suggestedValue
        self.metric = metric
        self.percentageApplied = percentageApplied
        self.appliedOutcome = appliedOutcome
        self.isOutcomeAdjusted = isOutcomeAdjusted
    }

    private enum CodingKeys: String, CodingKey {
        case baseValue, suggestedValue, metric, percentageApplied, appliedOutcome, isOutcomeAdjusted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseValue = try container.decode(Double.self, forKey: .baseValue)
        suggestedValue = try container.decode(Double.self, forKey: .suggestedValue)
        metric = try container.decode(ProgressionMetric.self, forKey: .metric)
        percentageApplied = try container.decode(Double.self, forKey: .percentageApplied)
        appliedOutcome = try container.decodeIfPresent(ProgressionRecommendation.self, forKey: .appliedOutcome)
        isOutcomeAdjusted = try container.decodeIfPresent(Bool.self, forKey: .isOutcomeAdjusted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseValue, forKey: .baseValue)
        try container.encode(suggestedValue, forKey: .suggestedValue)
        try container.encode(metric, forKey: .metric)
        try container.encode(percentageApplied, forKey: .percentageApplied)
        try container.encodeIfPresent(appliedOutcome, forKey: .appliedOutcome)
        try container.encode(isOutcomeAdjusted, forKey: .isOutcomeAdjusted)
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
