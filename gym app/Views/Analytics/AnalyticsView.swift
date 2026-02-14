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
        .analyticsCard()
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
        .analyticsCard()
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
        .analyticsCard()
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
                Text("Log strength sets with \(AnalyticsConfig.e1RMRepRange.lowerBound)-\(AnalyticsConfig.e1RMRepRange.upperBound) reps to view e1RM progression.")
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
        .analyticsCard()
    }

    private var progressionBreakdownCard: some View {
        let breakdown = viewModel.progressionBreakdown

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Progression Decisions (\(AnalyticsConfig.defaultBreakdownWindowDays)d)")
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
        .analyticsCard()
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
        .analyticsCard()
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
        .analyticsCard()
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
        .analyticsCard()
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
        .analyticsCard()
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

#Preview {
    AnalyticsView()
        .environmentObject(SessionViewModel())
}
