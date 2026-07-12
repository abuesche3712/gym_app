//
//  ExerciseDetailView.swift
//  gym app
//
//  Analytics drill-down: e1RM/volume history and recent sessions/PRs for a single
//  exercise. Presented from tapping a lift-trend row or a recent-PR row.
//

import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let sessions: [Session]

    private let analyticsService = AnalyticsService()

    private var e1RMPoints: [E1RMProgressPoint] {
        analyticsService.e1RMProgress(for: exerciseName, sessions: sessions)
    }

    private var history: [ExerciseSessionSummary] {
        analyticsService.exerciseSessionHistory(for: exerciseName, sessions: sessions)
    }

    private var recentHistory: [ExerciseSessionSummary] {
        Array(history.prefix(20))
    }

    private var currentE1RM: Double? {
        e1RMPoints.last?.estimatedOneRepMax
    }

    private var bestE1RM: Double? {
        e1RMPoints.map(\.estimatedOneRepMax).max()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    statsRow
                    chartSection
                    historySection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: AppSpacing.md) {
            stat(
                label: "Current e1RM",
                value: currentE1RM.map { "\(formatWeight($0)) lbs" } ?? "--",
                icon: "figure.strengthtraining.traditional",
                color: AppColors.dominant
            )
            stat(
                label: "Best e1RM",
                value: bestE1RM.map { "\(formatWeight($0)) lbs" } ?? "--",
                icon: "trophy.fill",
                color: AppColors.warning
            )
            stat(
                label: "Sessions",
                value: "\(history.count)",
                icon: "calendar",
                color: AppColors.accent3
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("e1RM Progress")
                .headline(color: AppColors.textPrimary)

            if e1RMPoints.isEmpty {
                Text("No qualifying sets (1-12 reps) yet for this exercise.")
                    .caption(color: AppColors.textTertiary)
            } else {
                E1RMSwiftChart(points: e1RMPoints)
                    .frame(height: 180)
            }
        }
        .analyticsCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent Sessions")
                .headline(color: AppColors.textPrimary)

            if recentHistory.isEmpty {
                Text("No logged sets yet.")
                    .caption(color: AppColors.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentHistory.enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                        if index < recentHistory.count - 1 {
                            Divider()
                                .background(AppColors.surfaceTertiary.opacity(0.5))
                        }
                    }
                }
            }
        }
        .analyticsCard()
    }

    private func historyRow(_ entry: ExerciseSessionSummary) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: entry.isPR ? "trophy.fill" : "circle.fill")
                .font(entry.isPR ? .body : .system(size: 5))
                .foregroundColor(entry.isPR ? AppColors.warning : AppColors.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.topSet.formatted)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.semibold)
                Text(formatMonthDay(entry.date))
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatWeight(entry.topSet.estimatedOneRepMax)) e1RM")
                    .caption(color: AppColors.textSecondary)
                if entry.isPR {
                    Text("PR")
                        .caption2(color: AppColors.warning)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(label: String, value: String, icon: String, color: Color) -> some View {
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
}
