//
//  AnalyticsConfig.swift
//  gym app
//
//  Tunable configuration for analytics computations and thresholds.
//

import Foundation

struct DryRunProfileConfig: Hashable {
    let name: String
    let confidenceThreshold: Double
}

enum AnalyticsConfig {
    static let defaultWeeklyVolumeWeeks = 10
    static let defaultBreakdownWindowDays = 28
    static let defaultEngineHealthWindowDays = 28
    static let defaultDecisionProfileWindowDays = 28
    static let defaultAlertWindowDays = 28
    static let defaultRecentSessionLimit = 12
    static let defaultRecentPRLimit = 5

    static let e1RMRepRange = 1...12
    static let oneRepMaxPRTolerance = 0.1

    static let minDecisionsForAlerts = 4
    static let lowAcceptanceThreshold = 0.45
    static let highRegressThreshold = 0.40
    static let highOverrideThreshold = 0.60

    static let dryRunProfiles: [DryRunProfileConfig] = [
        DryRunProfileConfig(name: "Conservative", confidenceThreshold: 0.78),
        DryRunProfileConfig(name: "Balanced", confidenceThreshold: 0.58),
        DryRunProfileConfig(name: "Aggressive", confidenceThreshold: 0.42)
    ]
}
