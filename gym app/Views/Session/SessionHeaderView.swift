//
//  SessionHeaderView.swift
//  gym app
//
//  Progress header for active session view
//

import SwiftUI

struct SessionProgressHeader: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Binding var showWorkoutOverview: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Thin progress bar at very top
            if let session = sessionViewModel.currentSession {
                let totalSets = session.completedModules.reduce(0) { moduleSum, module in
                    moduleSum + module.completedExercises.reduce(0) { exerciseSum, exercise in
                        exerciseSum + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
                    }
                }
                let completedSets = countCompletedSets()
                let progress = Double(completedSets) / Double(max(totalSets, 1))

                GeometryReader { geo in
                    Rectangle()
                        .fill(AppColors.accent1)
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(height: 3)
                .background(AppColors.surfaceTertiary.opacity(0.3))
            }

            // Compact info row - tappable for overview
            Button {
                showWorkoutOverview = true
                HapticManager.shared.soft()
            } label: {
                ZStack {
                    // Left and right content in an HStack
                    HStack {
                        // Timer - subtle
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .caption(color: AppColors.textTertiary)
                            Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                                .font(.body.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        // Module progress - subtle
                        if let session = sessionViewModel.currentSession {
                            Text("\(sessionViewModel.currentModuleIndex + 1)/\(session.completedModules.count)")
                                .caption(color: AppColors.textTertiary)
                                .fontWeight(.medium)
                        }
                    }

                    // Centered overview hint
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .caption2(color: AppColors.textTertiary)
                        Text("Overview")
                            .caption2(color: AppColors.textTertiary)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.surfaceTertiary)
                    )
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(AppColors.surfacePrimary.opacity(0.5))
    }

    private func countCompletedSets() -> Int {
        guard let session = sessionViewModel.currentSession else { return 0 }
        var count = 0
        for (moduleIndex, module) in session.completedModules.enumerated() {
            for (exerciseIndex, exercise) in module.completedExercises.enumerated() {
                for (setGroupIndex, setGroup) in exercise.completedSetGroups.enumerated() {
                    for (setIndex, set) in setGroup.sets.enumerated() {
                        if moduleIndex < sessionViewModel.currentModuleIndex ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex < sessionViewModel.currentExerciseIndex) ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex == sessionViewModel.currentExerciseIndex && setGroupIndex < sessionViewModel.currentSetGroupIndex) ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex == sessionViewModel.currentExerciseIndex && setGroupIndex == sessionViewModel.currentSetGroupIndex && setIndex < sessionViewModel.currentSetIndex) {
                            count += 1
                        } else if set.completed {
                            count += 1
                        }
                    }
                }
            }
        }
        return count
    }
}

// MARK: - Module Indicator

struct ModuleIndicator: View {
    let module: CompletedModule
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: module.moduleType.icon)
                .caption(color: AppColors.moduleColor(module.moduleType))
                .fontWeight(.medium)

            Text(module.moduleName)
                .subheadline(color: AppColors.textSecondary)
                .fontWeight(.medium)

            Spacer()

            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.moduleColor(module.moduleType).opacity(0.08))
        )
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    let exercise: SessionExercise
    let supersetPosition: Int?
    let supersetTotal: Int?
    let supersetExercises: [SessionExercise]?
    let canGoBack: Bool
    let onEdit: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    var onNotesChange: ((String?) -> Void)? = nil

    @State private var showNotes = false
    @State private var notesText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Superset indicator
            if exercise.isInSuperset,
               let position = supersetPosition,
               let total = supersetTotal {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "link")
                        .caption(color: AppColors.warning)
                    Text("SUPERSET \(position)/\(total)")
                        .caption(color: AppColors.warning)
                        .fontWeight(.semibold)

                    Spacer()

                    // Show next exercise in superset
                    if let supersetExercises = supersetExercises,
                       position < total {
                        Text("Next: \(supersetExercises[position].exerciseName)")
                            .caption(color: AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(AppColors.warning.opacity(0.1))
                )
            }

            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(exercise.exerciseName)
                        .headline(color: AppColors.textPrimary)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: AppSpacing.sm) {
                        Text(exerciseSetsSummary)
                            .subheadline(color: AppColors.textSecondary)

                        // Notes button
                        if onNotesChange != nil {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showNotes.toggle()
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: notesText.isEmpty ? "note.text.badge.plus" : "note.text")
                                        .caption(color: notesText.isEmpty ? AppColors.textTertiary : AppColors.accent1)
                                    if !notesText.isEmpty {
                                        Text("Notes")
                                            .caption2(color: AppColors.accent1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Fixed-width button group to prevent layout shift
                HStack(spacing: AppSpacing.xs) {
                    // Edit button
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .body(color: AppColors.textTertiary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Edit exercise")

                    // Back button (always reserve space)
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .body(color: canGoBack ? AppColors.textTertiary : AppColors.textTertiary.opacity(0.3))
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .disabled(!canGoBack)
                    .accessibilityLabel("Previous exercise")

                    // Skip button (superset-aware)
                    Button {
                        onSkip()
                    } label: {
                        Image(systemName: "forward.fill")
                            .body(color: AppColors.textTertiary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Next exercise")
                }
                .fixedSize()
            }

            // Collapsible notes field
            if showNotes, onNotesChange != nil {
                TextField("Add notes for this exercise...", text: $notesText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.small)
                            .fill(AppColors.surfaceTertiary)
                    )
                    .lineLimit(1...4)
                    .onChange(of: notesText) { _, newValue in
                        onNotesChange?(newValue.isEmpty ? nil : newValue)
                    }
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppGradients.cardGradientElevated)
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppGradients.cardShine)
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.4), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onLongPressGesture {
            onEdit()
        }
        .onAppear {
            notesText = exercise.notes ?? ""
            if !notesText.isEmpty { showNotes = true }
        }
        .onChange(of: exercise.id) { _, _ in
            notesText = exercise.notes ?? ""
            showNotes = !notesText.isEmpty
        }
    }

    private var exerciseSetsSummary: String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedCount = exercise.completedSetGroups.reduce(0) { groupSum, group in
            groupSum + group.sets.filter { $0.completed }.count
        }
        return "\(completedCount)/\(totalSets) sets completed"
    }
}
