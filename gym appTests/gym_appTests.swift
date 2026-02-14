//
//  gym_appTests.swift
//  gym appTests
//
//  Analytics unit tests
//

import XCTest
@testable import gym_app

final class gym_appTests: XCTestCase {
    private var service: AnalyticsService!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        service = AnalyticsService()
        calendar = Calendar.current
    }

    func testCurrentStreak_countsConsecutiveDays() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: reference)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: reference)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: reference)!

        let sessions = [
            makeSession(date: reference, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: yesterday, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: twoDaysAgo, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: fourDaysAgo, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)])
        ]

        let streak = service.currentStreak(from: sessions, referenceDate: reference)
        XCTAssertEqual(streak, 3)
    }

    func testWeeklyVolumeTrend_groupsVolumeByWeek() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: reference)!.start
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!

        let currentWeekSessionDate = calendar.date(byAdding: .day, value: 1, to: currentWeekStart)!
        let previousWeekSessionDate = calendar.date(byAdding: .day, value: 2, to: previousWeekStart)!

        let sessions = [
            makeSession(date: currentWeekSessionDate, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]), // 500
            makeSession(date: previousWeekSessionDate, exercises: [makeStrengthExercise(name: "Bench", weight: 90, reps: 5)])   // 450
        ]

        let points = service.weeklyVolumeTrend(from: sessions, weeks: 2, referenceDate: reference)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].totalVolume, 450, accuracy: 0.001)
        XCTAssertEqual(points[1].totalVolume, 500, accuracy: 0.001)
    }

    func testProgressionBreakdown_countsRecommendations() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let recentDate = calendar.date(byAdding: .day, value: -3, to: reference)!

        let exercises = [
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .progress),
            makeStrengthExercise(name: "Squat", weight: 200, reps: 5, recommendation: .stay),
            makeStrengthExercise(name: "Deadlift", weight: 300, reps: 3, recommendation: .regress)
        ]
        let sessions = [makeSession(date: recentDate, exercises: exercises)]

        let breakdown = service.progressionBreakdown(from: sessions, days: 28, referenceDate: reference)
        XCTAssertEqual(breakdown.progressCount, 1)
        XCTAssertEqual(breakdown.stayCount, 1)
        XCTAssertEqual(breakdown.regressCount, 1)
        XCTAssertEqual(breakdown.total, 3)
    }

    func testEngineHealth_calculatesAcceptanceOverrideAndRegressRates() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let recentDate = calendar.date(byAdding: .day, value: -2, to: reference)!

        let progressSuggestion = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.8,
            decisionCode: "WEIGHTED_PROGRESS"
        )
        let regressSuggestion = ProgressionSuggestion(
            baseValue: 200,
            suggestedValue: 190,
            metric: .weight,
            percentageApplied: -5,
            appliedOutcome: .regress,
            confidence: 0.78,
            decisionCode: "WEIGHTED_REGRESS"
        )

        let exercises = [
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .progress, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Squat", weight: 200, reps: 5, recommendation: .stay, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Deadlift", weight: 300, reps: 3, recommendation: .regress, suggestion: regressSuggestion)
        ]
        let sessions = [makeSession(date: recentDate, exercises: exercises)]

        let health = service.engineHealth(from: sessions, days: 28, referenceDate: reference)
        XCTAssertEqual(health.totalDecisions, 3)
        XCTAssertEqual(health.acceptedCount, 2)
        XCTAssertEqual(health.overriddenCount, 1)
        XCTAssertEqual(health.regressCount, 1)
        XCTAssertEqual(health.acceptanceRate, 67)
        XCTAssertEqual(health.overrideRate, 33)
        XCTAssertEqual(health.regressRate, 33)
    }

    func testProgressionAlerts_flagsLowAcceptanceAndHighOverrides() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let recentDate = calendar.date(byAdding: .day, value: -1, to: reference)!
        let progressSuggestion = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.65,
            decisionCode: "WEIGHTED_PROGRESS"
        )

        let benchExercises = [
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .stay, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .stay, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .regress, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .progress, suggestion: progressSuggestion)
        ]
        let sessions = [makeSession(date: recentDate, exercises: benchExercises)]

        let alerts = service.progressionAlerts(from: sessions, days: 28, referenceDate: reference)
        XCTAssertTrue(alerts.contains(where: { $0.title.contains("Low acceptance") }))
        XCTAssertTrue(alerts.contains(where: { $0.title.contains("Frequent overrides") }))
    }

    func testDryRunProfiles_simulatesConservativeToAggressive() {
        let reference = makeDate(year: 2026, month: 2, day: 6)

        let highConfidenceProgress = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.90,
            decisionCode: "WEIGHTED_PROGRESS"
        )
        let mediumConfidenceProgress = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.50,
            decisionCode: "WEIGHTED_PROGRESS"
        )
        let lowConfidenceRegress = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 95,
            metric: .weight,
            percentageApplied: -5,
            appliedOutcome: .regress,
            confidence: 0.30,
            decisionCode: "WEIGHTED_REGRESS"
        )

        let sessions = [
            makeSession(
                date: reference,
                exercises: [makeStrengthExercise(name: "Bench", weight: 105, reps: 5, recommendation: .progress, suggestion: highConfidenceProgress)]
            ),
            makeSession(
                date: calendar.date(byAdding: .day, value: -1, to: reference)!,
                exercises: [makeStrengthExercise(name: "Bench", weight: 102, reps: 5, recommendation: .stay, suggestion: mediumConfidenceProgress)]
            ),
            makeSession(
                date: calendar.date(byAdding: .day, value: -2, to: reference)!,
                exercises: [makeStrengthExercise(name: "Bench", weight: 98, reps: 5, recommendation: .stay, suggestion: lowConfidenceRegress)]
            )
        ]

        let dryRun = service.dryRunProfiles(from: sessions, recentSessionLimit: 12)

        XCTAssertEqual(dryRun.inputCount, 3)
        XCTAssertEqual(dryRun.results.count, 3)

        let conservative = dryRun.results.first { $0.name == "Conservative" }
        let aggressive = dryRun.results.first { $0.name == "Aggressive" }

        XCTAssertEqual(conservative?.progressCount, 1)
        XCTAssertEqual(conservative?.stayCount, 2)
        XCTAssertEqual(aggressive?.progressCount, 2)
        XCTAssertEqual(aggressive?.stayCount, 1)
    }

    func testRecentPRs_detectsEstimatedOneRepMaxUsingBrzycki() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 8)
        let day3 = makeDate(year: 2026, month: 1, day: 15)

        let sessions = [
            makeSession(date: day1, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: day2, exercises: [makeStrengthExercise(name: "Bench", weight: 105, reps: 5)]),
            makeSession(date: day3, exercises: [makeStrengthExercise(name: "Bench", weight: 105, reps: 8)])
        ]

        let prs = service.recentPRs(sessions: sessions, limit: 5)

        XCTAssertEqual(prs.count, 2)
        XCTAssertEqual(prs[0].exerciseName, "Bench")
        XCTAssertEqual(prs[0].date, day3)
        XCTAssertEqual(prs[1].date, day2)

        switch prs[0].type {
        case .estimatedOneRepMax:
            XCTAssertTrue(prs[0].newBest > prs[0].previousBest)
        }

        switch prs[1].type {
        case .estimatedOneRepMax:
            XCTAssertEqual(prs[1].newBest, 118.125, accuracy: 0.001) // 105 * 36 / (37 - 5)
        }
    }

    func testRecentPRs_ignoresSetsAbove12Reps() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 8)

        let sessions = [
            makeSession(date: day1, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 5)]),
            makeSession(date: day2, exercises: [makeStrengthExercise(name: "Bench", weight: 100, reps: 13)])
        ]

        let prs = service.recentPRs(sessions: sessions, limit: 5)
        XCTAssertEqual(prs.count, 0)
    }

    func testE1RMProgress_usesBestQualifyingSetPerDay() {
        let day1Morning = makeDate(year: 2026, month: 1, day: 1)
        let day1Evening = calendar.date(byAdding: .hour, value: 6, to: day1Morning)!
        let day2 = makeDate(year: 2026, month: 1, day: 2)

        let day1Exercise = makeStrengthExercise(
            name: "Deadlift",
            sets: [
                SetData(setNumber: 1, weight: 365, reps: 5, completed: true),  // e1RM 410.6
                SetData(setNumber: 2, weight: 405, reps: 4, completed: true),  // e1RM 437.4 (best)
                SetData(setNumber: 3, weight: 225, reps: 15, completed: true)  // ignored (>12 reps)
            ]
        )
        let day2Exercise = makeStrengthExercise(name: "Deadlift", weight: 425, reps: 4)

        let sessions = [
            makeSession(date: day1Morning, exercises: [day1Exercise]),
            makeSession(date: day1Evening, exercises: [makeStrengthExercise(name: "Deadlift", weight: 385, reps: 4)]),
            makeSession(date: day2, exercises: [day2Exercise])
        ]

        let points = service.e1RMProgress(for: "Deadlift", sessions: sessions)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].topSet.weight, 405, accuracy: 0.001)
        XCTAssertEqual(points[0].topSet.reps, 4)
        XCTAssertEqual(points[1].topSet.weight, 425, accuracy: 0.001)
    }

    func testAnalyticsService_emptySessions_returnsZeroOrEmpty() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let sessions: [Session] = []

        XCTAssertEqual(service.currentStreak(from: sessions, referenceDate: reference), 0)
        XCTAssertEqual(service.workoutsThisWeek(from: sessions, referenceDate: reference), 0)
        XCTAssertEqual(service.weeklyVolumeTrend(from: sessions, weeks: 4, referenceDate: reference).count, 4)
        XCTAssertEqual(service.progressionBreakdown(from: sessions, days: 28, referenceDate: reference), .empty)
        XCTAssertEqual(service.engineHealth(from: sessions, days: 28, referenceDate: reference), .empty)
        XCTAssertTrue(service.decisionProfileHealth(from: sessions, days: 28, referenceDate: reference).isEmpty)
        XCTAssertTrue(service.progressionAlerts(from: sessions, days: 28, referenceDate: reference).isEmpty)

        let dryRun = service.dryRunProfiles(from: sessions, recentSessionLimit: 12)
        XCTAssertEqual(dryRun.inputCount, 0)
        XCTAssertEqual(dryRun.results.count, 3)
        XCTAssertTrue(service.recentPRs(sessions: sessions, limit: 5).isEmpty)
    }

    func testRecentPRs_singleRepSet_countsAsValidEstimatedOneRepMax() {
        let day1 = makeDate(year: 2026, month: 1, day: 1)
        let day2 = makeDate(year: 2026, month: 1, day: 8)

        let sessions = [
            makeSession(date: day1, exercises: [makeStrengthExercise(name: "Bench", weight: 200, reps: 1)]),
            makeSession(date: day2, exercises: [makeStrengthExercise(name: "Bench", weight: 205, reps: 1)])
        ]

        let prs = service.recentPRs(sessions: sessions, limit: 5)
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs[0].exerciseName, "Bench")
        XCTAssertEqual(prs[0].date, day2)
        XCTAssertEqual(prs[0].newBest, 205, accuracy: 0.001)
    }

    func testProgressionAlerts_requiresMinimumDecisionsPerExercise() {
        let reference = makeDate(year: 2026, month: 2, day: 6)
        let recentDate = calendar.date(byAdding: .day, value: -1, to: reference)!
        let progressSuggestion = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.65,
            decisionCode: "WEIGHTED_PROGRESS"
        )

        let benchExercises = [
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .stay, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .stay, suggestion: progressSuggestion),
            makeStrengthExercise(name: "Bench", weight: 100, reps: 5, recommendation: .regress, suggestion: progressSuggestion)
        ]
        let sessions = [makeSession(date: recentDate, exercises: benchExercises)]

        let alerts = service.progressionAlerts(from: sessions, days: 28, referenceDate: reference)
        XCTAssertTrue(alerts.isEmpty)
    }

    func testDashboardData_matchesExistingMetricMethods() {
        let reference = makeDate(year: 2026, month: 2, day: 13)
        let sessions = makeAnalyticsDataset(sessionCount: 80, referenceDate: reference)

        let dashboard = service.dashboardData(from: sessions, referenceDate: reference)
        XCTAssertEqual(dashboard.analyzedSessionCount, sessions.count)
        XCTAssertEqual(dashboard.currentStreak, service.currentStreak(from: sessions, referenceDate: reference))
        XCTAssertEqual(dashboard.workoutsThisWeek, service.workoutsThisWeek(from: sessions, referenceDate: reference))
        XCTAssertEqual(
            dashboard.weeklyVolumeTrend,
            service.weeklyVolumeTrend(
                from: sessions,
                weeks: AnalyticsConfig.defaultWeeklyVolumeWeeks,
                referenceDate: reference
            )
        )
        XCTAssertEqual(
            normalizedLiftTrends(dashboard.liftTrends),
            normalizedLiftTrends(service.mostTrainedLiftTrends(from: sessions, limit: 3))
        )
        XCTAssertEqual(
            dashboard.exerciseProgress,
            service.strengthE1RMProgressByExercise(from: sessions)
        )
        XCTAssertEqual(
            dashboard.progressionBreakdown,
            service.progressionBreakdown(
                from: sessions,
                days: AnalyticsConfig.defaultBreakdownWindowDays,
                referenceDate: reference
            )
        )
        XCTAssertEqual(
            dashboard.engineHealth,
            service.engineHealth(
                from: sessions,
                days: AnalyticsConfig.defaultEngineHealthWindowDays,
                referenceDate: reference
            )
        )
        XCTAssertEqual(
            dashboard.decisionProfileHealth,
            service.decisionProfileHealth(
                from: sessions,
                days: AnalyticsConfig.defaultDecisionProfileWindowDays,
                referenceDate: reference
            )
        )
        XCTAssertEqual(
            dashboard.progressionAlerts,
            service.progressionAlerts(
                from: sessions,
                days: AnalyticsConfig.defaultAlertWindowDays,
                referenceDate: reference
            )
        )

        let dryRun = service.dryRunProfiles(
            from: sessions,
            recentSessionLimit: AnalyticsConfig.defaultRecentSessionLimit
        )
        XCTAssertEqual(dashboard.dryRunInputCount, dryRun.inputCount)
        XCTAssertEqual(dashboard.dryRunProfiles, dryRun.results)
        XCTAssertEqual(
            normalizedPersonalRecordEvents(dashboard.recentPRs),
            normalizedPersonalRecordEvents(
                service.recentPRs(sessions: sessions, limit: AnalyticsConfig.defaultRecentPRLimit)
            )
        )
    }

    func testDashboardData_profileWith250Sessions() {
        let reference = makeDate(year: 2026, month: 2, day: 13)
        let sessions = makeAnalyticsDataset(sessionCount: 250, referenceDate: reference)

        measure {
            _ = service.dashboardData(from: sessions, referenceDate: reference)
        }
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day)
        return calendar.date(from: components)!
    }

    private func makeStrengthExercise(
        name: String,
        weight: Double,
        reps: Int,
        recommendation: ProgressionRecommendation? = nil,
        suggestion: ProgressionSuggestion? = nil
    ) -> SessionExercise {
        makeStrengthExercise(
            name: name,
            sets: [SetData(setNumber: 1, weight: weight, reps: reps, completed: true)],
            recommendation: recommendation,
            suggestion: suggestion
        )
    }

    private func makeStrengthExercise(
        name: String,
        sets: [SetData],
        recommendation: ProgressionRecommendation? = nil,
        suggestion: ProgressionSuggestion? = nil
    ) -> SessionExercise {
        SessionExercise(
            exerciseId: UUID(),
            exerciseName: name,
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: sets
                )
            ],
            progressionRecommendation: recommendation,
            progressionSuggestion: suggestion
        )
    }

    private func makeSession(date: Date, exercises: [SessionExercise]) -> Session {
        Session(
            workoutId: UUID(),
            workoutName: "Test Workout",
            date: date,
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Strength",
                    moduleType: .strength,
                    completedExercises: exercises
                )
            ]
        )
    }

    private func makeAnalyticsDataset(sessionCount: Int, referenceDate: Date) -> [Session] {
        var sessions: [Session] = []
        for index in 0..<sessionCount {
            guard let date = calendar.date(byAdding: .day, value: -index, to: referenceDate) else { continue }
            let baseWeight = Double(185 + (index % 20))
            let reps = 3 + (index % 6)

            let suggestion = ProgressionSuggestion(
                baseValue: baseWeight,
                suggestedValue: baseWeight + 5,
                metric: .weight,
                percentageApplied: 2.5,
                appliedOutcome: .progress,
                confidence: 0.45 + (Double(index % 5) * 0.1),
                decisionCode: index % 4 == 0 ? "READINESS_GATE" : "WEIGHTED_PROGRESS"
            )

            let bench = makeStrengthExercise(
                name: "Bench",
                sets: [
                    SetData(setNumber: 1, weight: baseWeight, reps: reps, completed: true),
                    SetData(setNumber: 2, weight: baseWeight + 10, reps: max(1, reps - 1), completed: true)
                ],
                recommendation: index.isMultiple(of: 3) ? .progress : .stay,
                suggestion: suggestion
            )

            let squat = makeStrengthExercise(
                name: "Squat",
                sets: [SetData(setNumber: 1, weight: baseWeight + 30, reps: reps, completed: true)],
                recommendation: index.isMultiple(of: 7) ? .regress : .progress,
                suggestion: suggestion
            )

            sessions.append(makeSession(date: date, exercises: [bench, squat]))
        }

        return sessions
    }

    private struct LiftTrendComparable: Equatable {
        let exerciseName: String
        let latestDate: Date
        let latestTopSet: StrengthTopSet
        let previousTopSet: StrengthTopSet?
        let sessionCount: Int
    }

    private struct PersonalRecordComparable: Equatable {
        let exerciseName: String
        let date: Date
        let type: PersonalRecordType
        let previousBest: Double
        let newBest: Double
        let topSet: StrengthTopSet
    }

    private func normalizedLiftTrends(_ trends: [LiftTrend]) -> [LiftTrendComparable] {
        trends
            .map {
                LiftTrendComparable(
                    exerciseName: $0.exerciseName,
                    latestDate: $0.latestDate,
                    latestTopSet: $0.latestTopSet,
                    previousTopSet: $0.previousTopSet,
                    sessionCount: $0.sessionCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.exerciseName != rhs.exerciseName {
                    return lhs.exerciseName < rhs.exerciseName
                }
                return lhs.latestDate < rhs.latestDate
            }
    }

    private func normalizedPersonalRecordEvents(
        _ events: [PersonalRecordEvent]
    ) -> [PersonalRecordComparable] {
        events.map {
            PersonalRecordComparable(
                exerciseName: $0.exerciseName,
                date: $0.date,
                type: $0.type,
                previousBest: $0.previousBest,
                newBest: $0.newBest,
                topSet: $0.topSet
            )
        }
    }
}

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    actor MockComputationPerformer: AnalyticsComputationPerforming {
        private(set) var callCount = 0
        private let delayNanos: UInt64

        init(delayNanos: UInt64 = 0) {
            self.delayNanos = delayNanos
        }

        func compute(
            from sessions: [Session],
            weeklyVolumeWeeks _: Int,
            decisionWindowDays _: Int
        ) async -> AnalyticsComputationSnapshot {
            callCount += 1
            if delayNanos > 0 {
                try? await Task.sleep(nanoseconds: delayNanos)
            }

            return AnalyticsComputationSnapshot(
                analyzedSessionCount: sessions.count,
                currentStreak: sessions.count,
                workoutsThisWeek: sessions.count,
                weeklyVolumeTrend: [],
                liftTrends: [],
                exerciseProgress: [],
                progressionBreakdown: .empty,
                engineHealth: .empty,
                decisionProfileHealth: [],
                progressionAlerts: [],
                dryRunProfiles: [],
                dryRunInputCount: 0,
                recentPRs: [],
                muscleGroupVolume: [],
                cardioSummary: .empty,
                weeklyCardioTrend: []
            )
        }
    }

    func testLoad_skipsRecomputeWhenFingerprintUnchanged() async {
        let performer = MockComputationPerformer()
        let viewModel = AnalyticsViewModel(computationPerformer: performer)
        let sessions = [makeSession(reps: 5)]

        viewModel.load(from: sessions)
        await waitUntil("initial compute") {
            await performer.callCount == 1 && viewModel.analyzedSessionCount == 1
        }

        viewModel.load(from: sessions)

        try? await Task.sleep(nanoseconds: 80_000_000)
        let callCount = await performer.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testLoad_recomputesWhenRelevantStrengthDataChanges() async {
        let performer = MockComputationPerformer()
        let viewModel = AnalyticsViewModel(computationPerformer: performer)

        var sessions = [makeSession(reps: 5)]
        viewModel.load(from: sessions)
        await waitUntil("initial compute") { await performer.callCount == 1 }

        sessions[0].completedModules[0].completedExercises[0].completedSetGroups[0].sets[0].reps = 6
        viewModel.load(from: sessions)

        await waitUntil("recompute") { await performer.callCount == 2 }
        let callCount = await performer.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testLoad_cancelsStaleTaskAndAppliesLatestResult() async {
        let performer = MockComputationPerformer(delayNanos: 250_000_000)
        let viewModel = AnalyticsViewModel(computationPerformer: performer)

        viewModel.load(from: [makeSession(reps: 5)])
        viewModel.load(from: [makeSession(reps: 5), makeSession(reps: 6)])

        await waitUntil("latest result") {
            viewModel.analyzedSessionCount == 2 && viewModel.currentStreak == 2
        }

        XCTAssertEqual(viewModel.analyzedSessionCount, 2)
        XCTAssertEqual(viewModel.currentStreak, 2)
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        condition: @escaping () async -> Bool
    ) async {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for \(description)")
    }

    private func makeSession(reps: Int) -> Session {
        let suggestion = ProgressionSuggestion(
            baseValue: 100,
            suggestedValue: 105,
            metric: .weight,
            percentageApplied: 5,
            appliedOutcome: .progress,
            confidence: 0.8,
            decisionCode: "WEIGHTED_PROGRESS"
        )

        let exercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: "Bench",
            exerciseType: .strength,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: [SetData(setNumber: 1, weight: 100, reps: reps, completed: true)]
                )
            ],
            progressionRecommendation: .progress,
            progressionSuggestion: suggestion
        )

        return Session(
            workoutId: UUID(),
            workoutName: "Test",
            date: Date(),
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Strength",
                    moduleType: .strength,
                    completedExercises: [exercise]
                )
            ]
        )
    }
}
