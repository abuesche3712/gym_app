//
//  CompletedSetGroup.swift
//  gym app
//
//  A completed set group from a workout session containing actual logged sets
//

import Foundation

struct CompletedSetGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var setGroupId: UUID
    var restPeriod: Int?  // Target rest period from original SetGroup
    var sets: [SetData]

    // Interval mode fields
    var isInterval: Bool
    var workDuration: Int?  // seconds of work per round
    var intervalRestDuration: Int?  // seconds of rest between rounds

    // AMRAP mode fields
    var isAMRAP: Bool
    var amrapTimeLimit: Int?  // optional time limit in seconds

    // Unilateral mode
    var isUnilateral: Bool  // If true, sets have left/right sides

    // RPE tracking
    var trackRPE: Bool  // Whether to track RPE for this set group

    // Multi-measurable targets from the workout template
    var implementMeasurables: [ImplementMeasurableTarget]

    init(
        id: UUID = UUID(),
        setGroupId: UUID,
        restPeriod: Int? = nil,
        sets: [SetData] = [],
        isInterval: Bool = false,
        workDuration: Int? = nil,
        intervalRestDuration: Int? = nil,
        isAMRAP: Bool = false,
        amrapTimeLimit: Int? = nil,
        isUnilateral: Bool = false,
        trackRPE: Bool = true,
        implementMeasurables: [ImplementMeasurableTarget] = []
    ) {
        self.id = id
        self.setGroupId = setGroupId
        self.restPeriod = restPeriod
        self.sets = sets
        self.isInterval = isInterval
        self.workDuration = workDuration
        self.intervalRestDuration = intervalRestDuration
        self.isAMRAP = isAMRAP
        self.amrapTimeLimit = amrapTimeLimit
        self.isUnilateral = isUnilateral
        self.trackRPE = trackRPE
        self.implementMeasurables = implementMeasurables
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        setGroupId = try container.decode(UUID.self, forKey: .setGroupId)

        // Optional with defaults
        sets = try container.decodeIfPresent([SetData].self, forKey: .sets) ?? []
        isInterval = try container.decodeIfPresent(Bool.self, forKey: .isInterval) ?? false
        isAMRAP = try container.decodeIfPresent(Bool.self, forKey: .isAMRAP) ?? false
        isUnilateral = try container.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        trackRPE = try container.decodeIfPresent(Bool.self, forKey: .trackRPE) ?? true
        implementMeasurables = try container.decodeIfPresent([ImplementMeasurableTarget].self, forKey: .implementMeasurables) ?? []

        // Truly optional
        restPeriod = try container.decodeIfPresent(Int.self, forKey: .restPeriod)
        workDuration = try container.decodeIfPresent(Int.self, forKey: .workDuration)
        intervalRestDuration = try container.decodeIfPresent(Int.self, forKey: .intervalRestDuration)
        amrapTimeLimit = try container.decodeIfPresent(Int.self, forKey: .amrapTimeLimit)
    }

    private enum CodingKeys: String, CodingKey {
        case id, setGroupId, restPeriod, sets, isInterval, workDuration, intervalRestDuration
        case isAMRAP, amrapTimeLimit, isUnilateral, trackRPE, implementMeasurables
    }

    /// Total rounds (for interval mode, equals number of sets)
    var rounds: Int {
        sets.count
    }
}
