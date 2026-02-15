//
//  WorkoutSummaryView.swift
//  gym app
//
//  A classy celebration view for completed workouts
//  Shows stats, highlights, and module breakdown
//

import SwiftUI

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let session: Session
    let elapsedSeconds: Int
    let onReviewAndSave: () -> Void
    let onQuickSave: (Int?, String?) -> Void

    @State private var animateIn = false
    @State private var showShareSheet = false
    @State private var showPostToFeed = false
    @State private var showShareWithFriend = false
    @State private var showHighlightPicker = false
    @State private var selectedShareContent: (any ShareableContent)?

    // Computed stats
    private var totalVolume: Double {
        session.completedModules.filter { !$0.skipped }.reduce(0) { moduleTotal, module in
            moduleTotal + module.completedExercises.reduce(0) { $0 + $1.totalVolume }
        }
    }

    private var formattedDuration: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: session.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Hero Section
                    heroSection

                    // Stats Grid
                    statsGrid

                    // Highlights
                    if !exerciseHighlights.isEmpty {
                        highlightsSection
                    }

                    // Module Breakdown
                    moduleBreakdown

                    // Action Buttons
                    actionButtons
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            onQuickSave(nil, nil)
                            showHighlightPicker = true
                        } label: {
                            Label("Post to Feed", systemImage: "rectangle.stack")
                        }

                        Button {
                            showShareWithFriend = true
                        } label: {
                            Label("Share with Friend", systemImage: "paperplane")
                        }

                        Divider()

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share via...", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .body(color: AppColors.textSecondary)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                WorkoutShareSheet(items: [generateShareText()])
            }
            .sheet(isPresented: $showHighlightPicker) {
                HighlightPickerView(session: session) { highlights in
                    selectedShareContent = ShareableHighlightBundle.aggregate(
                        from: highlights,
                        workoutName: session.workoutName,
                        date: session.date
                    ) ?? session
                    showPostToFeed = true
                }
            }
            .sheet(isPresented: $showPostToFeed) {
                if let content = selectedShareContent {
                    ComposePostSheet(content: content)
                } else {
                    ComposePostSheet(content: session)
                }
            }
            .sheet(isPresented: $showShareWithFriend) {
                ShareWithFriendSheet(content: session)
            }
        }
        .onAppear {
            withAnimation(AppAnimation.entrance) {
                animateIn = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Success indicator
            ZStack {
                Circle()
                    .stroke(AppColors.success.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark")
                    .displaySmall(color: AppColors.success)
            }
            .scaleEffect(animateIn ? 1 : 0.5)
            .opacity(animateIn ? 1 : 0)

            // Workout name
            Text(session.workoutName)
                .font(.title.bold())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Date and duration
            HStack(spacing: AppSpacing.md) {
                Label(formattedDate, systemImage: "calendar")

                Text("·")
                    .foregroundColor(AppColors.textTertiary)

                Label(formattedDuration, systemImage: "clock")
            }
            .subheadline()
        }
        .padding(.top, AppSpacing.lg)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: AppSpacing.md) {
            statCard(
                value: "\(session.totalSetsCompleted)",
                label: "SETS",
                color: AppColors.dominant
            )

            statCard(
                value: "\(session.totalExercisesCompleted)",
                label: "EXERCISES",
                color: AppColors.accent1
            )

            statCard(
                value: formatVolume(totalVolume),
                label: "VOLUME",
                color: AppColors.accent3
            )
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.1), value: animateIn)
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .displayMedium(color: color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .statLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 10000 {
            return String(format: "%.1fk", volume / 1000)
        } else if volume >= 1000 {
            return String(format: "%.0f", volume)
        } else {
            return String(format: "%.0f", volume)
        }
    }

    // MARK: - Highlights Section

    private var exerciseHighlights: [ExerciseHighlight] {
        var highlights: [ExerciseHighlight] = []

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises {
                // Only include strength exercises with meaningful top sets
                guard exercise.exerciseType == .strength,
                      let topSet = exercise.topSet,
                      let weight = topSet.weight, weight > 0,
                      let reps = topSet.reps, reps > 0 else { continue }

                // Get last session data for comparison
                let lastExercise = sessionViewModel.getLastSessionData(
                    for: exercise.exerciseName,
                    workoutId: session.workoutId
                )
                let lastTopSet = lastExercise?.topSet

                var comparison: HighlightComparison? = nil
                if let lastWeight = lastTopSet?.weight, lastWeight > 0 {
                    let weightDiff = weight - lastWeight
                    if abs(weightDiff) >= 2.5 { // Significant change
                        comparison = HighlightComparison(
                            weightDiff: weightDiff,
                            isImprovement: weightDiff > 0
                        )
                    }
                }

                highlights.append(ExerciseHighlight(
                    exerciseName: exercise.exerciseName,
                    topWeight: weight,
                    topReps: reps,
                    comparison: comparison
                ))
            }
        }

        // Sort by weight and take top 3
        return Array(highlights.sorted { $0.topWeight > $1.topWeight }.prefix(3))
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("TOP LIFTS")
                .elegantLabel(color: AppColors.dominant)

            VStack(spacing: AppSpacing.sm) {
                ForEach(exerciseHighlights, id: \.exerciseName) { highlight in
                    highlightRow(highlight)
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.2), value: animateIn)
    }

    private func highlightRow(_ highlight: ExerciseHighlight) -> some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.exerciseName)
                    .headline()
                    .lineLimit(1)

                if let comparison = highlight.comparison {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: comparison.isImprovement ? "arrow.up.right" : "arrow.down.right")
                            .caption2(color: comparison.isImprovement ? AppColors.success : AppColors.textTertiary)
                            .fontWeight(.semibold)
                        Text(formatWeight(abs(comparison.weightDiff)))
                            .caption(color: comparison.isImprovement ? AppColors.success : AppColors.textTertiary)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Top set display
            HStack(spacing: AppSpacing.xs) {
                Text(formatWeight(highlight.topWeight))
                    .font(.title3.weight(.medium)).monospacedDigit()

                Text("×")
                    .foregroundColor(AppColors.textTertiary)

                Text("\(highlight.topReps)")
                    .font(.title3.weight(.medium)).monospacedDigit()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
        )
    }

    // MARK: - Module Breakdown

    private var moduleBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("BREAKDOWN")
                .elegantLabel(color: AppColors.textSecondary)

            VStack(spacing: AppSpacing.sm) {
                ForEach(session.completedModules) { module in
                    moduleRow(module)
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.3), value: animateIn)
    }

    private func moduleRow(_ module: CompletedModule) -> some View {
        let exerciseCount = module.completedExercises.count
        let setCount = module.completedExercises.reduce(0) { total, exercise in
            total + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        }
        let moduleColor = AppColors.moduleColor(module.moduleType)

        return HStack(spacing: AppSpacing.md) {
            // Module icon
            Image(systemName: module.moduleType.icon)
                .subheadline(color: moduleColor)
                .fontWeight(.medium)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.moduleName)
                    .subheadline(color: AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(exerciseCount) exercises · \(setCount) sets")
                    .caption()
            }

            Spacer()

            // Completion indicator
            Image(systemName: "checkmark.circle.fill")
                .body(color: AppColors.success.opacity(0.7))
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(moduleColor.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // Primary: Save
            Button {
                HapticManager.shared.impact()
                onQuickSave(nil, nil)
            } label: {
                Text("Save Workout")
                    .headline(color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppGradients.dominantGradient)
                    )
            }

            // Secondary: Review & Edit
            Button {
                HapticManager.shared.tap()
                onReviewAndSave()
            } label: {
                Text("Review & Edit")
                    .headline()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .stroke(AppColors.surfaceTertiary, lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.top, AppSpacing.md)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.4), value: animateIn)
    }

    // MARK: - Sharing

    private func generateShareText() -> String {
        var text = "\(session.workoutName)\n"
        text += "\(formattedDate) · \(formattedDuration)\n\n"
        text += "\(session.totalSetsCompleted) sets · "
        text += "\(session.totalExercisesCompleted) exercises · "
        text += "\(formatVolume(totalVolume)) lbs\n\n"

        // Add top lifts
        let topLifts = exerciseHighlights.prefix(3)
        if !topLifts.isEmpty {
            text += "Top Lifts:\n"
            for lift in topLifts {
                text += "• \(lift.exerciseName): \(formatWeight(lift.topWeight)) × \(lift.topReps)\n"
            }
        }

        return text
    }
}

// MARK: - Supporting Types

private struct ExerciseHighlight {
    let exerciseName: String
    let topWeight: Double
    let topReps: Int
    let comparison: HighlightComparison?
}

private struct HighlightComparison {
    let weightDiff: Double
    let isImprovement: Bool
}

// MARK: - Share Sheet

private struct WorkoutShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


#Preview {
    WorkoutSummaryView(
        session: Session(
            workoutId: UUID(),
            workoutName: "Push Day",
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Strength",
                    moduleType: .strength,
                    completedExercises: [
                        SessionExercise(
                            exerciseId: UUID(),
                            exerciseName: "Bench Press",
                            exerciseType: .strength,
                            completedSetGroups: [
                                CompletedSetGroup(
                                    setGroupId: UUID(),
                                    sets: [
                                        SetData(setNumber: 1, weight: 185, reps: 8, completed: true),
                                        SetData(setNumber: 2, weight: 185, reps: 7, completed: true),
                                        SetData(setNumber: 3, weight: 185, reps: 6, completed: true)
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        ),
        elapsedSeconds: 3600,
        onReviewAndSave: {},
        onQuickSave: { _, _ in }
    )
    .environmentObject(SessionViewModel())
}
