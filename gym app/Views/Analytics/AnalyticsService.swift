//
//  AnalyticsService.swift
//  gym app
//
//  Pure analytics computations derived from completed session data.
//

import Foundation
import SwiftUI

struct AnalyticsService {
    private let calendar = Calendar.current

    private struct ProgressionDecisionRecord {
        let date: Date
        let exerciseName: String
        let decisionPath: String
        let expected: ProgressionRecommendation
        let actual: ProgressionRecommendation?
        let confidence: Double
    }

    func dashboardData(
        from sessions: [Session],
        referenceDate: Date = Date(),
        weeklyVolumeWeeks: Int = AnalyticsConfig.defaultWeeklyVolumeWeeks,
        liftTrendLimit: Int = 3,
        decisionWindowDays: Int = AnalyticsConfig.defaultBreakdownWindowDays,
        recentSessionLimit: Int = AnalyticsConfig.defaultRecentSessionLimit,
        recentPRLimit: Int = AnalyticsConfig.defaultRecentPRLimit
    ) -> AnalyticsDashboardData {
        let orderedSessionsDesc = sessions.sorted { $0.date > $1.date }
        let orderedSessionsAsc = orderedSessionsDesc.reversed()

        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)

        let decisionCutoffDate: Date?
        if decisionWindowDays > 0 {
            decisionCutoffDate = calendar.date(byAdding: .day, value: -decisionWindowDays, to: referenceDate)
        } else {
            decisionCutoffDate = nil
        }

        var weekStarts: [Date] = []
        if weeklyVolumeWeeks > 0,
           let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start {
            for offset in stride(from: weeklyVolumeWeeks - 1, through: 0, by: -1) {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else {
                    continue
                }
                weekStarts.append(weekStart)
            }
        }
        let validWeekStarts = Set(weekStarts)
        var totalVolumeByWeek: [Date: Double] = [:]
        var sessionCountByWeek: [Date: Int] = [:]

        var workoutsThisWeek = 0
        var workoutDays: Set<Date> = []

        var liftHistory: [String: [(date: Date, topSet: StrengthTopSet)]] = [:]
        var pointsByExerciseAndDay: [String: [Date: E1RMProgressPoint]] = [:]
        var topBrzyckiBySessionExercise: [UUID: [UUID: StrengthTopSet]] = [:]

        var progressCount = 0
        var stayCount = 0
        var regressCount = 0
        var decisionRecords: [ProgressionDecisionRecord] = []
        var dryRunDecisionRecords: [ProgressionDecisionRecord] = []

        let recentSessionIds = Set(orderedSessionsDesc.prefix(max(1, recentSessionLimit)).map(\.id))

        for session in orderedSessionsDesc {
            let sessionDay = calendar.startOfDay(for: session.date)
            workoutDays.insert(sessionDay)

            if let currentWeek, currentWeek.contains(session.date) {
                workoutsThisWeek += 1
            }

            let isInDecisionWindow = decisionCutoffDate == nil || session.date >= decisionCutoffDate!
            let isInDryRunSlice = recentSessionIds.contains(session.id)

            var sessionStrengthVolume = 0.0

            for module in session.completedModules where !module.skipped {
                for exercise in module.completedExercises {
                    if exercise.exerciseType == .strength {
                        let strengthMetrics = analyzeStrengthSetMetrics(for: exercise)
                        sessionStrengthVolume += strengthMetrics.volume

                        if let topStrengthSet = strengthMetrics.topStrengthSet {
                            liftHistory[exercise.exerciseName, default: []].append((session.date, topStrengthSet))
                        }

                        if let topBrzyckiSet = strengthMetrics.topBrzyckiSet {
                            topBrzyckiBySessionExercise[session.id, default: [:]][exercise.id] = topBrzyckiSet

                            let candidate = E1RMProgressPoint(
                                date: sessionDay,
                                estimatedOneRepMax: topBrzyckiSet.estimatedOneRepMax,
                                topSet: topBrzyckiSet
                            )

                            let existing = pointsByExerciseAndDay[exercise.exerciseName]?[sessionDay]
                            if existing == nil || isBetter(candidate, than: existing!) {
                                pointsByExerciseAndDay[exercise.exerciseName, default: [:]][sessionDay] = candidate
                            }
                        }
                    }

                    if isInDecisionWindow, let recommendation = exercise.progressionRecommendation {
                        switch recommendation {
                        case .progress: progressCount += 1
                        case .stay: stayCount += 1
                        case .regress: regressCount += 1
                        }
                    }

                    guard let suggestion = exercise.progressionSuggestion,
                          let expected = expectedRecommendation(from: suggestion) else {
                        continue
                    }

                    let record = ProgressionDecisionRecord(
                        date: session.date,
                        exerciseName: exercise.exerciseName,
                        decisionPath: decisionPath(from: suggestion),
                        expected: expected,
                        actual: exercise.progressionRecommendation,
                        confidence: suggestion.confidence ?? 0.56
                    )

                    if isInDecisionWindow {
                        decisionRecords.append(record)
                    }
                    if isInDryRunSlice {
                        dryRunDecisionRecords.append(record)
                    }
                }
            }

            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start,
               validWeekStarts.contains(weekStart) {
                totalVolumeByWeek[weekStart, default: 0] += sessionStrengthVolume
                sessionCountByWeek[weekStart, default: 0] += 1
            }
        }

