//
//  AnalyticsModels.swift
//  gym app
//
//  Shared analytics model types.
//

import SwiftUI

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case month = "28d"
    case quarter = "90d"
    case allTime = "All"

    var id: String { rawValue }

    var decisionWindowDays: Int {
        switch self {
        case .month: return 28
        case .quarter: return 90
        case .allTime: return 0
        }
    }

    var weeklyVolumeWeeks: Int {
        switch self {
        case .month: return 5
        case .quarter: return 13
        case .allTime: return 26
        }
    }
}

struct WeeklyVolumePoint: Identifiable, Hashable {
    let weekStart: Date
    let totalVolume: Double
    let sessionCount: Int

    var id: Date { weekStart }
}

private func brzyckiEstimatedOneRepMax(weight: Double, reps: Int) -> Double? {
    guard weight > 0, AnalyticsConfig.e1RMRepRange.contains(reps) else { return nil }
    let denominator = 37.0 - Double(reps)
    guard denominator > 0 else { return nil }
    return weight * 36.0 / denominator
}

struct StrengthTopSet: Hashable {
    let weight: Double
    let reps: Int

    var estimatedOneRepMax: Double {
        brzyckiEstimatedOneRepMax(weight: weight, reps: reps) ?? weight
    }

    var formatted: String {
        "\(formatWeight(weight))x\(reps)"
    }
}

struct E1RMProgressPoint: Identifiable, Hashable {
    let date: Date
    let estimatedOneRepMax: Double
    let topSet: StrengthTopSet

    var id: Date { date }
}

struct E1RMExerciseProgress: Hashable {
    let exerciseName: String
    let points: [E1RMProgressPoint]

    var latestDate: Date {
        points.last?.date ?? .distantPast
    }
}

enum TrendDirection {
    case up
    case down
    case flat
}

struct LiftTrend: Identifiable, Hashable {
    let id = UUID()
    let exerciseName: String
    let latestDate: Date
    let latestTopSet: StrengthTopSet
    let previousTopSet: StrengthTopSet?
    let sessionCount: Int

    var direction: TrendDirection {
        guard let previousTopSet else { return .flat }

        if latestTopSet.weight > previousTopSet.weight + 0.001 { return .up }
        if latestTopSet.weight < previousTopSet.weight - 0.001 { return .down }
        if latestTopSet.estimatedOneRepMax > previousTopSet.estimatedOneRepMax + 0.001 { return .up }
        if latestTopSet.estimatedOneRepMax < previousTopSet.estimatedOneRepMax - 0.001 { return .down }
        return .flat
    }

    var deltaWeight: Double? {
        guard let previousTopSet else { return nil }
        return latestTopSet.weight - previousTopSet.weight
    }
}

struct ProgressionBreakdown: Hashable {
    let progressCount: Int
    let stayCount: Int
    let regressCount: Int

    static let empty = ProgressionBreakdown(progressCount: 0, stayCount: 0, regressCount: 0)

    var total: Int {
        progressCount + stayCount + regressCount
    }

    func percentage(for recommendation: ProgressionRecommendation) -> Int {
        guard total > 0 else { return 0 }
        let count: Int
        switch recommendation {
        case .progress: count = progressCount
        case .stay: count = stayCount
        case .regress: count = regressCount
        }
        return Int(round((Double(count) / Double(total)) * 100))
    }
}

struct ProgressionEngineHealth: Hashable {
    let totalDecisions: Int
    let acceptedCount: Int
    let overriddenCount: Int
    let regressCount: Int

    static let empty = ProgressionEngineHealth(
        totalDecisions: 0,
        acceptedCount: 0,
        overriddenCount: 0,
        regressCount: 0
    )

    var acceptanceRate: Int {
        guard totalDecisions > 0 else { return 0 }
        return Int(round((Double(acceptedCount) / Double(totalDecisions)) * 100))
    }

