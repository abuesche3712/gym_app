//
//  SetData.swift
//  gym app
//
//  Individual set data logged during a workout session
//

import Foundation

struct SetData: Identifiable, Codable, Hashable {
    var id: UUID
    var setNumber: Int

    // Strength metrics
    var weight: Double?
    var reps: Int?
    var rpe: Int?
    var completed: Bool
    var bandColor: String? // For band exercises (e.g., "Red", "Blue")

    // Cardio metrics
    var duration: Int? // seconds
    var distance: Double?
    var pace: Double? // seconds per unit
    var avgHeartRate: Int?

    // Isometric metrics
    var holdTime: Int? // seconds
    var intensity: Int? // 1-10

    // Explosive metrics
    var height: Double?
    var quality: Int? // 1-5

    // Recovery metrics
    var temperature: Int? // °F for sauna/cold plunge

    // Rest tracking
    var restAfter: Int? // seconds, actual rest taken

    // Unilateral tracking
    var side: Side? // nil = bilateral, .left/.right = unilateral

    // Multi-measurable values (e.g., {"Height": 24.0, "Incline": 5.0})
    var implementMeasurableValues: [String: MeasurableValue]

    // Sharing context (denormalized for standalone sharing - "I hit 225x5 on Bench!")
    var sessionId: UUID?
    var exerciseId: UUID?
    var exerciseName: String?
    var workoutName: String?
    var date: Date?

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        rpe: Int? = nil,
        completed: Bool = true,
        bandColor: String? = nil,
        duration: Int? = nil,
        distance: Double? = nil,
        pace: Double? = nil,
        avgHeartRate: Int? = nil,
        holdTime: Int? = nil,
        intensity: Int? = nil,
        height: Double? = nil,
        quality: Int? = nil,
        temperature: Int? = nil,
        restAfter: Int? = nil,
        side: Side? = nil,
        implementMeasurableValues: [String: MeasurableValue] = [:],
        sessionId: UUID? = nil,
        exerciseId: UUID? = nil,
        exerciseName: String? = nil,
        workoutName: String? = nil,
        date: Date? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.completed = completed
        self.bandColor = bandColor
        self.duration = duration
        self.distance = distance
        self.pace = pace
        self.avgHeartRate = avgHeartRate
        self.holdTime = holdTime
        self.intensity = intensity
        self.height = height
        self.quality = quality
        self.temperature = temperature
        self.restAfter = restAfter
        self.side = side
        self.implementMeasurableValues = implementMeasurableValues
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.workoutName = workoutName
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        setNumber = try container.decode(Int.self, forKey: .setNumber)

        // Optional with defaults
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true

        // Truly optional (metric data)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
        bandColor = try container.decodeIfPresent(String.self, forKey: .bandColor)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        pace = try container.decodeIfPresent(Double.self, forKey: .pace)
        avgHeartRate = try container.decodeIfPresent(Int.self, forKey: .avgHeartRate)
        holdTime = try container.decodeIfPresent(Int.self, forKey: .holdTime)
        intensity = try container.decodeIfPresent(Int.self, forKey: .intensity)
        height = try container.decodeIfPresent(Double.self, forKey: .height)
        quality = try container.decodeIfPresent(Int.self, forKey: .quality)
        temperature = try container.decodeIfPresent(Int.self, forKey: .temperature)
        restAfter = try container.decodeIfPresent(Int.self, forKey: .restAfter)
        side = try container.decodeIfPresent(Side.self, forKey: .side)

        // Multi-measurable values with backward compatibility migration
        if let values = try container.decodeIfPresent([String: MeasurableValue].self, forKey: .implementMeasurableValues) {
            implementMeasurableValues = values
        } else {
            // Migrate legacy fields to new dictionary format
            implementMeasurableValues = [:]

            // Migrate height (from box jumps)
            if let legacyHeight = try container.decodeIfPresent(Double.self, forKey: .height) {
                implementMeasurableValues["Height"] = MeasurableValue(numericValue: legacyHeight)
            }

            // Migrate bandColor (from resistance bands)
            if let legacyBandColor = try container.decodeIfPresent(String.self, forKey: .bandColor),
               !legacyBandColor.isEmpty {
                implementMeasurableValues["Color"] = MeasurableValue(stringValue: legacyBandColor)
            }
        }

        // Sharing context (optional - populated when needed for sharing)
        sessionId = try container.decodeIfPresent(UUID.self, forKey: .sessionId)
        exerciseId = try container.decodeIfPresent(UUID.self, forKey: .exerciseId)
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName)
        workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
    }

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, weight, reps, rpe, completed, bandColor, duration, distance, pace, avgHeartRate
        case holdTime, intensity, height, quality, temperature, restAfter, side, implementMeasurableValues
        case sessionId, exerciseId, exerciseName, workoutName, date
    }

    var formattedStrength: String? {
        guard let reps = reps else { return nil }
        var result: String
        if let band = bandColor, !band.isEmpty {
            result = "\(band) x \(reps)"
        } else if let weight = weight {
            result = "\(formatWeight(weight)) x \(reps)"
        } else {
            result = "\(reps) reps"
        }
        if let rpe = rpe {
            result += " @ RPE \(rpe)"
        }
        return result
    }

    var formattedBand: String? {
        guard let band = bandColor, !band.isEmpty, let reps = reps else { return nil }
        var result = "\(band) band x \(reps)"
        if let rpe = rpe {
            result += " @ RPE \(rpe)"
        }
        return result
    }

    var formattedCardio: String? {
        var parts: [String] = []
        if let duration = duration {
            parts.append(formatDuration(duration))
        }
        if let distance = distance {
            parts.append(String(format: "%.2f mi", distance))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    var formattedIsometric: String? {
        guard let holdTime = holdTime else { return nil }
        var result = formatDuration(holdTime) + " hold"
        if let intensity = intensity {
            result += " @ \(intensity)/10"
        }
        return result
    }

    var formattedRecovery: String? {
        guard let duration = duration else { return nil }
        var result = formatDuration(duration)
        if let temp = temperature {
            result += " @ \(temp)°F"
        }
        return result
    }
}
