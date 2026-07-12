//
//  AnalyticsView.swift
//  gym app
//
//  Analytics and progression insights
//

import SwiftUI

/// Identifies which exercise's drill-down detail sheet is presented, if any.
private struct ExerciseDetailTarget: Identifiable {
    let exerciseName: String
    var id: String { exerciseName }
}

struct AnalyticsView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()
    @StateObject private var bodyWeightViewModel = BodyWeightViewModel()

    @AppStorage("analytics_bodyExpanded") private var bodyExpanded = true
    @AppStorage("analytics_trainingExpanded") private var trainingExpanded = true
    @AppStorage("analytics_strengthExpanded") private var strengthExpanded = true

    @State private var showingShareSummary = false
    @State private var exerciseDetailTarget: ExerciseDetailTarget?

    /// Owned by MainTabView so re-tapping the Analytics tab can pop to root
    /// (by clearing the path) without destroying and rebuilding this subtree.
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    analyticsHeader
                    timeRangePicker

                    // Bodyweight tracking is independent of session history
                    sectionHeader("BODY", isExpanded: $bodyExpanded)
                    if bodyExpanded {
                        BodyWeightCard(
                            viewModel: bodyWeightViewModel,
                            unit: appState.weightUnit,
                            timeRange: viewModel.selectedTimeRange
                        )
                    }

                    if viewModel.analyzedSessionCount == 0 {
                        emptyState
                    } else {
                        // Training Activity
                        sectionHeader("TRAINING ACTIVITY", isExpanded: $trainingExpanded)
                        if trainingExpanded {
                            consistencyCard
                            volumeTrendCard
                            liftTrendsCard
                            recentPRsCard
                        }

                        // Strength Progress
                        sectionHeader("STRENGTH PROGRESS", isExpanded: $strengthExpanded)
                        if strengthExpanded {
                            strengthProgressCard
                        }

                    }
                }
                .padding(AppSpacing.screenPadding)
                .tabBarBottomPadding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingShareSummary) {
                ShareSummaryView(viewModel: viewModel)
            }
            .sheet(item: $exerciseDetailTarget) { target in
                ExerciseDetailView(exerciseName: target.exerciseName, sessions: sessionViewModel.sessions)
            }
            .onAppear {
                viewModel.load(from: sessionViewModel.sessions)
            }
            .onChange(of: sessionViewModel.sessions) { _, sessions in
                viewModel.load(from: sessions)
            }
        }
    }

    private var analyticsHeader: some View {
        HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANALYTICS")
                        .elegantLabel(color: AppColors.dominant)
                    Text("Your progress")
                        .displaySmall()
                }

                Spacer()

                Button { showingShareSummary = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.pressable)

                NavigationLink(destination: HistoryView()) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.pressable)

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.pressable)
        }
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(AnalyticsTimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            viewModel.load(from: sessionViewModel.sessions)
        }
    }

    private func sectionHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(AppAnimation.standard) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .elegantLabel(color: AppColors.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
            }
            .frame(minHeight: AppSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.xyaxis.line",
            title: "No Analytics Yet",
            subtitle: "Complete your first workout to see your training trends."
        )
        .padding(.top, AppSpacing.xl)
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
                Text("No volume data in this time range.")
                    .caption(color: AppColors.textTertiary)
            } else {
                VolumeTrendSwiftChart(points: points)
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
                Text("No lift data yet. Complete strength exercises to see trends.")
                    .caption(color: AppColors.textTertiary)
            } else {
                ForEach(viewModel.liftTrends) { trend in
                    Button {
                        exerciseDetailTarget = ExerciseDetailTarget(exerciseName: trend.exerciseName)
                    } label: {
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

                            Image(systemName: "chevron.right")
                                .caption(color: AppColors.textTertiary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
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
                Text("No e1RM data yet. Log sets in the 1-12 rep range.")
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
                    Text("No qualifying sets for this exercise yet.")
                        .caption(color: AppColors.textTertiary)
                } else {
                    E1RMSwiftChart(points: points)
                        .frame(height: 148)

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

    private var recentPRsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent PRs")
                .headline(color: AppColors.textPrimary)

            if viewModel.recentPRs.isEmpty {
                Text("No PRs detected yet. Keep training!")
                    .caption(color: AppColors.textTertiary)
            } else {
                ForEach(viewModel.recentPRs.prefix(3)) { pr in
                    Button {
                        exerciseDetailTarget = ExerciseDetailTarget(exerciseName: pr.exerciseName)
                    } label: {
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

                            Image(systemName: "chevron.right")
                                .caption(color: AppColors.textTertiary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
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
                .monoSmall(color: AppColors.textPrimary)
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

#Preview {
    AnalyticsView(path: .constant(NavigationPath()))
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
