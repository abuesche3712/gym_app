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
    case duration
    case distance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .duration: return "Duration"
        case .distance: return "Distance"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "lbs"
        case .reps: return "reps"
        case .duration: return "sec"
        case .distance: return "mi"
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

    /// Cardio duration progression: increase time by 5%, 30-second rounding
    static let cardioDuration = ProgressionRule(
        targetMetric: .duration,
        strategy: .linear,
        percentageIncrease: 5.0,
        roundingIncrement: 30.0,
        minimumIncrease: 30.0
    )

    /// Cardio distance progression: increase distance by 5%, 0.05-mile rounding
    static let cardioDistance = ProgressionRule(
        targetMetric: .distance,
        strategy: .linear,
        percentageIncrease: 5.0,
        roundingIncrement: 0.05,
        minimumIncrease: 0.05
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
        case .duration:
            return "+\(percentFormatted)%, round to \(Int(roundingIncrement)) sec"
        case .distance:
            return "+\(percentFormatted)%, round to \(String(format: "%.2f", roundingIncrement)) mi"
        }
    }
}

// MARK: - Profile Schema

/// Readiness rules used before applying progression decisions.
struct ProgressionReadinessGate: Codable, Hashable {
    var minimumCompletedSetRatio: Double
    var minimumCompletedSets: Int
    var staleAfterDays: Int

    init(
        minimumCompletedSetRatio: Double = 0.7,
        minimumCompletedSets: Int = 2,
        staleAfterDays: Int = 42
    ) {
        self.minimumCompletedSetRatio = min(max(minimumCompletedSetRatio, 0), 1)
        self.minimumCompletedSets = max(0, minimumCompletedSets)
        self.staleAfterDays = max(1, staleAfterDays)
    }

    static let strengthDefault = ProgressionReadinessGate()
    static let cardioDefault = ProgressionReadinessGate(
        minimumCompletedSetRatio: 0.8,
        minimumCompletedSets: 1,
        staleAfterDays: 42
    )
}

/// Weighted decision thresholds for progress/stay/regress.
struct ProgressionDecisionPolicy: Codable, Hashable {
    var progressThreshold: Double
    var regressThreshold: Double
    var completionWeight: Double
    var performanceWeight: Double
    var effortWeight: Double
    var confidenceWeight: Double
    var streakWeight: Double

    init(
        progressThreshold: Double = 0.68,
        regressThreshold: Double = 0.38,
        completionWeight: Double = 0.30,
        performanceWeight: Double = 0.30,
        effortWeight: Double = 0.15,
        confidenceWeight: Double = 0.15,
        streakWeight: Double = 0.10
    ) {
        self.progressThreshold = min(max(progressThreshold, 0), 1)
        self.regressThreshold = min(max(regressThreshold, 0), 1)
        self.completionWeight = max(0, completionWeight)
        self.performanceWeight = max(0, performanceWeight)
        self.effortWeight = max(0, effortWeight)
        self.confidenceWeight = max(0, confidenceWeight)
        self.streakWeight = max(0, streakWeight)
    }

    static let strengthDefault = ProgressionDecisionPolicy()
    static let cardioDefault = ProgressionDecisionPolicy(
        progressThreshold: 0.70,
        regressThreshold: 0.40,
        completionWeight: 0.25,
        performanceWeight: 0.35,
        effortWeight: 0.05,
        confidenceWeight: 0.20,
        streakWeight: 0.15
    )
}

/// Hard caps/floors so progression remains safe and non-jumpy.
struct ProgressionGuardrails: Codable, Hashable {
    var maxProgressPercent: Double?
    var maxRegressPercent: Double?
    var floorValue: Double?
    var ceilingValue: Double?
    var minimumAbsoluteStep: Double?

    init(
        maxProgressPercent: Double? = 10,
        maxRegressPercent: Double? = 12,
        floorValue: Double? = 0,
        ceilingValue: Double? = nil,
        minimumAbsoluteStep: Double? = nil
    ) {
        self.maxProgressPercent = maxProgressPercent.map { max(0, $0) }
        self.maxRegressPercent = maxRegressPercent.map { max(0, $0) }
        self.floorValue = floorValue
        self.ceilingValue = ceilingValue
        self.minimumAbsoluteStep = minimumAbsoluteStep.map { max(0, $0) }
    }

