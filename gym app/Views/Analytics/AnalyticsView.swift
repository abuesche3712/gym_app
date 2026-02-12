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
                        strengthProgressCard
                        progressionBreakdownCard
                        engineHealthCard
                        progressionAlertsCard
                        dryRunSimulatorCard
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

    private var strengthProgressCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Strength e1RM Progress")
                    .headline(color: AppColors.textPrimary)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.dominant)
            }

            if viewModel.strengthExerciseOptions.isEmpty {
                Text("Log strength sets with 1-12 reps to view e1RM progression.")
                    .caption(color: AppColors.textTertiary)
            } else {
                Picker("Exercise", selection: $viewModel.selectedStrengthExercise) {
                    ForEach(viewModel.strengthExerciseOptions, id: \.self) { exerciseName in
                        Text(exerciseName).tag(exerciseName)
                    }
                }
                .pickerStyle(.menu)

                let points = viewModel.selectedE1RMPoints
                if points.isEmpty {
                    Text("No qualifying sets yet for this exercise.")
                        .caption(color: AppColors.textTertiary)
                } else {
                    E1RMTrendChart(points: points)
                        .frame(height: 148)

                    HStack {
                        if let first = points.first, let last = points.last {
                            Text(formatMonthDay(first.date))
                                .caption(color: AppColors.textTertiary)
                            Spacer()
                            Text(formatMonthDay(last.date))
                                .caption(color: AppColors.textTertiary)
                        }
                    }

                    HStack(spacing: AppSpacing.md) {
                        analyticsStat(
                            label: "Current e1RM",
                            value: viewModel.selectedCurrentE1RM.map { "\(formatWeight($0)) lbs" } ?? "--",
                            icon: "figure.strengthtraining.traditional",
                            color: AppColors.dominant
                        )
                        analyticsStat(
                            label: "Best e1RM",
                            value: viewModel.selectedBestE1RM.map { "\(formatWeight($0)) lbs" } ?? "--",
                            icon: "trophy.fill",
                            color: AppColors.warning
                        )
                    }

                    if let delta = viewModel.selectedE1RMDelta {
                        Text(delta == 0 ? "No net change in visible range" : "\(delta > 0 ? "+" : "")\(formatWeight(delta)) lbs vs first point")
                            .caption(color: delta >= 0 ? AppColors.success : AppColors.warning)
                            .fontWeight(.semibold)
                    }
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
                            Text(pr.summary)
                                .subheadline(color: AppColors.textPrimary)
                                .fontWeight(.semibold)
                            Text("Estimated 1RM: \(formatWeight(pr.newBest)) lbs")
                                .caption(color: AppColors.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatMonthDay(pr.date))
                                .caption(color: AppColors.textTertiary)
                            Text("+\(formatWeight(pr.improvement)) e1RM")
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

    private var engineHealthCard: some View {
        let health = viewModel.engineHealth

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Engine Health")
                .headline(color: AppColors.textPrimary)

            if health.totalDecisions == 0 {
                Text("No engine decisions captured yet.")
                    .caption(color: AppColors.textTertiary)
            } else {
                HStack(spacing: AppSpacing.md) {
                    analyticsStat(
                        label: "Acceptance",
                        value: "\(health.acceptanceRate)% (\(health.acceptedCount)/\(health.totalDecisions))",
                        icon: "checkmark.circle.fill",
                        color: AppColors.success
                    )

                    analyticsStat(
                        label: "Overrides",
                        value: "\(health.overrideRate)% (\(health.overriddenCount))",
                        icon: "hand.point.up.left.fill",
                        color: AppColors.warning
                    )
                }

                HStack(spacing: AppSpacing.md) {
                    analyticsStat(
                        label: "Regress Rate",
                        value: "\(health.regressRate)% (\(health.regressCount))",
                        icon: "arrow.down.circle.fill",
                        color: AppColors.warning
                    )

                    analyticsStat(
                        label: "Profiles Tracked",
                        value: "\(viewModel.decisionProfileHealth.count)",
                        icon: "slider.horizontal.3",
                        color: AppColors.dominant
                    )
                }

                if !viewModel.decisionProfileHealth.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Decision Paths")
                            .caption(color: AppColors.textSecondary)
                        ForEach(viewModel.decisionProfileHealth.prefix(3)) { profile in
                            HStack {
                                Text(profile.name)
                                    .caption(color: AppColors.textPrimary)
                                Spacer()
                                Text("\(profile.acceptanceRate)% accept")
                                    .caption(color: AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 4)
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

    private var progressionAlertsCard: some View {
        let alerts = viewModel.progressionAlerts

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Safety Alerts")
                .headline(color: AppColors.textPrimary)

            if alerts.isEmpty {
                Text("No high-risk progression patterns detected.")
                    .caption(color: AppColors.textTertiary)
            } else {
                ForEach(alerts.prefix(4)) { alert in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: alert.icon)
                            .foregroundColor(alert.color)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .subheadline(color: AppColors.textPrimary)
                                .fontWeight(.semibold)
                            Text(alert.message)
                                .caption(color: AppColors.textSecondary)
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

    private var dryRunSimulatorCard: some View {
        let runs = viewModel.dryRunProfiles

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Dry-Run Simulator")
                .headline(color: AppColors.textPrimary)

            if runs.isEmpty {
                Text("Need more suggestion history to simulate alternate profiles.")
                    .caption(color: AppColors.textTertiary)
            } else {
                Text("How the last \(viewModel.dryRunInputCount) suggestions would route:")
                    .caption(color: AppColors.textSecondary)

                ForEach(runs) { run in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(run.name)
                                .subheadline(color: AppColors.textPrimary)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Match \(run.agreementRate)%")
                                .caption(color: AppColors.textSecondary)
                        }

                        HStack(spacing: 10) {
                            dryRunPill(label: "P", value: run.progressCount, color: AppColors.success)
                            dryRunPill(label: "S", value: run.stayCount, color: AppColors.dominant)
                            dryRunPill(label: "R", value: run.regressCount, color: AppColors.warning)
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

    @ViewBuilder
    private func dryRunPill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .caption(color: color)
                .fontWeight(.bold)
            Text("\(value)")
                .caption(color: AppColors.textPrimary)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
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

private struct E1RMTrendChart: View {
    let points: [E1RMProgressPoint]

    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 10

    private var minValue: Double {
        points.map(\.estimatedOneRepMax).min() ?? 0
    }

    private var maxValue: Double {
        points.map(\.estimatedOneRepMax).max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let chartPoints = normalizedPoints(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceSecondary)

                if chartPoints.count >= 2 {
                    Path { path in
                        path.move(to: chartPoints[0])
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(AppColors.dominant, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let position = chartPoints[index]
                    Circle()
                        .fill(index == points.count - 1 ? AppColors.warning : AppColors.dominant)
                        .frame(width: index == points.count - 1 ? 8 : 6, height: index == points.count - 1 ? 8 : 6)
                        .position(position)
                        .accessibilityLabel("\(formatMonthDay(point.date)), estimated 1RM \(formatWeight(point.estimatedOneRepMax)) pounds")
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let plotWidth = max(1, size.width - (horizontalPadding * 2))
        let plotHeight = max(1, size.height - (verticalPadding * 2))
        let range = max(maxValue - minValue, 1)

        return points.enumerated().map { index, point in
            let x: CGFloat
            if points.count == 1 {
                x = size.width / 2
            } else {
                x = horizontalPadding + (CGFloat(index) / CGFloat(points.count - 1)) * plotWidth
            }

            let normalizedY = (point.estimatedOneRepMax - minValue) / range
            let y = size.height - verticalPadding - (CGFloat(normalizedY) * plotHeight)

            return CGPoint(x: x, y: y)
        }
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

private let e1RMMinReps = 1
private let e1RMMaxReps = 12

private func brzyckiEstimatedOneRepMax(weight: Double, reps: Int) -> Double? {
    guard weight > 0, (e1RMMinReps...e1RMMaxReps).contains(reps) else { return nil }
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

// MARK: - Analytics Service

struct AnalyticsService {
    private let calendar = Calendar.current
    private let oneRepMaxPRTolerance = 0.1

    private struct ProgressionDecisionRecord {
        let date: Date
        let exerciseName: String
        let decisionPath: String
        let expected: ProgressionRecommendation
        let actual: ProgressionRecommendation?
        let confidence: Double
    }

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

    func engineHealth(from sessions: [Session], days: Int = 28, referenceDate: Date = Date()) -> ProgressionEngineHealth {
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

    func decisionProfileHealth(from sessions: [Session], days: Int = 28, referenceDate: Date = Date()) -> [DecisionProfileHealth] {
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

    func progressionAlerts(from sessions: [Session], days: Int = 28, referenceDate: Date = Date()) -> [ProgressionAlert] {
        let records = progressionDecisionRecords(
            from: sessions,
            days: days,
            referenceDate: referenceDate
        ).filter { $0.actual != nil }

        let byExercise = Dictionary(grouping: records, by: \.exerciseName)
        var alerts: [ProgressionAlert] = []

        for (exerciseName, entries) in byExercise {
            guard entries.count >= 4 else { continue }

            let accepted = entries.filter { $0.actual == $0.expected }.count
            let acceptanceRate = Double(accepted) / Double(entries.count)
            let regressCount = entries.filter { $0.actual == .regress }.count
            let regressRate = Double(regressCount) / Double(entries.count)
            let overrideRate = 1 - acceptanceRate

            if acceptanceRate < 0.45 {
                alerts.append(
                    ProgressionAlert(
                        title: "\(exerciseName): Low acceptance",
                        message: "Only \(Int((acceptanceRate * 100).rounded()))% of suggestions are accepted (\(entries.count) decisions). Consider a more conservative profile.",
                        type: .lowAcceptance
                    )
                )
            }

            if regressRate > 0.40 {
                alerts.append(
                    ProgressionAlert(
                        title: "\(exerciseName): High regressions",
                        message: "Regress selected \(Int((regressRate * 100).rounded()))% of the time. Tighten progression caps or raise readiness gates.",
                        type: .highRegress
                    )
                )
            }

            if overrideRate > 0.60 {
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
        recentSessionLimit: Int = 12
    ) -> (results: [DryRunProfileResult], inputCount: Int) {
        let orderedSessions = sessions.sorted { $0.date > $1.date }
        let sessionSlice = Array(orderedSessions.prefix(max(1, recentSessionLimit)))

        let records = progressionDecisionRecords(
            from: sessionSlice,
            days: 0,
            referenceDate: Date()
        )

        let runConfigs: [(name: String, threshold: Double)] = [
            ("Conservative", 0.78),
            ("Balanced", 0.58),
            ("Aggressive", 0.42)
        ]

        let results = runConfigs.map { config in
            var progress = 0
            var stay = 0
            var regress = 0
            var agreement = 0
            var comparable = 0

            for record in records {
                let predicted = predictedOutcome(
                    for: record,
                    confidenceThreshold: config.threshold
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

                if topSet.estimatedOneRepMax > bestEstimatedOneRepMax + oneRepMaxPRTolerance {
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

    private func topBrzyckiSet(for exercise: SessionExercise) -> StrengthTopSet? {
        let candidateSets = exercise.completedSetGroups
            .flatMap { $0.sets }
            .filter { set in
                guard set.completed,
                      let weight = set.weight,
                      let reps = set.reps,
                      weight > 0 else { return false }
                return (e1RMMinReps...e1RMMaxReps).contains(reps)
            }

        var best: StrengthTopSet?

        for set in candidateSets {
            guard let weight = set.weight, let reps = set.reps else { continue }
            let candidate = StrengthTopSet(weight: weight, reps: reps)
            if let currentBest = best {
                if isBetter(candidate, than: currentBest) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        return best
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

// MARK: - Analytics ViewModel

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

    private let analyticsService = AnalyticsService()

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

    func load(from sessions: [Session]) {
        analyzedSessionCount = sessions.count
        currentStreak = analyticsService.currentStreak(from: sessions)
        workoutsThisWeek = analyticsService.workoutsThisWeek(from: sessions)
        weeklyVolumeTrend = analyticsService.weeklyVolumeTrend(from: sessions, weeks: 10)
        liftTrends = analyticsService.mostTrainedLiftTrends(from: sessions, limit: 3)
        let exerciseProgress = analyticsService.strengthE1RMProgressByExercise(from: sessions)
        strengthExerciseOptions = exerciseProgress.map(\.exerciseName)
        e1RMProgressByExercise = Dictionary(uniqueKeysWithValues: exerciseProgress.map { ($0.exerciseName, $0.points) })
        if !strengthExerciseOptions.contains(selectedStrengthExercise) {
            selectedStrengthExercise = strengthExerciseOptions.first ?? ""
        }
        progressionBreakdown = analyticsService.progressionBreakdown(from: sessions, days: 28)
        engineHealth = analyticsService.engineHealth(from: sessions, days: 28)
        decisionProfileHealth = analyticsService.decisionProfileHealth(from: sessions, days: 28)
        progressionAlerts = analyticsService.progressionAlerts(from: sessions, days: 28)
        let dryRun = analyticsService.dryRunProfiles(from: sessions, recentSessionLimit: 12)
        dryRunProfiles = dryRun.results
        dryRunInputCount = dryRun.inputCount
        recentPRs = analyticsService.recentPRs(sessions: sessions, limit: 5)
    }
}