        let weeklyVolumeTrend = weekStarts.map { weekStart in
            WeeklyVolumePoint(
                weekStart: weekStart,
                totalVolume: totalVolumeByWeek[weekStart] ?? 0,
                sessionCount: sessionCountByWeek[weekStart] ?? 0
            )
        }

        let liftTrends = liftHistory
            .compactMap { exerciseName, entries -> LiftTrend? in
                guard let latest = entries.first else { return nil }
                return LiftTrend(
                    exerciseName: exerciseName,
                    latestDate: latest.date,
                    latestTopSet: latest.topSet,
                    previousTopSet: entries.dropFirst().first?.topSet,
                    sessionCount: entries.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.sessionCount != rhs.sessionCount {
                    return lhs.sessionCount > rhs.sessionCount
                }
                return lhs.latestDate > rhs.latestDate
            }
            .prefix(max(0, liftTrendLimit))

        let exerciseProgress = pointsByExerciseAndDay
            .map { exerciseName, pointsByDay in
                let points = pointsByDay.values.sorted { $0.date < $1.date }
                return E1RMExerciseProgress(exerciseName: exerciseName, points: points)
            }
            .filter { !$0.points.isEmpty }
            .sorted { lhs, rhs in
                if lhs.latestDate != rhs.latestDate {
                    return lhs.latestDate > rhs.latestDate
                }
                return lhs.exerciseName < rhs.exerciseName
            }

        let progressionBreakdown = ProgressionBreakdown(
            progressCount: progressCount,
            stayCount: stayCount,
            regressCount: regressCount
        )

        let comparableDecisionRecords = decisionRecords.filter { $0.actual != nil }
        let engineHealth: ProgressionEngineHealth
        if comparableDecisionRecords.isEmpty {
            engineHealth = .empty
        } else {
            let accepted = comparableDecisionRecords.filter { $0.actual == $0.expected }.count
            let overrides = comparableDecisionRecords.count - accepted
            let regress = comparableDecisionRecords.filter { $0.actual == .regress }.count
            engineHealth = ProgressionEngineHealth(
                totalDecisions: comparableDecisionRecords.count,
                acceptedCount: accepted,
                overriddenCount: overrides,
                regressCount: regress
            )
        }

        let decisionProfileHealth = Dictionary(grouping: comparableDecisionRecords, by: \.decisionPath)
            .map { name, entries in
                let accepted = entries.filter { $0.actual == $0.expected }.count
                let regress = entries.filter { $0.actual == .regress }.count
                return DecisionProfileHealth(
                    name: name,
                    totalDecisions: entries.count,
                    acceptedCount: accepted,
                    regressCount: regress
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalDecisions != rhs.totalDecisions {
                    return lhs.totalDecisions > rhs.totalDecisions
                }
                return lhs.name < rhs.name
            }

        let progressionAlerts = progressionAlertsFromDecisionRecords(comparableDecisionRecords)

        let dryRunProfiles = AnalyticsConfig.dryRunProfiles.map { config in
            var progress = 0
            var stay = 0
            var regress = 0
            var agreement = 0
            var comparable = 0

            for record in dryRunDecisionRecords {
                let predicted = predictedOutcome(
                    for: record,
                    confidenceThreshold: config.confidenceThreshold
                )

                switch predicted {
                case .progress: progress += 1
                case .stay: stay += 1
                case .regress: regress += 1
                }

                if let actual = record.actual {
                    comparable += 1
                    if actual == predicted { agreement += 1 }
                }
            }

            return DryRunProfileResult(
                name: config.name,
                progressCount: progress,
                stayCount: stay,
                regressCount: regress,
                agreementCount: agreement,
                comparableCount: comparable
            )
        }

        var bestEstimatedOneRepMaxByExercise: [String: Double] = [:]
        var prEvents: [PersonalRecordEvent] = []
        for session in orderedSessionsAsc {
            for module in session.completedModules where !module.skipped {
                for exercise in module.completedExercises where exercise.exerciseType == .strength {
                    guard let topSet = topBrzyckiBySessionExercise[session.id]?[exercise.id] else { continue }
                    let exerciseName = exercise.exerciseName

                    guard let bestEstimatedOneRepMax = bestEstimatedOneRepMaxByExercise[exerciseName] else {
                        bestEstimatedOneRepMaxByExercise[exerciseName] = topSet.estimatedOneRepMax
                        continue
                    }

                    if topSet.estimatedOneRepMax > bestEstimatedOneRepMax + AnalyticsConfig.oneRepMaxPRTolerance {
                        prEvents.append(
                            PersonalRecordEvent(
                                exerciseName: exerciseName,
                                date: session.date,
                                type: .estimatedOneRepMax,
                                previousBest: bestEstimatedOneRepMax,
                                newBest: topSet.estimatedOneRepMax,
                                topSet: topSet
                            )
                        )
                    }

                    bestEstimatedOneRepMaxByExercise[exerciseName] = max(bestEstimatedOneRepMax, topSet.estimatedOneRepMax)
                }
            }
        }

        let recentPRs = Array(prEvents.sorted { $0.date > $1.date }.prefix(max(0, recentPRLimit)))

        return AnalyticsDashboardData(
            analyzedSessionCount: sessions.count,
            currentStreak: currentStreak(fromWorkoutDays: workoutDays, referenceDate: referenceDate),
            workoutsThisWeek: workoutsThisWeek,
            weeklyVolumeTrend: weeklyVolumeTrend,
            liftTrends: Array(liftTrends),
            exerciseProgress: exerciseProgress,
            progressionBreakdown: progressionBreakdown,
            engineHealth: engineHealth,
            decisionProfileHealth: decisionProfileHealth,
            progressionAlerts: progressionAlerts,
            dryRunProfiles: dryRunProfiles,
            dryRunInputCount: dryRunDecisionRecords.count,
            recentPRs: recentPRs
        )
    }

    func currentStreak(from sessions: [Session], referenceDate: Date = Date()) -> Int {
        let workoutDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        return currentStreak(fromWorkoutDays: workoutDays, referenceDate: referenceDate)
    }

    func workoutsThisWeek(from sessions: [Session], referenceDate: Date = Date()) -> Int {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        return sessions.filter { currentWeek.contains($0.date) }.count
    }

    func weeklyVolumeTrend(
        from sessions: [Session],
        weeks: Int = AnalyticsConfig.defaultWeeklyVolumeWeeks,
        referenceDate: Date = Date()
    ) -> [WeeklyVolumePoint] {
        guard weeks > 0,
              let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }

        var weekStarts: [Date] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else {
                continue
            }
            weekStarts.append(weekStart)
        }