    var overrideRate: Int {
        guard totalDecisions > 0 else { return 0 }
        return Int(round((Double(overriddenCount) / Double(totalDecisions)) * 100))
    }

    var regressRate: Int {
        guard totalDecisions > 0 else { return 0 }
        return Int(round((Double(regressCount) / Double(totalDecisions)) * 100))
    }
}

struct DecisionProfileHealth: Identifiable, Hashable {
    let name: String
    let totalDecisions: Int
    let acceptedCount: Int
    let regressCount: Int

    var id: String { name }

    var acceptanceRate: Int {
        guard totalDecisions > 0 else { return 0 }
        return Int(round((Double(acceptedCount) / Double(totalDecisions)) * 100))
    }

    var regressRate: Int {
        guard totalDecisions > 0 else { return 0 }
        return Int(round((Double(regressCount) / Double(totalDecisions)) * 100))
    }
}

enum ProgressionAlertType {
    case lowAcceptance
    case highRegress
    case highOverride
}

struct ProgressionAlert: Identifiable, Hashable {
    let title: String
    let message: String
    let type: ProgressionAlertType

    var id: String { "\(type)-\(title)" }

    var icon: String {
        switch type {
        case .lowAcceptance: return "exclamationmark.triangle.fill"
        case .highRegress: return "arrow.down.circle.fill"
        case .highOverride: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch type {
        case .lowAcceptance: return AppColors.warning
        case .highRegress: return AppColors.warning
        case .highOverride: return AppColors.dominant
        }
    }
}

struct DryRunProfileResult: Identifiable, Hashable {
    let name: String
    let progressCount: Int
    let stayCount: Int
    let regressCount: Int
    let agreementCount: Int
    let comparableCount: Int

    var id: String { name }

    var agreementRate: Int {
        guard comparableCount > 0 else { return 0 }
        return Int(round((Double(agreementCount) / Double(comparableCount)) * 100))
    }
}

enum PersonalRecordType {
    case estimatedOneRepMax
}

struct PersonalRecordEvent: Identifiable, Hashable {
    let id = UUID()
    let exerciseName: String
    let date: Date
    let type: PersonalRecordType
    let previousBest: Double
    let newBest: Double
    let topSet: StrengthTopSet

    var improvement: Double {
        newBest - previousBest
    }

    var summary: String {
        "\(topSet.formatted) \(exerciseName) PR"
    }
}

struct MuscleGroupVolume: Identifiable, Hashable {
    let muscleGroup: String
    let totalVolume: Double
    let sessionCount: Int
    let percentageOfTotal: Double
    var id: String { muscleGroup }
}

struct CardioSummary: Hashable {
    let totalDuration: Int
    let totalDistance: Double?
    let sessionCount: Int
    let avgDurationPerSession: Int

    static let empty = CardioSummary(totalDuration: 0, totalDistance: nil, sessionCount: 0, avgDurationPerSession: 0)
}

struct WeeklyCardioPoint: Identifiable, Hashable {
    let weekStart: Date
    let totalDuration: Int
    var id: Date { weekStart }
}

struct AnalyticsDashboardData {
    let analyzedSessionCount: Int
    let currentStreak: Int
    let workoutsThisWeek: Int
    let weeklyVolumeTrend: [WeeklyVolumePoint]
    let liftTrends: [LiftTrend]
    let exerciseProgress: [E1RMExerciseProgress]
    let progressionBreakdown: ProgressionBreakdown
    let engineHealth: ProgressionEngineHealth
    let decisionProfileHealth: [DecisionProfileHealth]
    let progressionAlerts: [ProgressionAlert]
    let dryRunProfiles: [DryRunProfileResult]
    let dryRunInputCount: Int
    let recentPRs: [PersonalRecordEvent]
    let muscleGroupVolume: [MuscleGroupVolume]
    let cardioSummary: CardioSummary
    let weeklyCardioTrend: [WeeklyCardioPoint]
}
