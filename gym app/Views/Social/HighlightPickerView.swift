//
//  HighlightPickerView.swift
//  gym app
//
//  Allows users to select which exercises/sets to feature when sharing a completed workout
//

import SwiftUI

struct HighlightPickerView: View {
    let session: Session
    let onConfirm: ([any ShareableContent]) -> Void
    @Environment(\.dismiss) private var dismiss

    // Selection state - can select exercises OR individual sets
    @State private var selectedExercises: Set<UUID> = []
    @State private var selectedSets: [UUID: Set<UUID>] = [:] // exerciseId -> set of setIds
    @State private var shareEntireSession = false

    private let maxHighlights = 5

    /// Number of selected highlights
    private var highlightCount: Int {
        let exerciseCount = selectedExercises.count
        let individualSetCount = selectedSets.filter { !selectedExercises.contains($0.key) }.values.reduce(0) { $0 + $1.count }
        return exerciseCount + individualSetCount
    }

    /// What we're sharing - either "1" for full workout or the highlight count
    private var shareCount: Int {
        shareEntireSession ? 1 : highlightCount
    }

    private var nonSkippedModules: [CompletedModule] {
        session.completedModules.filter { !$0.skipped }
    }

    /// Button should be disabled if: sharing full workout with no highlights, OR sharing highlights with none selected
    private var isShareDisabled: Bool {
        if shareEntireSession {
            return highlightCount == 0  // Full workout needs at least 1 highlight
        } else {
            return highlightCount == 0  // Individual share needs at least 1 selection
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Option to share entire session
                    shareEntireSessionCard

                    // Instructions
                    if shareEntireSession {
                        Text("Select up to \(maxHighlights) highlights to feature on your workout card")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Shared highlight selection UI
                    HighlightSelectionCore(
                        session: session,
                        selectedExerciseIds: $selectedExercises,
                        selectedSetIds: $selectedSets,
                        maxHighlights: maxHighlights
                    )
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Select Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(shareEntireSession ? "Share Workout" : "Share (\(shareCount))") {
                        confirmSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(isShareDisabled)
                }
            }
        }
    }

    // MARK: - Share Entire Session Card

    private var shareEntireSessionCard: some View {
        Button {
            withAnimation(AppAnimation.quick) {
                shareEntireSession.toggle()
            }
            HapticManager.shared.tap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(AppColors.success.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.medium))
                        .foregroundColor(AppColors.success)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Share Full Workout Card")
                        .headline(color: AppColors.textPrimary)

                    Text(shareEntireSession ? "Select highlights to feature below" : "Shows stats + your selected highlights")
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: shareEntireSession ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(shareEntireSession ? AppColors.success : AppColors.textTertiary)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(shareEntireSession ? AppColors.success.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func confirmSelection() {
        var content: [any ShareableContent] = []

        if shareEntireSession {
            // Share full workout with selected highlights embedded
            let wrapper = ShareableSessionWithHighlights(
                session: session,
                highlightedExerciseIds: Array(selectedExercises),
                highlightedSetIds: selectedSets.flatMap { Array($0.value) }
            )
            content.append(wrapper)
        } else {
            // Share just the selected items as individual highlights
            for module in nonSkippedModules {
                for exercise in module.completedExercises {
                    if selectedExercises.contains(exercise.id) {
                        // Entire exercise selected
                        let wrapper = ShareableExercisePerformance(
                            exercise: exercise,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                        content.append(wrapper)
                    } else if let setIds = selectedSets[exercise.id], !setIds.isEmpty {
                        // Individual sets selected
                        for setGroup in exercise.completedSetGroups {
                            for set in setGroup.sets where setIds.contains(set.id) {
                                let wrapper = ShareableSetPerformance(
                                    set: set,
                                    exerciseName: exercise.exerciseName,
                                    exerciseType: exercise.exerciseType,
                                    distanceUnit: exercise.distanceUnit,
                                    workoutName: session.workoutName,
                                    date: session.date
                                )
                                content.append(wrapper)
                            }
                        }
                    }
                }
            }
        }

        onConfirm(content)
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    HighlightPickerView(
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
                        ),
                        SessionExercise(
                            exerciseId: UUID(),
                            exerciseName: "Incline Dumbbell Press",
                            exerciseType: .strength,
                            completedSetGroups: [
                                CompletedSetGroup(
                                    setGroupId: UUID(),
                                    sets: [
                                        SetData(setNumber: 1, weight: 60, reps: 10, completed: true),
                                        SetData(setNumber: 2, weight: 60, reps: 9, completed: true)
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    ) { _ in }
}