    static let strengthDefault = ProgressionGuardrails()
    static let cardioDefault = ProgressionGuardrails(
        maxProgressPercent: 8,
        maxRegressPercent: 10,
        floorValue: 0,
        ceilingValue: nil,
        minimumAbsoluteStep: nil
    )
}

/// Per-exercise profile that keeps progression flexible without changing old fields.
struct ProgressionProfile: Codable, Hashable {
    var preferredMetric: ProgressionMetric?
    var readinessGate: ProgressionReadinessGate
    var decisionPolicy: ProgressionDecisionPolicy
    var guardrails: ProgressionGuardrails

    init(
        preferredMetric: ProgressionMetric? = nil,
        readinessGate: ProgressionReadinessGate = .strengthDefault,
        decisionPolicy: ProgressionDecisionPolicy = .strengthDefault,
        guardrails: ProgressionGuardrails = .strengthDefault
    ) {
        self.preferredMetric = preferredMetric
        self.readinessGate = readinessGate
        self.decisionPolicy = decisionPolicy
        self.guardrails = guardrails
    }

    static let strengthDefault = ProgressionProfile(
        preferredMetric: nil,
        readinessGate: .strengthDefault,
        decisionPolicy: .strengthDefault,
        guardrails: .strengthDefault
    )

    static let cardioDefault = ProgressionProfile(
        preferredMetric: nil,
        readinessGate: .cardioDefault,
        decisionPolicy: .cardioDefault,
        guardrails: .cardioDefault
    )
}

// MARK: - Exercise Progression State

/// Stores per-exercise progression context so decisions can be stateful over time.
struct ExerciseProgressionState: Codable, Hashable {
    /// Last prescribed working weight for the exercise, if applicable.
    var lastPrescribedWeight: Double?
    /// Last prescribed rep target for the exercise, if applicable.
    var lastPrescribedReps: Int?
    /// Last prescribed duration target (seconds), if applicable.
    var lastPrescribedDuration: Int?
    /// Last prescribed distance target, if applicable.
    var lastPrescribedDistance: Double?
    /// Consecutive successful sessions.
    var successStreak: Int
    /// Consecutive under-target sessions.
    var failStreak: Int
    /// Most recent outcomes, newest first (max 3 entries).
    var recentOutcomes: [ProgressionRecommendation]
    /// Decision confidence from 0.0 to 1.0.
    var confidence: Double
    /// Last time this state was updated.
    var lastUpdatedAt: Date?
    /// Number of times an engine suggestion was shown.
    var suggestionsPresented: Int
    /// Number of times the user/session aligned with the engine suggestion.
    var suggestionsAccepted: Int
    /// Number of times the user/session diverged from the engine suggestion.
    var suggestionsDismissed: Int

    init(
        lastPrescribedWeight: Double? = nil,
        lastPrescribedReps: Int? = nil,
        lastPrescribedDuration: Int? = nil,
        lastPrescribedDistance: Double? = nil,
        successStreak: Int = 0,
        failStreak: Int = 0,
        recentOutcomes: [ProgressionRecommendation] = [],
        confidence: Double = 0.5,
        lastUpdatedAt: Date? = nil,
        suggestionsPresented: Int = 0,
        suggestionsAccepted: Int = 0,
        suggestionsDismissed: Int = 0
    ) {
        self.lastPrescribedWeight = lastPrescribedWeight
        self.lastPrescribedReps = lastPrescribedReps
        self.lastPrescribedDuration = lastPrescribedDuration
        self.lastPrescribedDistance = lastPrescribedDistance
        self.successStreak = successStreak
        self.failStreak = failStreak
        self.recentOutcomes = Array(recentOutcomes.prefix(3))
        self.confidence = min(max(confidence, 0), 1)
        self.lastUpdatedAt = lastUpdatedAt
        self.suggestionsPresented = max(0, suggestionsPresented)
        self.suggestionsAccepted = max(0, suggestionsAccepted)
        self.suggestionsDismissed = max(0, suggestionsDismissed)
    }

