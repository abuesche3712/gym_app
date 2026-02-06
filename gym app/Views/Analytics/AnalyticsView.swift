//
//  AnalyticsView.swift
//  gym app
//
//  Analytics and progression insights
//

import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    analyticsHeader

                    if viewModel.analyzedSessionCount == 0 {
                        emptyState
                    } else {
                        consistencyCard
                        volumeTrendCard
                        liftTrendsCard
                        progressionBreakdownCard
                        recentPRsCard
                    }
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, 56)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.load(from: sessionViewModel.sessions)
            }
            .onChange(of: sessionViewModel.sessions) { _, sessions in
                viewModel.load(from: sessions)
            }
        }
    }

    private var analyticsHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANALYTICS")
                        .elegantLabel(color: AppColors.dominant)
                    Text("Progress Dashboard")
                        .displaySmall(color: AppColors.textPrimary)
                }

                Spacer()

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(AppColors.surfaceTertiary)
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.dominant.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(AppColors.dominant)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Analytics Yet")
                    .headline(color: AppColors.textPrimary)

                Text("Complete your first workout to unlock progression insights.")
                    .subheadline(color: AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxl)
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Consistency")
                .headline(color: AppColors.textPrimary)

            HStack(spacing: AppSpacing.md) {
                analyticsStat(
                    label: "Current Streak",
                    value: "\(viewModel.currentStreak) days",
                    icon: "flame.fill",
                    color: AppColors.warning
                )

                analyticsStat(
                    label: "This Week",
                    value: "\(viewModel.workoutsThisWeek) workouts",
                    icon: "calendar",
                    color: AppColors.dominant
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var volumeTrendCard: some View {
        let points = viewModel.weeklyVolumeTrend
        let current = points.last?.totalVolume ?? 0
        let previous = points.dropLast().last?.totalVolume ?? 0
        let delta = current - previous

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly Volume Trend")
                    .headline(color: AppColors.textPrimary)
                Spacer()
                Text(formatVolume(current))
                    .monoSmall(color: AppColors.dominant)
                    .fontWeight(.semibold)
                Text("lbs")
                    .caption(color: AppColors.textTertiary)
            }

            if points.allSatisfy({ $0.totalVolume == 0 }) {
                Text("No logged strength volume in the last \(points.count) weeks.")
                    .caption(color: AppColors.textTertiary)
            } else {
                VolumeTrendBars(points: points)
                    .frame(height: 96)

                HStack {
                    Text("vs last week")
                        .caption(color: AppColors.textTertiary)
                    Spacer()
                    Text(delta == 0 ? "No change" : "\(delta > 0 ? "+" : "")\(formatVolume(abs(delta))) lbs")
                        .caption(color: delta >= 0 ? AppColors.success : AppColors.warning)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var liftTrendsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Most Trained Lifts")
                .headline(color: AppColors.textPrimary)

            if viewModel.liftTrends.isEmpty {
                Text("Log more strength sets to unlock lift trends.")
                    .caption(color: AppColors.textTertiary)
            } else {
                ForEach(viewModel.liftTrends) { trend in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: icon(for: trend.direction))
                            .foregroundColor(color(for: trend.direction))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(trend.exerciseName)
                                .subheadline(color: AppColors.textPrimary)
                                .fontWeight(.semibold)
                            Text("\(trend.sessionCount) logged sessions")
                                .caption(color: AppColors.textTertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(trend.latestTopSet.formatted)
                                .monoSmall(color: AppColors.textPrimary)
                            if let deltaWeight = trend.deltaWeight {
                                let deltaText = deltaWeight == 0 ? "No change" : "\(deltaWeight > 0 ? "+" : "")\(formatWeight(deltaWeight)) lbs"
                                Text(deltaText)
                                    .caption(color: color(for: trend.direction))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var progressionBreakdownCard: some View {
        let breakdown = viewModel.progressionBreakdown

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Progression Decisions (28d)")
                .headline(color: AppColors.textPrimary)

            if breakdown.total == 0 {
                Text("No progression decisions logged yet.")
                    .caption(color: AppColors.textTertiary)
            } else {
                ProgressionBreakdownRow(
                    label: "Progress",
                    count: breakdown.progressCount,
                    percentage: breakdown.percentage(for: .progress),
                    color: AppColors.success
                )
                ProgressionBreakdownRow(
                    label: "Stay",
                    count: breakdown.stayCount,
                    percentage: breakdown.percentage(for: .stay),
                    color: AppColors.dominant
                )
                ProgressionBreakdownRow(
                    label: "Regress",
                    count: breakdown.regressCount,
                    percentage: breakdown.percentage(for: .regress),
                    color: AppColors.warning
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var recentPRsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent PRs")
                .headline(color: AppColors.textPrimary)

            if viewModel.recentPRs.isEmpty {
                Text("No personal records detected yet.")
                    .caption(color: AppColors.textTertiary)
            } else {
                ForEach(viewModel.recentPRs.prefix(3)) { pr in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(AppColors.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .subheadline(color: AppColors.textPrimary)
                                .fontWeight(.semibold)
                            Text(pr.summary)
                                .caption(color: AppColors.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatMonthDay(pr.date))
                                .caption(color: AppColors.textTertiary)
                            Text("+\(formatWeight(pr.improvement))")
                                .caption(color: AppColors.success)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func analyticsStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .caption(color: color)
                Text(label)
                    .caption(color: AppColors.textSecondary)
            }
            Text(value)
                .subheadline(color: AppColors.textPrimary)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfaceSecondary)
        )
    }

    private func icon(for direction: TrendDirection) -> String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.left.and.right"
        }
    }

    private func color(for direction: TrendDirection) -> Color {
        switch direction {
        case .up: return AppColors.success
        case .down: return AppColors.warning
        case .flat: return AppColors.textTertiary
        }
    }
}

private struct VolumeTrendBars: View {
    let points: [WeeklyVolumePoint]

    private var maxVolume: Double {
        max(points.map(\.totalVolume).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                VStack(spacing: 4) {
                    Capsule()
                        .fill(point.totalVolume > 0 ? AppColors.dominant : AppColors.surfaceTertiary)
                        .frame(width: 10, height: barHeight(for: point))

                    if index == 0 || index == points.count - 1 {
                        Text(formatMonthDay(point.weekStart))
                            .caption2(color: AppColors.textTertiary)
                    } else {
                        Color.clear
                            .frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for point: WeeklyVolumePoint) -> CGFloat {
        let normalized = point.totalVolume / maxVolume
        return max(8, CGFloat(normalized * 72))
    }
}

private struct ProgressionBreakdownRow: View {
    let label: String
    let count: Int
    let percentage: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .caption(color: AppColors.textSecondary)
                Spacer()
                Text("\(count) (\(percentage)%)")
                    .caption(color: AppColors.textPrimary)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceTertiary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (CGFloat(percentage) / 100.0))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(SessionViewModel())
}

// MARK: - Analytics Models

struct WeeklyVolumePoint: Identifiable, Hashable {
    let weekStart: Date
    let totalVolume: Double
    let sessionCount: Int

    var id: Date { weekStart }
}

struct StrengthTopSet: Hashable {
    let weight: Double
    let reps: Int

    var estimatedOneRepMax: Double {
        weight * (1 + (Double(reps) / 30.0))
    }

    var formatted: String {
        "\(formatWeight(weight)) x \(reps)"
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

enum PersonalRecordType {
    case topWeight
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
        switch type {
        case .topWeight:
            return "Top set \(topSet.formatted) (\(formatWeight(newBest)) lbs PR)"
        case .estimatedOneRepMax:
            return "Top set \(topSet.formatted) (~\(formatWeight(newBest)) 1RM PR)"
        }
    }
}

// MARK: - Analytics Service

struct AnalyticsService {
    private let calendar = Calendar.current

    func currentStreak(from sessions: [Session], referenceDate: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        let workoutDates = Set(sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        guard !workoutDates.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        if !workoutDates.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  workoutDates.contains(yesterday) else {
                return 0
            }
            checkDate = yesterday
        }

        while workoutDates.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    func workoutsThisWeek(from sessions: [Session], referenceDate: Date = Date()) -> Int {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        return sessions.filter { currentWeek.contains($0.date) }.count
    }

    func weeklyVolumeTrend(from sessions: [Session], weeks: Int = 8, referenceDate: Date = Date()) -> [WeeklyVolumePoint] {
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

    func progressionBreakdown(from sessions: [Session], days: Int = 28, referenceDate: Date = Date()) -> ProgressionBreakdown {
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

    func recentPRs(sessions: [Session], limit: Int = 3) -> [PersonalRecordEvent] {
        guard limit > 0 else { return [] }

        struct RunningBest {
            var topWeight: Double
            var estimatedOneRepMax: Double
        }

        var bestByExercise: [String: RunningBest] = [:]
        var events: [PersonalRecordEvent] = []
        let orderedSessions = sessions.sorted { $0.date < $1.date }

        for session in orderedSessions {
            for exercise in strengthExercises(in: session) {
                guard let topSet = topStrengthSet(for: exercise) else { continue }
                let exerciseName = exercise.exerciseName

                guard let best = bestByExercise[exerciseName] else {
                    bestByExercise[exerciseName] = RunningBest(
                        topWeight: topSet.weight,
                        estimatedOneRepMax: topSet.estimatedOneRepMax
                    )
                    continue
                }

                let weightImproved = topSet.weight > best.topWeight + 0.001
                let oneRepMaxImproved = topSet.estimatedOneRepMax > best.estimatedOneRepMax + 0.001

                if weightImproved || oneRepMaxImproved {
                    if weightImproved {
                        events.append(
                            PersonalRecordEvent(
                                exerciseName: exerciseName,
                                date: session.date,
                                type: .topWeight,
                                previousBest: best.topWeight,
                                newBest: topSet.weight,
                                topSet: topSet
                            )
                        )
                    } else {
                        events.append(
                            PersonalRecordEvent(
                                exerciseName: exerciseName,
                                date: session.date,
                                type: .estimatedOneRepMax,
                                previousBest: best.estimatedOneRepMax,
                                newBest: topSet.estimatedOneRepMax,
                                topSet: topSet
                            )
                        )
                    }
                }

                bestByExercise[exerciseName] = RunningBest(
                    topWeight: max(best.topWeight, topSet.weight),
                    estimatedOneRepMax: max(best.estimatedOneRepMax, topSet.estimatedOneRepMax)
                )
            }
        }

        return Array(events.sorted { $0.date > $1.date }.prefix(limit))
    }

    private func strengthExercises(in session: Session) -> [SessionExercise] {
        session.completedModules
            .filter { !$0.skipped }
            .flatMap { $0.completedExercises }
            .filter { $0.exerciseType == .strength }
    }

    private func strengthVolume(for session: Session) -> Double {
        var total: Double = 0

        for exercise in strengthExercises(in: session) {
            for setGroup in exercise.completedSetGroups {
                for set in setGroup.sets where set.completed {
                    guard let weight = set.weight, let reps = set.reps, weight > 0, reps > 0 else { continue }
                    total += weight * Double(reps)
                }
            }
        }

        return total
    }

    private func topStrengthSet(for exercise: SessionExercise) -> StrengthTopSet? {
        let completedSets = exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { $0.completed && ($0.weight ?? 0) > 0 }

        guard let best = completedSets.max(by: { lhs, rhs in
            let lhsWeight = lhs.weight ?? 0
            let rhsWeight = rhs.weight ?? 0
            if lhsWeight == rhsWeight {
                return (lhs.reps ?? 0) < (rhs.reps ?? 0)
            }
            return lhsWeight < rhsWeight
        }), let weight = best.weight else {
            return nil
        }

        return StrengthTopSet(
            weight: weight,
            reps: max(1, best.reps ?? 0)
        )
    }
}

// MARK: - Analytics ViewModel

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var currentStreak = 0
    @Published private(set) var workoutsThisWeek = 0
    @Published private(set) var weeklyVolumeTrend: [WeeklyVolumePoint] = []
    @Published private(set) var liftTrends: [LiftTrend] = []
    @Published private(set) var progressionBreakdown: ProgressionBreakdown = .empty
    @Published private(set) var recentPRs: [PersonalRecordEvent] = []
    @Published private(set) var analyzedSessionCount = 0

    private let analyticsService = AnalyticsService()

    func load(from sessions: [Session]) {
        analyzedSessionCount = sessions.count
        currentStreak = analyticsService.currentStreak(from: sessions)
        workoutsThisWeek = analyticsService.workoutsThisWeek(from: sessions)
        weeklyVolumeTrend = analyticsService.weeklyVolumeTrend(from: sessions, weeks: 10)
        liftTrends = analyticsService.mostTrainedLiftTrends(from: sessions, limit: 3)
        progressionBreakdown = analyticsService.progressionBreakdown(from: sessions, days: 28)
        recentPRs = analyticsService.recentPRs(sessions: sessions, limit: 5)
    }
}
