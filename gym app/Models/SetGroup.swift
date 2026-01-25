//
//  SetGroup.swift
//  gym app
//
//  A group of sets with the same prescription
//

import Foundation

struct SetGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var sets: Int  // Also used as "rounds" for interval mode
    var targetReps: Int?
    var targetWeight: Double?
    var targetRPE: Int?
    var targetDuration: Int? // seconds
    var targetDistance: Double?
    var targetDistanceUnit: DistanceUnit? // unit for distance-based cardio
    var targetHoldTime: Int? // seconds
    var restPeriod: Int? // seconds between sets
    var notes: String?

    // Interval mode fields
    var isInterval: Bool
    var workDuration: Int?  // seconds of work per round
    var intervalRestDuration: Int?  // seconds of rest between rounds

    // AMRAP mode fields
    var isAMRAP: Bool
    var amrapTimeLimit: Int?  // optional time limit in seconds (e.g., 60s AMRAP)

    // Unilateral mode (single-leg/arm exercises)
    var isUnilateral: Bool  // If true, each set is done left then right

    // RPE tracking
    var trackRPE: Bool  // Whether to track RPE for this set group

    // Multi-measurable system for tracking multiple implement attributes
    var implementMeasurables: [ImplementMeasurableTarget]

    // Legacy fields (deprecated, kept for backward compatibility)
    var implementMeasurableLabel: String?
    var implementMeasurableUnit: String?
    var implementMeasurableValue: Double?
    var implementMeasurableStringValue: String?

    init(
        id: UUID = UUID(),
        sets: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetRPE: Int? = nil,
        targetDuration: Int? = nil,
        targetDistance: Double? = nil,
        targetDistanceUnit: DistanceUnit? = nil,
        targetHoldTime: Int? = nil,
        restPeriod: Int? = nil,
        notes: String? = nil,
        isInterval: Bool = false,
        workDuration: Int? = nil,
        intervalRestDuration: Int? = nil,
        isAMRAP: Bool = false,
        amrapTimeLimit: Int? = nil,
        isUnilateral: Bool = false,
        trackRPE: Bool = true,
        implementMeasurables: [ImplementMeasurableTarget] = [],
        implementMeasurableLabel: String? = nil,
        implementMeasurableUnit: String? = nil,
        implementMeasurableValue: Double? = nil,
        implementMeasurableStringValue: String? = nil
    ) {
        self.id = id
        self.sets = sets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetRPE = targetRPE
        self.targetDuration = targetDuration
        self.targetDistance = targetDistance
        self.targetDistanceUnit = targetDistanceUnit
        self.targetHoldTime = targetHoldTime
        self.restPeriod = restPeriod
        self.notes = notes
        self.isInterval = isInterval
        self.workDuration = workDuration
        self.intervalRestDuration = intervalRestDuration
        self.isAMRAP = isAMRAP
        self.amrapTimeLimit = amrapTimeLimit
        self.isUnilateral = isUnilateral
        self.trackRPE = trackRPE
        self.implementMeasurables = implementMeasurables
        self.implementMeasurableLabel = implementMeasurableLabel
        self.implementMeasurableUnit = implementMeasurableUnit
        self.implementMeasurableValue = implementMeasurableValue
        self.implementMeasurableStringValue = implementMeasurableStringValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        sets = try container.decode(Int.self, forKey: .sets)

        // Optional with defaults
        isInterval = try container.decodeIfPresent(Bool.self, forKey: .isInterval) ?? false
        isAMRAP = try container.decodeIfPresent(Bool.self, forKey: .isAMRAP) ?? false
        isUnilateral = try container.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        trackRPE = try container.decodeIfPresent(Bool.self, forKey: .trackRPE) ?? true

        // Multi-measurable system with backward compatibility migration
        if let measurables = try container.decodeIfPresent([ImplementMeasurableTarget].self, forKey: .implementMeasurables) {
            implementMeasurables = measurables
        } else {
            // Migrate legacy single measurable to new array format
            implementMeasurables = []
            if let legacyLabel = try container.decodeIfPresent(String.self, forKey: .implementMeasurableLabel),
               let legacyUnit = try container.decodeIfPresent(String.self, forKey: .implementMeasurableUnit) {
                let isStringBased = (try? container.decodeIfPresent(String.self, forKey: .implementMeasurableStringValue)) != nil
                let targetValue = try container.decodeIfPresent(Double.self, forKey: .implementMeasurableValue)
                let targetStringValue = try container.decodeIfPresent(String.self, forKey: .implementMeasurableStringValue)

                // Create a migrated measurable (use a placeholder UUID for implementId since we don't have it)
                implementMeasurables.append(ImplementMeasurableTarget(
                    implementId: UUID(), // Will be re-resolved when needed
                    measurableName: legacyLabel,
                    unit: legacyUnit,
                    isStringBased: isStringBased,
                    targetValue: targetValue,
                    targetStringValue: targetStringValue
                ))
            }
        }

        // Truly optional (target values)
        targetReps = try container.decodeIfPresent(Int.self, forKey: .targetReps)
        targetWeight = try container.decodeIfPresent(Double.self, forKey: .targetWeight)
        targetRPE = try container.decodeIfPresent(Int.self, forKey: .targetRPE)
        targetDuration = try container.decodeIfPresent(Int.self, forKey: .targetDuration)
        targetDistance = try container.decodeIfPresent(Double.self, forKey: .targetDistance)
        targetDistanceUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .targetDistanceUnit)
        targetHoldTime = try container.decodeIfPresent(Int.self, forKey: .targetHoldTime)
        restPeriod = try container.decodeIfPresent(Int.self, forKey: .restPeriod)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        workDuration = try container.decodeIfPresent(Int.self, forKey: .workDuration)
        intervalRestDuration = try container.decodeIfPresent(Int.self, forKey: .intervalRestDuration)
        amrapTimeLimit = try container.decodeIfPresent(Int.self, forKey: .amrapTimeLimit)
        implementMeasurableLabel = try container.decodeIfPresent(String.self, forKey: .implementMeasurableLabel)
        implementMeasurableUnit = try container.decodeIfPresent(String.self, forKey: .implementMeasurableUnit)
        implementMeasurableValue = try container.decodeIfPresent(Double.self, forKey: .implementMeasurableValue)
        implementMeasurableStringValue = try container.decodeIfPresent(String.self, forKey: .implementMeasurableStringValue)
    }

    private enum CodingKeys: String, CodingKey {
        case id, sets, targetReps, targetWeight, targetRPE, targetDuration, targetDistance, targetDistanceUnit
        case targetHoldTime, restPeriod, notes, isInterval, workDuration, intervalRestDuration
        case isAMRAP, amrapTimeLimit, isUnilateral, trackRPE
        case implementMeasurables
        case implementMeasurableLabel, implementMeasurableUnit, implementMeasurableValue, implementMeasurableStringValue
    }

    /// Total duration of the interval workout (all rounds)
    var totalIntervalDuration: Int? {
        guard isInterval, let work = workDuration, let rest = intervalRestDuration else { return nil }
        // Work for all rounds + rest between rounds (no rest after last round)
        return (work * sets) + (rest * max(0, sets - 1))
    }

    var formattedTarget: String {
        // Interval mode has special formatting
        if isInterval, let work = workDuration, let rest = intervalRestDuration {
            return "\(sets) rounds: \(formatDurationVerbose(work)) on / \(formatDurationVerbose(rest)) off"
        }

        var parts: [String] = []

        // AMRAP mode has special formatting
        if isAMRAP {
            if let timeLimit = amrapTimeLimit {
                parts.append("\(sets)x AMRAP (\(formatDurationVerbose(timeLimit)))")
            } else {
                parts.append("\(sets)x AMRAP")
            }
        } else if let reps = targetReps {
            parts.append("\(sets)x\(reps)")
        } else if let distance = targetDistance {
            let unit = targetDistanceUnit ?? .meters
            parts.append("\(sets)x\(formatDistance(distance, unit: unit))")
        } else if let duration = targetDuration {
            parts.append("\(sets)x\(formatDurationVerbose(duration))")
        } else if let holdTime = targetHoldTime {
            parts.append("\(sets)x\(formatDurationVerbose(holdTime)) hold")
        } else {
            parts.append("\(sets) sets")
        }

        // Show implement-specific measurable OR weight
        if let label = implementMeasurableLabel {
            if let stringVal = implementMeasurableStringValue, !stringVal.isEmpty {
                parts.append("@ \(stringVal) \(label)")
            } else if let numVal = implementMeasurableValue {
                let unit = implementMeasurableUnit ?? ""
                parts.append("@ \(formatWeight(numVal))\(unit)")
            }
        } else if let weight = targetWeight {
            parts.append("@ \(formatWeight(weight)) lbs")
        }

        if let rpe = targetRPE {
            parts.append("RPE \(rpe)")
        }

        return parts.joined(separator: " ")
    }

    var formattedRest: String? {
        guard let rest = restPeriod else { return nil }
        return formatDurationVerbose(rest) + " rest"
    }
}

// MARK: - Implement Measurable Target

/// Represents a target value for an implement measurable in a workout template
/// Supports both numeric (weight, height, incline) and string-based (band color) measurables
struct ImplementMeasurableTarget: Identifiable, Codable, Hashable {
    var id: UUID
    var implementId: UUID        // Which implement this measurable belongs to
    var measurableName: String   // e.g., "Height", "Weight", "Incline", "Color"
    var unit: String             // e.g., "in", "lbs", "°", "" (for string-based)
    var isStringBased: Bool      // true for text inputs (band color), false for numeric
    var targetValue: Double?     // numeric target (height: 24, incline: 5)
    var targetStringValue: String?  // string target (band color: "Red")

    init(
        id: UUID = UUID(),
        implementId: UUID,
        measurableName: String,
        unit: String,
        isStringBased: Bool,
        targetValue: Double? = nil,
        targetStringValue: String? = nil
    ) {
        self.id = id
        self.implementId = implementId
        self.measurableName = measurableName
        self.unit = unit
        self.isStringBased = isStringBased
        self.targetValue = targetValue
        self.targetStringValue = targetStringValue
    }
}
