//
//  SetListSection.swift
//  gym app
//
//  All sets display section for active session
//

import SwiftUI

// MARK: - All Sets Section

struct AllSetsSection: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var appState: AppState

    let exercise: SessionExercise
    let width: CGFloat
    let highlightNextSet: Bool
    let isLastExercise: Bool
    let onLogSet: (FlatSet, Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, String?, [String: String]?) -> Void
    let onDeleteSet: (FlatSet) -> Void
    let onUncheckSet: (FlatSet) -> Void
    let onAddSet: () -> Void
    let onAdvanceToNextExercise: () -> Void
    let onStartIntervalTimer: (Int) -> Void
    let onDistanceUnitChange: (DistanceUnit) -> Void
    let onProgressionUpdate: (SessionExercise, ProgressionRecommendation) -> Void
    var onHighlightClear: () -> Void = {}

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Check for interval set groups
            ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.element.id) { groupIndex, setGroup in
                if setGroup.isInterval {
                    // Interval set group - show special UI
                    IntervalSetGroupRow(
                        setGroup: setGroup,
                        groupIndex: groupIndex,
                        onStartInterval: { onStartIntervalTimer(groupIndex) }
                    )
                } else {
                    // Regular sets
                    let lastSessionExercise = sessionViewModel.getLastSessionData(for: exercise.exerciseName)
                    let flatSets = flattenedSetsForGroup(exercise: exercise, groupIndex: groupIndex)

                    // Group unilateral sets by set number
                    if setGroup.isUnilateral {
                        let groupedSets = groupUnilateralSets(flatSets)
                        ForEach(groupedSets, id: \.setNumber) { group in
                            UnilateralSetPairView(
                                setNumber: group.setNumber,
                                leftSet: group.leftSet,
                                rightSet: group.rightSet,
                                exercise: exercise,
                                highlightNextSet: highlightNextSet,
                                isFirstIncompleteLeft: group.leftSet.map { isFirstIncompleteSet($0, in: exercise) } ?? false,
                                isFirstIncompleteRight: group.rightSet.map { isFirstIncompleteSet($0, in: exercise) } ?? false,
                                onLog: { flatSet, weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues in
                                    onLogSet(flatSet, weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues)
                                    onHighlightClear()
                                    // Start rest timer after completing right side
                                    if flatSet.setData.side == .right && exercise.exerciseType != .recovery {
                                        let restPeriod = flatSet.restPeriod ?? appState.defaultRestTime
                                        if !allSetsCompleted(exercise) {
                                            sessionViewModel.startRestTimer(seconds: restPeriod)
                                        }
                                    }
                                },
                                onDelete: canDeleteSet(exercise: exercise) ? { flatSet in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        onDeleteSet(flatSet)
                                    }
                                } : nil,
                                onUncheck: { flatSet in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        onUncheckSet(flatSet)
                                    }
                                },
                                lastSessionExercise: lastSessionExercise,
                                contentWidth: width - (AppSpacing.cardPadding * 2)
                            )
                        }
                    } else {
                        // Non-unilateral sets - render individually
                        ForEach(flatSets, id: \.id) { flatSet in
                            let isFirstIncomplete = isFirstIncompleteSet(flatSet, in: exercise)
                            SetRowView(
                                flatSet: flatSet,
                                exercise: exercise,
                                isHighlighted: highlightNextSet && isFirstIncomplete,
                                onLog: { weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues in
                                    onLogSet(flatSet, weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues)
                                    onHighlightClear()
                                    // Start rest timer (skip for recovery activities)
                                    if exercise.exerciseType != .recovery {
                                        let restPeriod = flatSet.restPeriod ?? appState.defaultRestTime
                                        if !allSetsCompleted(exercise) {
                                            sessionViewModel.startRestTimer(seconds: restPeriod)
                                        }
                                    }
                                },
                                onDelete: canDeleteSet(exercise: exercise) ? {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        onDeleteSet(flatSet)
                                    }
                                } : nil,
                                onDistanceUnitChange: exercise.exerciseType == .cardio ? { newUnit in
                                    onDistanceUnitChange(newUnit)
                                } : nil,
                                onUncheck: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        onUncheckSet(flatSet)
                                    }
                                },
                                lastSessionExercise: lastSessionExercise,
                                contentWidth: width - (AppSpacing.cardPadding * 2)
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if canDeleteSet(exercise: exercise) {
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            onDeleteSet(flatSet)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Add Set button
            Button {
                onAddSet()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                    Text("Add Set")
                        .subheadline(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                }
                .frame(width: width - (AppSpacing.cardPadding * 2))
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .stroke(AppColors.surfaceTertiary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
            .buttonStyle(.plain)

            // Progression buttons (show when all sets completed)
            if allSetsCompleted(exercise) && exercise.exerciseType == .strength {
                ProgressionButtonsSection(
                    exercise: exercise,
                    width: width,
                    onProgressionUpdate: onProgressionUpdate
                )
            }

            // Next Exercise button
            Button {
                onAdvanceToNextExercise()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: isLastExercise ? "checkmark.circle.fill" : "arrow.right")
                        .body(color: .white)
                        .fontWeight(.semibold)
                    Text(isLastExercise ? "Complete Workout" : "Next Exercise")
                        .headline(color: .white)
                }
                .frame(width: width - (AppSpacing.cardPadding * 2))
                .padding(.vertical, AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(allSetsCompleted(exercise) ? AppGradients.dominantGradient : LinearGradient(colors: [AppColors.textTertiary], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .frame(width: width)  // Lock width to prevent layout shifts
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
        .clipped()
    }

    // MARK: - Helper Functions

    private func flattenedSetsForGroup(exercise: SessionExercise, groupIndex: Int) -> [FlatSet] {
        guard groupIndex < exercise.completedSetGroups.count else { return [] }
        let setGroup = exercise.completedSetGroups[groupIndex]

        // Calculate running set number by counting sets in previous groups
        var runningSetNumber = 1
        for i in 0..<groupIndex {
            let prevGroup = exercise.completedSetGroups[i]
            // For unilateral exercises, count pairs (2 SetData = 1 logical set)
            if prevGroup.isUnilateral {
                runningSetNumber += prevGroup.sets.count / 2
            } else {
                runningSetNumber += prevGroup.sets.count
            }
        }

        var result: [FlatSet] = []
        for (setIndex, setData) in setGroup.sets.enumerated() {
            result.append(FlatSet(
                id: "\(groupIndex)-\(setIndex)",
                setGroupIndex: groupIndex,
                setIndex: setIndex,
                setNumber: runningSetNumber,
                setData: setData,
                targetWeight: setData.weight,
                targetReps: setData.reps,
                targetDuration: setData.duration,
                targetHoldTime: setData.holdTime,
                targetDistance: setData.distance,
                restPeriod: setGroup.restPeriod,
                isInterval: setGroup.isInterval,
                workDuration: setGroup.workDuration,
                intervalRestDuration: setGroup.intervalRestDuration,
                isAMRAP: setGroup.isAMRAP,
                amrapTimeLimit: setGroup.amrapTimeLimit,
                isUnilateral: setGroup.isUnilateral,
                trackRPE: setGroup.trackRPE,
                implementMeasurables: setGroup.implementMeasurables
            ))

            // For unilateral sets, left and right share the same set number
            // Only increment after completing both sides (right side)
            if setGroup.isUnilateral {
                if setData.side == .right {
                    runningSetNumber += 1
                }
            } else {
                runningSetNumber += 1
            }
        }
        return result
    }

    private func allSetsCompleted(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.allSatisfy { group in
            group.sets.allSatisfy { $0.completed }
        }
    }

    private func isFirstIncompleteSet(_ flatSet: FlatSet, in exercise: SessionExercise) -> Bool {
        // Find the first incomplete set in the exercise
        for setGroup in exercise.completedSetGroups {
            for set in setGroup.sets {
                if !set.completed {
                    // This is the first incomplete set - check if it matches our flatSet
                    return set.id == flatSet.setData.id
                }
            }
        }
        return false
    }

    private func canDeleteSet(exercise: SessionExercise) -> Bool {
        // Can delete if there's more than 1 set total in the exercise
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        return totalSets > 1
    }

    /// Groups unilateral sets by set number (left and right paired together)
    private func groupUnilateralSets(_ flatSets: [FlatSet]) -> [UnilateralSetGroup] {
        var groups: [Int: UnilateralSetGroup] = [:]

        for flatSet in flatSets {
            let setNum = flatSet.setNumber
            if groups[setNum] == nil {
                groups[setNum] = UnilateralSetGroup(setNumber: setNum, leftSet: nil, rightSet: nil)
            }

            if flatSet.setData.side == .left {
                groups[setNum]?.leftSet = flatSet
            } else if flatSet.setData.side == .right {
                groups[setNum]?.rightSet = flatSet
            }
        }

        return groups.values.sorted { $0.setNumber < $1.setNumber }
    }
}

// MARK: - Unilateral Set Group

struct UnilateralSetGroup {
    let setNumber: Int
    var leftSet: FlatSet?
    var rightSet: FlatSet?
}

// MARK: - Unilateral Set Pair View

struct UnilateralSetPairView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let setNumber: Int
    let leftSet: FlatSet?
    let rightSet: FlatSet?
    let exercise: SessionExercise
    let highlightNextSet: Bool
    let isFirstIncompleteLeft: Bool
    let isFirstIncompleteRight: Bool
    let onLog: (FlatSet, Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, String?, [String: String]?) -> Void
    var onDelete: ((FlatSet) -> Void)?
    var onUncheck: ((FlatSet) -> Void)?
    var lastSessionExercise: SessionExercise?
    var contentWidth: CGFloat?

    private var bothCompleted: Bool {
        (leftSet?.setData.completed ?? true) && (rightSet?.setData.completed ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Set number header
            HStack {
                ZStack {
                    if bothCompleted {
                        AnimatedCheckmark(
                            isChecked: true,
                            size: 28,
                            color: AppColors.success,
                            lineWidth: 2.5
                        )
                    } else {
                        Circle()
                            .fill(AppColors.surfaceTertiary)
                            .frame(width: 28, height: 28)
                        Text("\(setNumber)")
                            .caption(color: AppColors.textSecondary)
                            .fontWeight(.bold)
                    }
                }

                Text("Set \(setNumber)")
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            // Left and Right rows nested
            VStack(spacing: AppSpacing.xs) {
                if let left = leftSet {
                    UnilateralSideRow(
                        flatSet: left,
                        side: .left,
                        exercise: exercise,
                        highlightNextSet: highlightNextSet,
                        isFirstIncomplete: isFirstIncompleteLeft,
                        onLog: onLog,
                        onUncheck: onUncheck
                    )
                }
                if let right = rightSet {
                    UnilateralSideRow(
                        flatSet: right,
                        side: .right,
                        exercise: exercise,
                        highlightNextSet: highlightNextSet,
                        isFirstIncomplete: isFirstIncompleteRight,
                        onLog: onLog,
                        onUncheck: onUncheck
                    )
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfaceTertiary)
        )
    }
}

// MARK: - Unilateral Side Row

/// Individual L or R row within a unilateral set pair, with its own input state
struct UnilateralSideRow: View {
    let flatSet: FlatSet
    let side: Side
    let exercise: SessionExercise
    let highlightNextSet: Bool
    let isFirstIncomplete: Bool
    let onLog: (FlatSet, Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, String?, [String: String]?) -> Void
    var onUncheck: ((FlatSet) -> Void)?

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: String = ""

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Side indicator
            Text(side.abbreviation)
                .caption(color: side == .left ? AppColors.dominant : AppColors.accent2)
                .fontWeight(.bold)
                .frame(width: 24)

            if flatSet.setData.completed {
                // Completed state
                Button {
                    onUncheck?(flatSet)
                } label: {
                    HStack {
                        Text(completedSummary)
                            .caption(color: AppColors.textPrimary)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .caption(color: AppColors.success)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Input fields
                inputFields
                    .layoutPriority(-1)

                Spacer(minLength: 0)

                // Log button
                Button {
                    logSet()
                } label: {
                    Image(systemName: "checkmark")
                        .caption(color: .white)
                        .fontWeight(.bold)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppGradients.dominantGradient)
                        )
                }
                .buttonStyle(.bouncy)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(flatSet.setData.completed
                      ? AppColors.success.opacity(0.08)
                      : (highlightNextSet && isFirstIncomplete ? AppColors.dominant.opacity(0.1) : AppColors.surfacePrimary))
        )
        .onAppear { loadDefaults() }
    }

    private func loadDefaults() {
        if let w = flatSet.setData.weight { inputWeight = formatWeight(w) }
        if let r = flatSet.setData.reps { inputReps = "\(r)" }
        if let rpe = flatSet.setData.rpe { inputRPE = "\(rpe)" }
    }

    @ViewBuilder
    private var inputFields: some View {
        HStack(spacing: 4) {
            switch exercise.exerciseType {
            case .strength:
                if !exercise.isBodyweight {
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                    Text("×")
                        .caption(color: AppColors.textTertiary)
                }
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                Text("reps")
                    .caption2(color: AppColors.textTertiary)
            default:
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                Text("reps")
                    .caption2(color: AppColors.textTertiary)
            }

            if flatSet.trackRPE && (exercise.exerciseType == .strength || exercise.exerciseType == .explosive) {
                TextField("-", text: $inputRPE)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 32)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                    .onChange(of: inputRPE) { _, newValue in
                        if let rpe = Int(newValue), rpe > 10 { inputRPE = "10" }
                    }
                Text("RPE")
                    .caption2(color: AppColors.textTertiary)
            }
        }
    }

    private var completedSummary: String {
        let set = flatSet.setData
        var summary: String
        switch exercise.exerciseType {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                summary = exercise.isBodyweight ? "BW+\(formatWeight(weight)) × \(reps)" : "\(formatWeight(weight)) × \(reps)"
            } else if let reps = set.reps {
                summary = exercise.isBodyweight ? "BW × \(reps)" : "\(reps) reps"
            } else {
                summary = "Done"
            }
        default:
            if let reps = set.reps {
                summary = "\(reps) reps"
            } else {
                summary = "Done"
            }
        }
        if let rpe = set.rpe {
            summary += " @ RPE \(rpe)"
        }
        return summary
    }

    private func logSet() {
        let weight = Double(inputWeight)
        let reps = Int(inputReps)
        let rpeValue = Int(inputRPE)
        let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }
        onLog(flatSet, weight, reps, validRPE, nil, nil, nil, nil, nil, nil, nil, nil)
    }
}

