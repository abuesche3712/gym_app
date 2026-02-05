//
//  HighlightSelectionCore.swift
//  gym app
//
//  Shared component for selecting exercise and set highlights
//  Used by HighlightPickerView and EditPostSheet
//

import SwiftUI

/// Reusable component that displays exercises/sets with selection checkboxes
/// for choosing highlights to feature on workout posts
struct HighlightSelectionCore: View {
    let session: Session
    @Binding var selectedExerciseIds: Set<UUID>
    @Binding var selectedSetIds: [UUID: Set<UUID>]
    let maxHighlights: Int

    @State private var expandedExercises: Set<UUID> = []

    // MARK: - Computed Properties

    /// Number of selected highlights (exercises + individual sets not in selected exercises)
    var highlightCount: Int {
        let exerciseCount = selectedExerciseIds.count
        let individualSetCount = selectedSetIds
            .filter { !selectedExerciseIds.contains($0.key) }
            .values
            .reduce(0) { $0 + $1.count }
        return exerciseCount + individualSetCount
    }

    /// Whether more highlights can be selected
    var canSelectMore: Bool {
        highlightCount < maxHighlights
    }

    private var nonSkippedModules: [CompletedModule] {
        session.completedModules.filter { !$0.skipped }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ForEach(nonSkippedModules) { module in
                moduleSection(module)
            }
        }
    }

    // MARK: - Module Section

    private func moduleSection(_ module: CompletedModule) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: module.moduleType.icon)
                    .font(.caption)
                    .foregroundColor(AppColors.moduleColor(module.moduleType))

                Text(module.moduleName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)

                Spacer()

                Text("\(highlightCount)/\(maxHighlights)")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            // Exercises
            VStack(spacing: 1) {
                ForEach(module.completedExercises) { exercise in
                    exerciseCard(exercise, moduleColor: AppColors.moduleColor(module.moduleType))
                }
            }
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: SessionExercise, moduleColor: Color) -> some View {
        let isExpanded = expandedExercises.contains(exercise.id)
        let isExerciseSelected = selectedExerciseIds.contains(exercise.id)
        let exerciseSetSelections = selectedSetIds[exercise.id] ?? []
        let hasAnySelection = isExerciseSelected || !exerciseSetSelections.isEmpty
        let isDisabled = !canSelectMore && !hasAnySelection

        return VStack(spacing: 0) {
            // Exercise header row
            HStack(spacing: AppSpacing.md) {
                // Exercise type icon
                Image(systemName: exercise.exerciseType.icon)
                    .font(.subheadline)
                    .foregroundColor(isDisabled ? AppColors.textTertiary : moduleColor)
                    .frame(width: 24)

                // Exercise info
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseName)
                        .subheadline(color: isDisabled ? AppColors.textTertiary : AppColors.textPrimary)
                        .fontWeight(.medium)

                    HStack(spacing: AppSpacing.sm) {
                        let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
                        Text("\(completedSets.count) sets")
                            .caption(color: AppColors.textSecondary)

                        if let topSet = exercise.topSet {
                            Text("\u{2022}")
                                .caption(color: AppColors.textTertiary)
                            Text(formatTopSet(topSet, exercise: exercise))
                                .caption(color: moduleColor)
                        }
                    }
                }

                Spacer()

                // Expand/collapse button
                Button {
                    withAnimation(AppAnimation.quick) {
                        if isExpanded {
                            expandedExercises.remove(exercise.id)
                        } else {
                            expandedExercises.insert(exercise.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(AppColors.surfaceTertiary.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)

                // Selection checkbox for entire exercise
                Button {
                    toggleExercise(exercise.id)
                } label: {
                    Image(systemName: isExerciseSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isExerciseSelected ? moduleColor : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled && !isExerciseSelected)
                .opacity(isDisabled && !isExerciseSelected ? 0.5 : 1)
            }
            .padding(AppSpacing.cardPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap anywhere on the row to expand/collapse
                withAnimation(AppAnimation.quick) {
                    if isExpanded {
                        expandedExercises.remove(exercise.id)
                    } else {
                        expandedExercises.insert(exercise.id)
                    }
                }
            }

            // Expanded set details
            if isExpanded {
                Divider()
                    .background(AppColors.surfaceTertiary.opacity(0.3))

                VStack(spacing: 0) {
                    ForEach(exercise.completedSetGroups) { setGroup in
                        ForEach(setGroup.sets.filter { $0.completed }) { set in
                            setRow(
                                set: set,
                                exercise: exercise,
                                moduleColor: moduleColor,
                                isExerciseSelected: isExerciseSelected
                            )

                            if set.id != setGroup.sets.filter({ $0.completed }).last?.id ||
                               setGroup.id != exercise.completedSetGroups.last?.id {
                                Divider()
                                    .background(AppColors.surfaceTertiary.opacity(0.2))
                                    .padding(.leading, AppSpacing.xl + AppSpacing.lg)
                            }
                        }
                    }
                }
            }
        }
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Set Row

    private func setRow(set: SetData, exercise: SessionExercise, moduleColor: Color, isExerciseSelected: Bool) -> some View {
        let exerciseSetSelections = selectedSetIds[exercise.id] ?? []
        let isSetSelected = exerciseSetSelections.contains(set.id)
        // Disable if exercise is selected (all sets included) or can't select more
        let isDisabled = isExerciseSelected || (!canSelectMore && !isSetSelected)

        return HStack(spacing: AppSpacing.md) {
            // Set number badge
            Text("\(set.setNumber)")
                .caption2(color: moduleColor)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(moduleColor.opacity(0.15))
                )

            // Side indicator (for unilateral)
            if let side = set.side {
                Text(side == .left ? "L" : "R")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.semibold)
                    .frame(width: 16)
            }

            // Set data
            Text(formatSetData(set, exercise: exercise))
                .caption(color: isDisabled && !isSetSelected ? AppColors.textTertiary : AppColors.textPrimary)

            Spacer()

            // Selection checkbox
            Button {
                toggleSet(set.id, exerciseId: exercise.id)
            } label: {
                Image(systemName: isSetSelected || isExerciseSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(isSetSelected || isExerciseSelected ? moduleColor : AppColors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled && !isSetSelected)
            .opacity(isDisabled && !isSetSelected ? 0.5 : 1)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.leading, AppSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled || isSetSelected {
                toggleSet(set.id, exerciseId: exercise.id)
            }
        }
    }

    // MARK: - Actions

    private func toggleExercise(_ exerciseId: UUID) {
        withAnimation(AppAnimation.quick) {
            if selectedExerciseIds.contains(exerciseId) {
                selectedExerciseIds.remove(exerciseId)
            } else if canSelectMore {
                selectedExerciseIds.insert(exerciseId)
                // Clear individual set selections for this exercise since we're selecting all
                selectedSetIds[exerciseId] = nil
            }
        }
        HapticManager.shared.tap()
    }

    private func toggleSet(_ setId: UUID, exerciseId: UUID) {
        guard !selectedExerciseIds.contains(exerciseId) else { return }

        withAnimation(AppAnimation.quick) {
            var exerciseSets = selectedSetIds[exerciseId] ?? []
            if exerciseSets.contains(setId) {
                exerciseSets.remove(setId)
                if exerciseSets.isEmpty {
                    selectedSetIds[exerciseId] = nil
                } else {
                    selectedSetIds[exerciseId] = exerciseSets
                }
            } else if canSelectMore {
                exerciseSets.insert(setId)
                selectedSetIds[exerciseId] = exerciseSets
            }
        }
        HapticManager.shared.tap()
    }
}
