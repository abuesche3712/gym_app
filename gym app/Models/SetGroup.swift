//
//  SetGroup.swift
//  gym app
//
//  A group of sets with the same prescription
//

import Foundation

struct SetGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var sets: Int
    var targetReps: Int?
    var targetWeight: Double?
    var targetRPE: Int?
    var targetDuration: Int? // seconds
    var targetDistance: Double?
    var targetDistanceUnit: DistanceUnit? // unit for distance-based cardio
    var targetHoldTime: Int? // seconds
    var restPeriod: Int? // seconds between sets
    var notes: String?

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
        notes: String? = nil
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
    }

    var formattedTarget: String {
        var parts: [String] = []

        if let reps = targetReps {
            parts.append("\(sets)x\(reps)")
        } else if let distance = targetDistance {
            parts.append("\(sets)x\(formatDistance(distance))")
        } else if let duration = targetDuration {
            parts.append("\(sets)x\(formatDuration(duration))")
        } else if let holdTime = targetHoldTime {
            parts.append("\(sets)x\(holdTime)s hold")
        } else {
            parts.append("\(sets) sets")
        }

        if let weight = targetWeight {
            parts.append("@ \(formatWeight(weight)) lbs")
        }

        if let rpe = targetRPE {
            parts.append("RPE \(rpe)")
        }

        return parts.joined(separator: " ")
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private func formatDistance(_ distance: Double) -> String {
        let unit = targetDistanceUnit ?? .meters
        if distance == floor(distance) {
            return "\(Int(distance))\(unit.abbreviation)"
        }
        return String(format: "%.1f%@", distance, unit.abbreviation)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(mins)m \(secs)s"
            }
            return "\(mins) min"
        }
        return "\(seconds)s"
    }

    var formattedRest: String? {
        guard let rest = restPeriod else { return nil }
        return formatDuration(rest) + " rest"
    }
}