// MARK: - Compact Text Field

struct CompactTextField: View {
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var width: CGFloat = 44

    @State private var text: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
    }
}

// MARK: - Interval Set Group Row

struct IntervalSetGroupRow: View {
    let setGroup: CompletedSetGroup
    let groupIndex: Int
    let onStartInterval: () -> Void

    private var allCompleted: Bool {
        setGroup.sets.allSatisfy { $0.completed }
    }

    private var completedCount: Int {
        setGroup.sets.filter { $0.completed }.count
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .body(color: AppColors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interval")
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.semibold)

                    Text("\(setGroup.rounds) rounds: \(formatDuration(setGroup.workDuration ?? 30)) on / \(formatDuration(setGroup.intervalRestDuration ?? 30)) off")
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()

                if allCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .displaySmall(color: AppColors.success)
                } else if completedCount > 0 {
                    Text("\(completedCount)/\(setGroup.rounds)")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
            }

            // Start button or completion summary
            if allCompleted {
                // Show completed rounds summary
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(setGroup.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Round \(index + 1)")
                                .caption(color: AppColors.textTertiary)

                            Spacer()

                            if let duration = set.duration {
                                Text(formatDuration(duration))
                                    .caption(color: AppColors.textSecondary)
                                    .fontWeight(.medium)
                            }

                            Image(systemName: "checkmark")
                                .caption2(color: AppColors.success)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(AppColors.success.opacity(0.05))
                )
            } else {
                // Start interval button
                Button {
                    onStartInterval()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.fill")
                            .subheadline(color: .white)
                        Text("Start Interval")
                            .subheadline(color: .white)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(LinearGradient(
                                colors: [AppColors.warning, AppColors.warning.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(allCompleted ? AppColors.success.opacity(0.3) : AppColors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Progression Buttons Section

struct ProgressionButtonsSection: View {
    let exercise: SessionExercise
    let width: CGFloat
    let onProgressionUpdate: (SessionExercise, ProgressionRecommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Next session:")
                .caption(color: AppColors.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(ProgressionRecommendation.allCases) { recommendation in
                    progressionButton(recommendation)
                }
            }
            .frame(width: width - (AppSpacing.cardPadding * 2))
        }
        .padding(.top, AppSpacing.sm)
    }

    private func progressionButton(_ recommendation: ProgressionRecommendation) -> some View {
        let isSelected = exercise.progressionRecommendation == recommendation
        let color = recommendation.color

        return Button {
            onProgressionUpdate(exercise, recommendation)
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: recommendation.icon)
                    .caption(color: isSelected ? .white : color)
                Text(recommendation.displayName)
                    .caption(color: isSelected ? .white : color)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