    var acceptanceRate: Double? {
        guard suggestionsPresented > 0 else { return nil }
        return Double(suggestionsAccepted) / Double(suggestionsPresented)
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
    let rationale: String?
    let confidence: Double?
    let decisionCode: String?
    let decisionFactors: [String]?

    init(
        baseValue: Double,
        suggestedValue: Double,
        metric: ProgressionMetric,
        percentageApplied: Double,
        appliedOutcome: ProgressionRecommendation? = nil,
        isOutcomeAdjusted: Bool = false,
        rationale: String? = nil,
        confidence: Double? = nil,
        decisionCode: String? = nil,
        decisionFactors: [String]? = nil
    ) {
        self.baseValue = baseValue
        self.suggestedValue = suggestedValue
        self.metric = metric
        self.percentageApplied = percentageApplied
        self.appliedOutcome = appliedOutcome
        self.isOutcomeAdjusted = isOutcomeAdjusted
        self.rationale = rationale
        if let confidence {
            self.confidence = min(max(confidence, 0), 1)
        } else {
            self.confidence = nil
        }
        self.decisionCode = decisionCode
        self.decisionFactors = decisionFactors?.isEmpty == true ? nil : decisionFactors
    }

    private enum CodingKeys: String, CodingKey {
        case baseValue, suggestedValue, metric, percentageApplied, appliedOutcome, isOutcomeAdjusted, rationale, confidence
        case decisionCode, decisionFactors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseValue = try container.decode(Double.self, forKey: .baseValue)
        suggestedValue = try container.decode(Double.self, forKey: .suggestedValue)
        metric = try container.decode(ProgressionMetric.self, forKey: .metric)
        percentageApplied = try container.decode(Double.self, forKey: .percentageApplied)
        appliedOutcome = try container.decodeIfPresent(ProgressionRecommendation.self, forKey: .appliedOutcome)
        isOutcomeAdjusted = try container.decodeIfPresent(Bool.self, forKey: .isOutcomeAdjusted) ?? false
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
        if let decodedConfidence = try container.decodeIfPresent(Double.self, forKey: .confidence) {
            confidence = min(max(decodedConfidence, 0), 1)
        } else {
            confidence = nil
        }
        decisionCode = try container.decodeIfPresent(String.self, forKey: .decisionCode)
        decisionFactors = try container.decodeIfPresent([String].self, forKey: .decisionFactors)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseValue, forKey: .baseValue)
        try container.encode(suggestedValue, forKey: .suggestedValue)
        try container.encode(metric, forKey: .metric)
        try container.encode(percentageApplied, forKey: .percentageApplied)
        try container.encodeIfPresent(appliedOutcome, forKey: .appliedOutcome)
        try container.encode(isOutcomeAdjusted, forKey: .isOutcomeAdjusted)
        try container.encodeIfPresent(rationale, forKey: .rationale)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(decisionCode, forKey: .decisionCode)
        try container.encodeIfPresent(decisionFactors, forKey: .decisionFactors)
    }

    /// Formatted string for display (e.g., "135 lbs (+3.8%)")
    var formattedSuggestion: String {
        let percentFormatted = String(format: "%.1f", percentageApplied)

        switch metric {
        case .weight:
            return "\(formatWeight(suggestedValue)) (+\(percentFormatted)%)"
        case .reps:
            return "\(Int(suggestedValue)) reps (+\(percentFormatted)%)"
        case .duration:
            return "\(formatDuration(Int(suggestedValue.rounded()))) (+\(percentFormatted)%)"
        case .distance:
            return "\(String(format: "%.2f", suggestedValue)) mi (+\(percentFormatted)%)"
        }
    }

    /// Just the value without percentage
    var formattedValue: String {
        switch metric {
        case .weight:
            return formatWeight(suggestedValue)
        case .reps:
            return "\(Int(suggestedValue))"
        case .duration:
            return formatDuration(Int(suggestedValue.rounded()))
        case .distance:
            return String(format: "%.2f", suggestedValue)
        }
    }

    var confidenceText: String? {
        guard let confidence else { return nil }
        return "\(Int((confidence * 100).rounded()))% confidence"
    }

    var confidenceLabel: String? {
        guard let confidence else { return nil }
        switch confidence {
        case 0.75...:
            return "High"
        case 0.45...:
            return "Medium"
        default:
            return "Low"
        }
    }
}
