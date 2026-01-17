//
//  UserProfile.swift
//  gym app
//
//  User preferences and settings that sync to cloud
//

import Foundation

struct UserProfile: Codable {
    var weightUnit: WeightUnit
    var distanceUnit: DistanceUnit
    var defaultRestTime: Int

    init(
        weightUnit: WeightUnit = .lbs,
        distanceUnit: DistanceUnit = .miles,
        defaultRestTime: Int = 90
    ) {
        self.weightUnit = weightUnit
        self.distanceUnit = distanceUnit
        self.defaultRestTime = defaultRestTime
    }
}
