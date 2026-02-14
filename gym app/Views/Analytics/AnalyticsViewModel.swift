//
//  AnalyticsViewModel.swift
//  gym app
//
//  View-model orchestration for analytics dashboards.
//

import Foundation

struct AnalyticsComputationSnapshot {
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

protocol AnalyticsComputationPerforming {
    func compute(from sessions: [Session], weeklyVolumeWeeks: Int, decisionWindowDays: Int) async -> AnalyticsComputationSnapshot
}

actor AnalyticsComputationActor: AnalyticsComputationPerforming {
    private let analyticsService = AnalyticsService()

    func compute(from sessions: [Session], weeklyVolumeWeeks: Int, decisionWindowDays: Int) async -> AnalyticsComputationSnapshot {
        let data = analyticsService.dashboardData(from: sessions, weeklyVolumeWeeks: weeklyVolumeWeeks, decisionWindowDays: decisionWindowDays)

        return AnalyticsComputationSnapshot(
            analyzedSessionCount: data.analyzedSessionCount,
            currentStreak: data.currentStreak,
            workoutsThisWeek: data.workoutsThisWeek,
            weeklyVolumeTrend: data.weeklyVolumeTrend,
            liftTrends: data.liftTrends,
            exerciseProgress: data.exerciseProgress,
            progressionBreakdown: data.progressionBreakdown,
            engineHealth: data.engineHealth,
            decisionProfileHealth: data.decisionProfileHealth,
            progressionAlerts: data.progressionAlerts,
            dryRunProfiles: data.dryRunProfiles,
            dryRunInputCount: data.dryRunInputCount,
            recentPRs: data.recentPRs,
            muscleGroupVolume: data.muscleGroupVolume,
            cardioSummary: data.cardioSummary,
            weeklyCardioTrend: data.weeklyCardioTrend
        )
    }
}

private enum AnalyticsSessionFingerprint {
    static func make(from sessions: [Session]) -> Int {
        var hasher = Hasher()
        hasher.combine(sessions.count)

        for session in sessions {
            hasher.combine(session.id)
            hasher.combine(session.date)

            for module in session.completedModules where !module.skipped {
                hasher.combine(module.id)

                for exercise in module.completedExercises where exercise.exerciseType == .strength {
                    hasher.combine(exercise.id)
                    hasher.combine(exercise.exerciseName)
                    hasher.combine(exercise.progressionRecommendation?.rawValue ?? "")

                    if let suggestion = exercise.progressionSuggestion {
                        hasher.combine(quantize(suggestion.baseValue))
                        hasher.combine(quantize(suggestion.suggestedValue))
                        hasher.combine(suggestion.appliedOutcome?.rawValue ?? "")
                        hasher.combine(quantize(suggestion.confidence ?? -1))
                        hasher.combine(suggestion.decisionCode ?? "")
                    } else {
                        hasher.combine("<no_suggestion>")
                    }

                    for setGroup in exercise.completedSetGroups {
                        hasher.combine(setGroup.id)
                        for set in setGroup.sets {
                            hasher.combine(set.id)
                            hasher.combine(set.completed)
                            hasher.combine(quantize(set.weight))
                            hasher.combine(set.reps ?? -1)
                        }
                    }
                }

                for exercise in module.completedExercises where exercise.exerciseType == .cardio {
                    hasher.combine(exercise.id)
                    hasher.combine(exercise.exerciseName)

                    for setGroup in exercise.completedSetGroups {
                        hasher.combine(setGroup.id)
                        for set in setGroup.sets {
                            hasher.combine(set.id)
                            hasher.combine(set.completed)
                            hasher.combine(set.duration ?? -1)
                            hasher.combine(quantize(set.distance))
                        }
                    }
                }
            }
        }

        return hasher.finalize()
    }