        let validWeekStarts = Set(weekStarts)
        var totalVolumeByWeek: [Date: Double] = [:]
        var sessionCountByWeek: [Date: Int] = [:]

        for session in sessions {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start,
                  validWeekStarts.contains(weekStart) else {
                continue
            }

            totalVolumeByWeek[weekStart, default: 0] += strengthVolume(for: session)
            sessionCountByWeek[weekStart, default: 0] += 1
        }

        return weekStarts.map { weekStart in
            WeeklyVolumePoint(
                weekStart: weekStart,
                totalVolume: totalVolumeByWeek[weekStart] ?? 0,
                sessionCount: sessionCountByWeek[weekStart] ?? 0
            )
        }
    }

    func mostTrainedLiftTrends(from sessions: [Session], limit: Int = 3) -> [LiftTrend] {
        guard limit > 0 else { return [] }

        struct LiftSessionEntry {
            let date: Date
            let topSet: StrengthTopSet
        }

        var liftHistory: [String: [LiftSessionEntry]] = [:]
        let sortedSessions = sessions.sorted { $0.date > $1.date }

        for session in sortedSessions {
            for exercise in strengthExercises(in: session) {
                guard let topSet = topStrengthSet(for: exercise) else { continue }
                liftHistory[exercise.exerciseName, default: []].append(
                    LiftSessionEntry(date: session.date, topSet: topSet)
                )
            }
        }

        let ranked = liftHistory
            .compactMap { exerciseName, entries -> LiftTrend? in
                guard let latest = entries.first else { return nil }
                return LiftTrend(
                    exerciseName: exerciseName,
                    latestDate: latest.date,
                    latestTopSet: latest.topSet,
                    previousTopSet: entries.dropFirst().first?.topSet,
                    sessionCount: entries.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.sessionCount != rhs.sessionCount {
                    return lhs.sessionCount > rhs.sessionCount
                }
                return lhs.latestDate > rhs.latestDate
            }

        return Array(ranked.prefix(limit))
    }

    func progressionBreakdown(
        from sessions: [Session],
        days: Int = AnalyticsConfig.defaultBreakdownWindowDays,
        referenceDate: Date = Date()
    ) -> ProgressionBreakdown {
        let cutoffDate: Date?
        if days > 0 {
            cutoffDate = calendar.date(byAdding: .day, value: -days, to: referenceDate)
        } else {
            cutoffDate = nil
        }

        var progressCount = 0
        var stayCount = 0
        var regressCount = 0

        for session in sessions {
            if let cutoffDate, session.date < cutoffDate { continue }

            for module in session.completedModules where !module.skipped {
                for exercise in module.completedExercises {
                    guard let recommendation = exercise.progressionRecommendation else { continue }
                    switch recommendation {
                    case .progress: progressCount += 1
                    case .stay: stayCount += 1
                    case .regress: regressCount += 1
                    }
                }
            }
        }

        return ProgressionBreakdown(
            progressCount: progressCount,
            stayCount: stayCount,
            regressCount: regressCount
        )
    }

    func engineHealth(
        from sessions: [Session],
        days: Int = AnalyticsConfig.defaultEngineHealthWindowDays,
        referenceDate: Date = Date()
    ) -> ProgressionEngineHealth {
        let records = progressionDecisionRecords(
            from: sessions,
            days: days,
            referenceDate: referenceDate
        ).filter { $0.actual != nil }

        guard !records.isEmpty else { return .empty }

        let accepted = records.filter { $0.actual == $0.expected }.count
        let overrides = records.count - accepted
        let regress = records.filter { $0.actual == .regress }.count

        return ProgressionEngineHealth(
            totalDecisions: records.count,
            acceptedCount: accepted,
            overriddenCount: overrides,
            regressCount: regress
        )
    }

    func decisionProfileHealth(
        from sessions: [Session],
        days: Int = AnalyticsConfig.defaultDecisionProfileWindowDays,
        referenceDate: Date = Date()
    ) -> [DecisionProfileHealth] {
        let records = progressionDecisionRecords(
            from: sessions,
            days: days,
            referenceDate: referenceDate
        ).filter { $0.actual != nil }

        let grouped = Dictionary(grouping: records, by: \.decisionPath)
        return grouped
            .map { name, entries in
                let accepted = entries.filter { $0.actual == $0.expected }.count
                let regress = entries.filter { $0.actual == .regress }.count
                return DecisionProfileHealth(
                    name: name,
                    totalDecisions: entries.count,
                    acceptedCount: accepted,
                    regressCount: regress
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalDecisions != rhs.totalDecisions {
                    return lhs.totalDecisions > rhs.totalDecisions
                }
                return lhs.name < rhs.name
            }
    }

    func progressionAlerts(
        from sessions: [Session],
        days: Int = AnalyticsConfig.defaultAlertWindowDays,
        referenceDate: Date = Date()
    ) -> [ProgressionAlert] {
        let records = progressionDecisionRecords(
            from: sessions,
            days: days,
            referenceDate: referenceDate
        ).filter { $0.actual != nil }

        return progressionAlertsFromDecisionRecords(records)
    }

    private func progressionAlertsFromDecisionRecords(_ records: [ProgressionDecisionRecord]) -> [ProgressionAlert] {
        let byExercise = Dictionary(grouping: records, by: \.exerciseName)
        var alerts: [ProgressionAlert] = []

        for (exerciseName, entries) in byExercise {
            guard entries.count >= AnalyticsConfig.minDecisionsForAlerts else { continue }

            let accepted = entries.filter { $0.actual == $0.expected }.count
            let acceptanceRate = Double(accepted) / Double(entries.count)
            let regressCount = entries.filter { $0.actual == .regress }.count
            let regressRate = Double(regressCount) / Double(entries.count)
            let overrideRate = 1 - acceptanceRate

            if acceptanceRate < AnalyticsConfig.lowAcceptanceThreshold {
                alerts.append(
                    ProgressionAlert(
                        title: "\(exerciseName): Low acceptance",
                        message: "Only \(Int((acceptanceRate * 100).rounded()))% of suggestions are accepted (\(entries.count) decisions). Consider a more conservative profile.",
                        type: .lowAcceptance
                    )
                )
            }

            if regressRate > AnalyticsConfig.highRegressThreshold {
                alerts.append(
                    ProgressionAlert(
                        title: "\(exerciseName): High regressions",
                        message: "Regress selected \(Int((regressRate * 100).rounded()))% of the time. Tighten progression caps or raise readiness gates.",
                        type: .highRegress
                    )
                )
            }

            if overrideRate > AnalyticsConfig.highOverrideThreshold {
                alerts.append(
                    ProgressionAlert(
                        title: "\(exerciseName): Frequent overrides",
                        message: "Overrides are \(Int((overrideRate * 100).rounded()))%. The current decision profile may be too aggressive.",
                        type: .highOverride
                    )
                )
            }
        }

        let severityRank: (ProgressionAlertType) -> Int = { type in
            switch type {
            case .lowAcceptance: return 0
            case .highRegress: return 1
            case .highOverride: return 2
            }
        }

        return alerts
            .sorted { lhs, rhs in
                if severityRank(lhs.type) != severityRank(rhs.type) {
                    return severityRank(lhs.type) < severityRank(rhs.type)
                }
                return lhs.title < rhs.title
            }
    }

    func dryRunProfiles(
        from sessions: [Session],
        recentSessionLimit: Int = AnalyticsConfig.defaultRecentSessionLimit
    ) -> (results: [DryRunProfileResult], inputCount: Int) {
        let orderedSessions = sessions.sorted { $0.date > $1.date }
        let sessionSlice = Array(orderedSessions.prefix(max(1, recentSessionLimit)))

        let records = progressionDecisionRecords(
            from: sessionSlice,
            days: 0,
            referenceDate: Date()
        )

        let results = AnalyticsConfig.dryRunProfiles.map { config in
            var progress = 0
            var stay = 0
            var regress = 0
            var agreement = 0
            var comparable = 0

            for record in records {
                let predicted = predictedOutcome(
                    for: record,
                    confidenceThreshold: config.confidenceThreshold
                )

                switch predicted {
                case .progress: progress += 1
                case .stay: stay += 1
                case .regress: regress += 1
                }

                if let actual = record.actual {
                    comparable += 1
                    if actual == predicted { agreement += 1 }
                }
            }

            return DryRunProfileResult(
                name: config.name,
                progressCount: progress,
                stayCount: stay,
                regressCount: regress,
                agreementCount: agreement,
                comparableCount: comparable
            )
        }

        return (results, records.count)
    }

    func recentPRs(sessions: [Session], limit: Int = 3) -> [PersonalRecordEvent] {
        guard limit > 0 else { return [] }

        var bestEstimatedOneRepMaxByExercise: [String: Double] = [:]
        var events: [PersonalRecordEvent] = []
        let orderedSessions = sessions.sorted { $0.date < $1.date }

        for session in orderedSessions {
            for exercise in strengthExercises(in: session) {
                guard let topSet = topBrzyckiSet(for: exercise) else { continue }
                let exerciseName = exercise.exerciseName

                guard let bestEstimatedOneRepMax = bestEstimatedOneRepMaxByExercise[exerciseName] else {
                    bestEstimatedOneRepMaxByExercise[exerciseName] = topSet.estimatedOneRepMax
                    continue
                }

                if topSet.estimatedOneRepMax > bestEstimatedOneRepMax + AnalyticsConfig.oneRepMaxPRTolerance {
                    events.append(
                        PersonalRecordEvent(
                            exerciseName: exerciseName,
                            date: session.date,
                            type: .estimatedOneRepMax,
                            previousBest: bestEstimatedOneRepMax,
                            newBest: topSet.estimatedOneRepMax,
                            topSet: topSet
                        )
                    )
                }

                bestEstimatedOneRepMaxByExercise[exerciseName] = max(bestEstimatedOneRepMax, topSet.estimatedOneRepMax)
            }
        }

        return Array(events.sorted { $0.date > $1.date }.prefix(limit))
    }

    func strengthE1RMProgressByExercise(from sessions: [Session]) -> [E1RMExerciseProgress] {
        let orderedSessions = sessions.sorted { $0.date < $1.date }
        var pointsByExerciseAndDay: [String: [Date: E1RMProgressPoint]] = [:]

        for session in orderedSessions {
            let day = calendar.startOfDay(for: session.date)
            for exercise in strengthExercises(in: session) {
                guard let topSet = topBrzyckiSet(for: exercise) else { continue }

                let candidate = E1RMProgressPoint(
                    date: day,
                    estimatedOneRepMax: topSet.estimatedOneRepMax,
                    topSet: topSet
                )

                let existing = pointsByExerciseAndDay[exercise.exerciseName]?[day]
                if let existing, !isBetter(candidate, than: existing) {
                    continue
                }

                pointsByExerciseAndDay[exercise.exerciseName, default: [:]][day] = candidate
            }
        }

        return pointsByExerciseAndDay
            .map { exerciseName, pointsByDay in
                let points = pointsByDay.values.sorted { $0.date < $1.date }
                return E1RMExerciseProgress(exerciseName: exerciseName, points: points)
            }
            .filter { !$0.points.isEmpty }
            .sorted { lhs, rhs in
                if lhs.latestDate != rhs.latestDate {
                    return lhs.latestDate > rhs.latestDate
                }
                return lhs.exerciseName < rhs.exerciseName
            }
    }

    func e1RMProgress(for exerciseName: String, sessions: [Session]) -> [E1RMProgressPoint] {
        strengthE1RMProgressByExercise(from: sessions)
            .first(where: { $0.exerciseName == exerciseName })?
            .points ?? []
    }

    private func currentStreak(fromWorkoutDays workoutDays: Set<Date>, referenceDate: Date) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        guard !workoutDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        if !workoutDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  workoutDays.contains(yesterday) else {
                return 0
            }
            checkDate = yesterday
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    private func analyzeStrengthSetMetrics(
        for exercise: SessionExercise
    ) -> (volume: Double, topStrengthSet: StrengthTopSet?, topBrzyckiSet: StrengthTopSet?) {
        var volume = 0.0
        var topStrengthMeta: (weight: Double, reps: Int, set: StrengthTopSet)?
        var topBrzyckiSet: StrengthTopSet?

        for setGroup in exercise.completedSetGroups {
            for set in setGroup.sets where set.completed {
                guard let weight = set.weight, weight > 0 else { continue }

                let reps = set.reps ?? 0
                if reps > 0 {
                    volume += weight * Double(reps)
                }

                let normalizedReps = max(1, reps)
                let candidate = StrengthTopSet(weight: weight, reps: normalizedReps)

                if let currentTop = topStrengthMeta {
                    if weight > currentTop.weight + 0.0001 ||
                        (abs(weight - currentTop.weight) <= 0.0001 && reps > currentTop.reps) {
                        topStrengthMeta = (weight: weight, reps: reps, set: candidate)
                    }
                } else {
                    topStrengthMeta = (weight: weight, reps: reps, set: candidate)
                }

                if AnalyticsConfig.e1RMRepRange.contains(reps) {
                    if let existingTop = topBrzyckiSet {
                        if isBetter(candidate, than: existingTop) {
                            topBrzyckiSet = candidate
                        }
                    } else {
                        topBrzyckiSet = candidate
                    }
                }
            }
        }

        return (volume: volume, topStrengthSet: topStrengthMeta?.set, topBrzyckiSet: topBrzyckiSet)
    }

    private func strengthExercises(in session: Session) -> [SessionExercise] {
        session.completedModules
            .filter { !$0.skipped }
            .flatMap { $0.completedExercises }
            .filter { $0.exerciseType == .strength }
    }

    private func strengthVolume(for session: Session) -> Double {
        strengthExercises(in: session)
            .reduce(0) { $0 + analyzeStrengthSetMetrics(for: $1).volume }
    }

    private func topStrengthSet(for exercise: SessionExercise) -> StrengthTopSet? {
        analyzeStrengthSetMetrics(for: exercise).topStrengthSet
    }

    private func topBrzyckiSet(for exercise: SessionExercise) -> StrengthTopSet? {
        analyzeStrengthSetMetrics(for: exercise).topBrzyckiSet
    }

    private func isBetter(_ lhs: StrengthTopSet, than rhs: StrengthTopSet) -> Bool {
        if lhs.estimatedOneRepMax != rhs.estimatedOneRepMax {
            return lhs.estimatedOneRepMax > rhs.estimatedOneRepMax
        }
        if lhs.weight != rhs.weight {
            return lhs.weight > rhs.weight
        }
        return lhs.reps < rhs.reps
    }

    private func isBetter(_ lhs: E1RMProgressPoint, than rhs: E1RMProgressPoint) -> Bool {
        if lhs.estimatedOneRepMax != rhs.estimatedOneRepMax {
            return lhs.estimatedOneRepMax > rhs.estimatedOneRepMax
        }
        return isBetter(lhs.topSet, than: rhs.topSet)
    }

    private func progressionDecisionRecords(
        from sessions: [Session],
        days: Int,
        referenceDate: Date
    ) -> [ProgressionDecisionRecord] {
        let cutoffDate: Date?
        if days > 0 {
            cutoffDate = calendar.date(byAdding: .day, value: -days, to: referenceDate)
        } else {
            cutoffDate = nil
        }

        var records: [ProgressionDecisionRecord] = []

        for session in sessions {
            if let cutoffDate, session.date < cutoffDate { continue }

            for module in session.completedModules where !module.skipped {
                for exercise in module.completedExercises {
                    guard let suggestion = exercise.progressionSuggestion,
                          let expected = expectedRecommendation(from: suggestion) else {
                        continue
                    }

                    records.append(
                        ProgressionDecisionRecord(
                            date: session.date,
                            exerciseName: exercise.exerciseName,
                            decisionPath: decisionPath(from: suggestion),
                            expected: expected,
                            actual: exercise.progressionRecommendation,
                            confidence: suggestion.confidence ?? 0.56
                        )
                    )
                }
            }
        }

        return records.sorted { $0.date > $1.date }
    }

    private func expectedRecommendation(from suggestion: ProgressionSuggestion) -> ProgressionRecommendation? {
        if let applied = suggestion.appliedOutcome {
            return applied
        }
        if suggestion.suggestedValue > suggestion.baseValue + 0.0001 {
            return .progress
        }
        if suggestion.suggestedValue < suggestion.baseValue - 0.0001 {
            return .regress
        }
        return .stay
    }

    private func decisionPath(from suggestion: ProgressionSuggestion) -> String {
        guard let code = suggestion.decisionCode else { return "Unlabeled" }
        if code.contains("DOUBLE_PROGRESSION_GATE") { return "Double Progression Gate" }
        if code.contains("READINESS_GATE") { return "Readiness Gate" }
        if code.contains("WEIGHTED_") { return "Weighted Model" }
        if code.contains("BASELINE") { return "Baseline Rule" }
        if code.contains("MANUAL_OVERRIDE") { return "Manual Carryover" }
        return "Unlabeled"
    }

    private func predictedOutcome(
        for record: ProgressionDecisionRecord,
        confidenceThreshold: Double
    ) -> ProgressionRecommendation {
        if record.decisionPath == "Readiness Gate" {
            return .stay
        }
        if record.expected == .stay {
            return .stay
        }
        if record.confidence >= confidenceThreshold {
            return record.expected
        }
        return .stay
    }
}