    private static func quantize(_ value: Double?) -> Int {
        guard let value else { return Int.min }
        return Int((value * 100).rounded())
    }
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var currentStreak = 0
    @Published private(set) var workoutsThisWeek = 0
    @Published private(set) var weeklyVolumeTrend: [WeeklyVolumePoint] = []
    @Published private(set) var liftTrends: [LiftTrend] = []
    @Published private(set) var strengthExerciseOptions: [String] = []
    @Published private(set) var e1RMProgressByExercise: [String: [E1RMProgressPoint]] = [:]
    @Published var selectedStrengthExercise: String = ""
    @Published private(set) var progressionBreakdown: ProgressionBreakdown = .empty
    @Published private(set) var engineHealth: ProgressionEngineHealth = .empty
    @Published private(set) var decisionProfileHealth: [DecisionProfileHealth] = []
    @Published private(set) var progressionAlerts: [ProgressionAlert] = []
    @Published private(set) var dryRunProfiles: [DryRunProfileResult] = []
    @Published private(set) var dryRunInputCount: Int = 0
    @Published private(set) var recentPRs: [PersonalRecordEvent] = []
    @Published private(set) var analyzedSessionCount = 0
    @Published private(set) var muscleGroupVolume: [MuscleGroupVolume] = []
    @Published private(set) var cardioSummary: CardioSummary = .empty
    @Published private(set) var weeklyCardioTrend: [WeeklyCardioPoint] = []
    @Published var selectedTimeRange: AnalyticsTimeRange = .month

    private var computeTask: Task<Void, Never>?
    private let computationPerformer: any AnalyticsComputationPerforming
    private var lastSessionFingerprint: Int?

    init(computationPerformer: any AnalyticsComputationPerforming = AnalyticsComputationActor()) {
        self.computationPerformer = computationPerformer
    }

    var selectedE1RMPoints: [E1RMProgressPoint] {
        guard !selectedStrengthExercise.isEmpty else { return [] }
        return e1RMProgressByExercise[selectedStrengthExercise] ?? []
    }

    var selectedCurrentE1RM: Double? {
        selectedE1RMPoints.last?.estimatedOneRepMax
    }

    var selectedBestE1RM: Double? {
        selectedE1RMPoints.map(\.estimatedOneRepMax).max()
    }

    var selectedE1RMDelta: Double? {
        guard let first = selectedE1RMPoints.first?.estimatedOneRepMax,
              let last = selectedE1RMPoints.last?.estimatedOneRepMax else {
            return nil
        }
        return last - first
    }

    deinit {
        computeTask?.cancel()
    }

    func load(from sessions: [Session]) {
        let range = selectedTimeRange
        var hasher = Hasher()
        hasher.combine(AnalyticsSessionFingerprint.make(from: sessions))
        hasher.combine(range.rawValue)
        let fingerprint = hasher.finalize()

        if lastSessionFingerprint == fingerprint {
            return
        }

        lastSessionFingerprint = fingerprint
        let preferredExercise = selectedStrengthExercise

        computeTask?.cancel()
        computeTask = Task(priority: .userInitiated) {
            let snapshot = await computationPerformer.compute(
                from: sessions,
                weeklyVolumeWeeks: range.weeklyVolumeWeeks,
                decisionWindowDays: range.decisionWindowDays
            )
            guard !Task.isCancelled else { return }
            apply(snapshot, preferredExercise: preferredExercise)
        }
    }

    private func apply(_ snapshot: AnalyticsComputationSnapshot, preferredExercise: String) {
        analyzedSessionCount = snapshot.analyzedSessionCount
        currentStreak = snapshot.currentStreak
        workoutsThisWeek = snapshot.workoutsThisWeek
        weeklyVolumeTrend = snapshot.weeklyVolumeTrend
        liftTrends = snapshot.liftTrends

        let options = snapshot.exerciseProgress.map(\.exerciseName)
        strengthExerciseOptions = options
        e1RMProgressByExercise = Dictionary(uniqueKeysWithValues: snapshot.exerciseProgress.map { ($0.exerciseName, $0.points) })

        if options.contains(preferredExercise) {
            selectedStrengthExercise = preferredExercise
        } else {
            selectedStrengthExercise = options.first ?? ""
        }

        progressionBreakdown = snapshot.progressionBreakdown
        engineHealth = snapshot.engineHealth
        decisionProfileHealth = snapshot.decisionProfileHealth
        progressionAlerts = snapshot.progressionAlerts
        dryRunProfiles = snapshot.dryRunProfiles
        dryRunInputCount = snapshot.dryRunInputCount
        recentPRs = snapshot.recentPRs
        muscleGroupVolume = snapshot.muscleGroupVolume
        cardioSummary = snapshot.cardioSummary
        weeklyCardioTrend = snapshot.weeklyCardioTrend
    }
}
