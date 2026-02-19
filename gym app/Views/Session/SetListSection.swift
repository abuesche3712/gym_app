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
                                    // Start rest timer only after completing the RIGHT side (not left)
                                    if exercise.exerciseType != .recovery {
                                        let fullRest = flatSet.restPeriod ?? appState.defaultRestTime
                                        if !allSetsCompleted(exercise) {
                                            if flatSet.setData.side == .right || flatSet.setData.side == nil {
                                                sessionViewModel.startRestTimer(seconds: fullRest)
                                            }
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
                            .contextMenu {
                                if canDeleteSet(exercise: exercise) {
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            onDeleteSet(flatSet)
                                        }
                                    } label: {
                                        Label("Delete Set", systemImage: "trash")
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
            if allSetsCompleted(exercise) &&
                (exercise.exerciseType == .strength || exercise.exerciseType == .cardio) {
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
                id: "\(exercise.exerciseId.uuidString)-\(setData.id.uuidString)",
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
        // Can delete if there's more than 1 logical set in the exercise.
        // Unilateral groups store two SetData rows (L/R) per logical set.
        let totalLogicalSets = exercise.completedSetGroups.reduce(0) { partialResult, group in
            partialResult + (group.isUnilateral ? ((group.sets.count + 1) / 2) : group.sets.count)
        }
        return totalLogicalSets > 1
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
                        onUncheck: onUncheck,
                        lastSessionExercise: lastSessionExercise
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
                        onUncheck: onUncheck,
                        lastSessionExercise: lastSessionExercise
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
        .contextMenu {
            if let onDelete = onDelete, let leftSet = leftSet {
                Button(role: .destructive) {
                    onDelete(leftSet)
                } label: {
                    Label("Delete Set \(setNumber)", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Unilateral Side Row

/// Individual L or R row within a unilateral set pair, with its own input state
struct UnilateralSideRow: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let side: Side
    let exercise: SessionExercise
    let highlightNextSet: Bool
    let isFirstIncomplete: Bool
    let onLog: (FlatSet, Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, String?, [String: String]?) -> Void
    var onUncheck: ((FlatSet) -> Void)?
    var lastSessionExercise: SessionExercise? = nil

    // Shared input state
    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: String = ""

    // Type-specific input state
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @State private var inputHeight: String = ""
    @State private var inputTemperature: String = ""
    @State private var inputBandColor: String = ""
    @State private var inputMeasurableValues: [String: String] = [:]
    @State private var showTimePicker: Bool = false
    @State private var durationManuallySet: Bool = false

    /// Unique timer ID for this row
    private var timerSetId: String { flatSet.id }

    /// Whether this row's exercise timer is running
    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == timerSetId
    }

    private var targetFingerprint: String {
        "\(flatSet.targetWeight ?? 0)-\(flatSet.targetReps ?? 0)-\(flatSet.targetDuration ?? 0)-\(flatSet.targetHoldTime ?? 0)-\(flatSet.targetDistance ?? 0)-\(exercise.exerciseType.rawValue)-\(exercise.cardioMetric.rawValue)-\(exercise.mobilityTracking.rawValue)"
    }

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
                        Image(systemName: "pencil")
                            .caption2(color: AppColors.textTertiary)
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
        .onChange(of: targetFingerprint) { _, _ in
            if !flatSet.setData.completed {
                loadDefaults()
            }
        }
        .onChange(of: timerRunning) { wasRunning, isRunning in
            // Capture elapsed only when this row's timer transitions from running to stopped.
            if wasRunning && !isRunning {
                let elapsed = sessionViewModel.exerciseTimerElapsed
                if exercise.exerciseType == .isometric && elapsed > 0 {
                    inputHoldTime = elapsed
                } else if elapsed > 0 {
                    inputDuration = elapsed
                    durationManuallySet = true
                }
            }
        }
        .onChange(of: flatSet.setData.completed) { wasCompleted, isCompleted in
            if wasCompleted && !isCompleted {
                durationManuallySet = false
                loadDefaults()
            }
        }
        .onChange(of: flatSet.id) { _, _ in
            durationManuallySet = false
            loadDefaults()
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(totalSeconds: $inputDuration, title: "Enter Time", onSave: {
                durationManuallySet = true
            })
        }
    }

    private func loadDefaults() {
        let setData = flatSet.setData
        let hasLoggedValues = setData.weight != nil || setData.reps != nil || setData.duration != nil || setData.holdTime != nil || setData.distance != nil

        // Extract last session data matching this side
        let lastSessionSet = lastSessionExercise?.completedSetGroups
            .flatMap { $0.sets }
            .first { $0.completed && $0.side == side }
        let lastWeight = lastSessionSet?.weight
        let lastReps = lastSessionSet?.reps
        let lastDuration = lastSessionSet?.duration
        let lastHoldTime = lastSessionSet?.holdTime
        let lastDistance = lastSessionSet?.distance
        let lastBandColor = lastSessionSet?.bandColor

        inputWeight = ""
        inputReps = ""
        inputRPE = ""
        if !durationManuallySet {
            inputDuration = 0
        }
        inputHoldTime = 0
        inputDistance = ""
        inputHeight = ""
        inputTemperature = ""
        inputBandColor = ""
        inputMeasurableValues = [:]

        if hasLoggedValues {
            inputWeight = setData.weight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
            inputReps = setData.reps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""
            if !durationManuallySet {
                inputDuration = setData.duration ?? flatSet.targetDuration ?? 0
            }
            inputHoldTime = setData.holdTime ?? flatSet.targetHoldTime ?? 0
            inputDistance = setData.distance.map { formatDistanceValue($0) } ?? flatSet.targetDistance.map { formatDistanceValue($0) } ?? ""
            inputBandColor = setData.bandColor ?? lastBandColor ?? ""
        } else if let suggestion = exercise.progressionSuggestion {
            switch suggestion.metric {
            case .weight:
                let delta = max(suggestion.suggestedValue - suggestion.baseValue, 0)
                let regressionStep = delta > 0 ? delta : 2.5
                switch exercise.progressionRecommendation {
                case .progress:
                    inputWeight = formatWeight(suggestion.suggestedValue)
                case .regress:
                    inputWeight = formatWeight(max(0, suggestion.baseValue - regressionStep))
                case .stay:
                    inputWeight = formatWeight(suggestion.baseValue)
                case nil:
                    inputWeight = formatWeight(suggestion.baseValue)
                }
                inputReps = lastReps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""

            case .reps:
                let baseReps = Int(round(suggestion.baseValue))
                let progressedReps = Int(round(suggestion.suggestedValue))
                let repDelta = max(progressedReps - baseReps, 0)
                let regressedReps = max(1, baseReps - max(repDelta, 1))

                let prefilledReps: Int
                switch exercise.progressionRecommendation {
                case .progress:
                    prefilledReps = max(1, progressedReps)
                case .regress:
                    prefilledReps = regressedReps
                case .stay:
                    prefilledReps = max(1, baseReps)
                case nil:
                    prefilledReps = max(1, baseReps)
                }

                inputWeight = lastWeight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
                inputReps = "\(prefilledReps)"

            case .duration:
                let baseDuration = Int(round(suggestion.baseValue))
                let progressedDuration = Int(round(suggestion.suggestedValue))
                let durationDelta = max(progressedDuration - baseDuration, 1)
                let regressedDuration = max(1, baseDuration - durationDelta)

                let prefilledDuration: Int
                switch exercise.progressionRecommendation {
                case .progress:
                    prefilledDuration = progressedDuration
                case .regress:
                    prefilledDuration = regressedDuration
                case .stay:
                    prefilledDuration = baseDuration
                case nil:
                    prefilledDuration = baseDuration
                }

                if !durationManuallySet {
                    inputDuration = max(1, prefilledDuration)
                }
                inputDistance = lastDistance.map { formatDistanceValue($0) } ?? flatSet.targetDistance.map { formatDistanceValue($0) } ?? ""

            case .distance:
                let baseDistance = suggestion.baseValue
                let progressedDistance = suggestion.suggestedValue
                let distanceDelta = max(progressedDistance - baseDistance, 0.01)
                let regressedDistance = max(0, baseDistance - distanceDelta)

                let prefilledDistance: Double
                switch exercise.progressionRecommendation {
                case .progress:
                    prefilledDistance = progressedDistance
                case .regress:
                    prefilledDistance = regressedDistance
                case .stay:
                    prefilledDistance = baseDistance
                case nil:
                    prefilledDistance = baseDistance
                }

                inputDistance = formatDistanceValue(prefilledDistance)
            }
        } else {
            // No progression suggestion - use lastSession data as fallback, then targets
            inputWeight = lastWeight.map { formatWeight($0) }
                ?? flatSet.targetWeight.map { formatWeight($0) }
                ?? ""
            inputReps = lastReps.map { "\($0)" }
                ?? flatSet.targetReps.map { "\($0)" }
                ?? ""
            if !durationManuallySet {
                inputDuration = lastDuration ?? flatSet.targetDuration ?? 0
            }
            inputHoldTime = lastHoldTime ?? flatSet.targetHoldTime ?? 0
            inputDistance = lastDistance.map { formatDistanceValue($0) }
                ?? flatSet.targetDistance.map { formatDistanceValue($0) }
                ?? ""
            inputBandColor = lastBandColor ?? ""
        }

        if !hasLoggedValues && exercise.progressionSuggestion != nil {
            if inputReps.isEmpty {
                inputReps = lastReps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""
            }
            if inputWeight.isEmpty {
                inputWeight = lastWeight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
            }
            if !durationManuallySet && inputDuration == 0 {
                inputDuration = lastDuration ?? flatSet.targetDuration ?? 0
            }
            if inputDistance.isEmpty {
                inputDistance = lastDistance.map { formatDistanceValue($0) } ?? flatSet.targetDistance.map { formatDistanceValue($0) } ?? ""
            }
            if inputHoldTime == 0 {
                inputHoldTime = lastHoldTime ?? flatSet.targetHoldTime ?? 0
            }
            if inputBandColor.isEmpty {
                inputBandColor = lastBandColor ?? ""
            }
        }

        if let rpe = setData.rpe { inputRPE = "\(rpe)" }
        if let ht = setData.height { inputHeight = formatHeight(ht) }
        if let temp = setData.temperature { inputTemperature = "\(temp)" }
        if inputBandColor.isEmpty {
            inputBandColor = setData.bandColor ?? lastBandColor ?? ""
        }

        for measurable in flatSet.implementMeasurables {
            let storageKey = measurableStorageKey(for: measurable)
            if let loggedValue = measurableValue(for: measurable, in: setData.implementMeasurableValues) {
                if let numericValue = loggedValue.numericValue {
                    inputMeasurableValues[storageKey] = formatMeasurableValue(numericValue)
                } else if let stringValue = loggedValue.stringValue {
                    inputMeasurableValues[storageKey] = stringValue
                }
            } else if let lastValue = measurableValue(for: measurable, in: lastSessionSet?.implementMeasurableValues ?? [:]) {
                if let numericValue = lastValue.numericValue {
                    inputMeasurableValues[storageKey] = formatMeasurableValue(numericValue)
                } else if let stringValue = lastValue.stringValue {
                    inputMeasurableValues[storageKey] = stringValue
                }
            } else if let targetNumeric = measurable.targetValue {
                inputMeasurableValues[storageKey] = formatMeasurableValue(targetNumeric)
            } else if let targetString = measurable.targetStringValue {
                inputMeasurableValues[storageKey] = targetString
            }
        }
    }

    private func formatMeasurableValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func measurableStorageKey(for measurable: ImplementMeasurableTarget) -> String {
        "\(measurable.implementId.uuidString)|\(measurable.measurableName)"
    }

    private func measurableValue(
        for measurable: ImplementMeasurableTarget,
        in values: [String: MeasurableValue]
    ) -> MeasurableValue? {
        if let currentValue = values[measurableStorageKey(for: measurable)] {
            return currentValue
        }
        return values[measurable.measurableName]
    }

    private func toggleTimer() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
            durationManuallySet = true
        } else {
            if exercise.exerciseType == .isometric {
                let target = max(inputHoldTime, flatSet.targetHoldTime ?? 30)
                sessionViewModel.startExerciseTimer(seconds: target, setId: timerSetId)
            } else if exercise.exerciseType == .cardio || (exercise.exerciseType == .mobility && exercise.mobilityTracking.tracksDuration) {
                let target = flatSet.targetDuration ?? 0
                if target > 0 {
                    sessionViewModel.startExerciseTimer(seconds: target, setId: timerSetId)
                } else {
                    sessionViewModel.startExerciseStopwatch(setId: timerSetId)
                }
            } else {
                sessionViewModel.startExerciseStopwatch(setId: timerSetId)
            }
        }
    }

    @ViewBuilder
    private var inputFields: some View {
        HStack(spacing: 6) {
            switch exercise.exerciseType {
            case .strength:
                if !exercise.isBodyweight {
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
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
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                Text("reps")
                    .caption2(color: AppColors.textTertiary)

            case .cardio:
                // Duration control
                if exercise.cardioMetric.tracksTime {
                    HStack(spacing: 6) {
                        Button {
                            if !timerRunning {
                                showTimePicker = true
                            }
                        } label: {
                            Text(timerRunning ? formatDuration(sessionViewModel.exerciseTimerSeconds) : (inputDuration > 0 ? formatDuration(inputDuration) : "0:00"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(timerRunning ? AppColors.warning : AppColors.textPrimary)
                                .frame(minWidth: 48)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleTimer()
                        } label: {
                            Image(systemName: timerRunning ? "stop.fill" : ((flatSet.targetDuration ?? 0) > 0 ? "play.fill" : "stopwatch"))
                                .caption(color: timerRunning ? AppColors.warning : AppColors.accent1)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.15))
                                )
                        }
                        .buttonStyle(.bouncy)
                    }
                }
                // Distance field
                if exercise.cardioMetric.tracksDistance {
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                    Text(exercise.distanceUnit.abbreviation)
                        .caption2(color: AppColors.textTertiary)
                }

            case .isometric:
                // Hold time button with timer support
                Button {
                    if timerRunning {
                        toggleTimer()
                    } else if inputHoldTime > 0 {
                        // Start countdown from target
                        sessionViewModel.startExerciseTimer(seconds: inputHoldTime, setId: timerSetId)
                    } else {
                        let target = flatSet.targetHoldTime ?? 30
                        sessionViewModel.startExerciseTimer(seconds: target, setId: timerSetId)
                    }
                } label: {
                    Text(timerRunning ? formatDuration(sessionViewModel.exerciseTimerSeconds) : (inputHoldTime > 0 ? "\(inputHoldTime)s" : "0s"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(timerRunning ? AppColors.warning : AppColors.textPrimary)
                        .frame(minWidth: 48)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                }
                .buttonStyle(.plain)
                Text("hold")
                    .caption2(color: AppColors.textTertiary)

            case .explosive:
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
                TextField("0", text: $inputHeight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                Text("in")
                    .caption2(color: AppColors.textTertiary)

            case .mobility:
                if exercise.mobilityTracking.tracksReps {
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
                if exercise.mobilityTracking.tracksDuration {
                    HStack(spacing: 6) {
                        Button {
                            if !timerRunning {
                                showTimePicker = true
                            }
                        } label: {
                            Text(timerRunning ? formatDuration(sessionViewModel.exerciseTimerSeconds) : (inputDuration > 0 ? formatDuration(inputDuration) : "0:00"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(timerRunning ? AppColors.warning : AppColors.textPrimary)
                                .frame(minWidth: 48)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleTimer()
                        } label: {
                            Image(systemName: timerRunning ? "stop.fill" : ((flatSet.targetDuration ?? 0) > 0 ? "play.fill" : "stopwatch"))
                                .caption(color: timerRunning ? AppColors.warning : AppColors.accent1)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.15))
                                )
                        }
                        .buttonStyle(.bouncy)
                    }
                }

            case .recovery:
                // Duration display with inline timer control
                HStack(spacing: 6) {
                    Button {
                        if !timerRunning {
                            showTimePicker = true
                        }
                    } label: {
                        Text(timerRunning ? formatDuration(sessionViewModel.exerciseTimerSeconds) : (inputDuration > 0 ? formatDuration(inputDuration) : "0:00"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(timerRunning ? AppColors.warning : AppColors.textPrimary)
                            .frame(minWidth: 48)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
                    }
                    .buttonStyle(.plain)

                    Button {
                        toggleTimer()
                    } label: {
                        Image(systemName: timerRunning ? "stop.fill" : "stopwatch")
                            .caption(color: timerRunning ? AppColors.warning : AppColors.accent1)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.15))
                            )
                    }
                    .buttonStyle(.bouncy)
                }
                // Temperature field
                TextField("°F", text: $inputTemperature)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.surfacePrimary))
            }

            if flatSet.trackRPE && (exercise.exerciseType == .strength || exercise.exerciseType == .explosive) {
                TextField("-", text: $inputRPE)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
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
            if let band = set.bandColor, !band.isEmpty, let reps = set.reps {
                summary = "\(band) × \(reps)"
            } else if let weight = set.weight, let reps = set.reps {
                summary = exercise.isBodyweight ? "BW+\(formatWeight(weight)) × \(reps)" : "\(formatWeight(weight)) × \(reps)"
            } else if let reps = set.reps {
                summary = exercise.isBodyweight ? "BW × \(reps)" : "\(reps) reps"
            } else {
                summary = "Done"
            }
        case .isometric:
            if let holdTime = set.holdTime {
                summary = formatDuration(holdTime) + " hold"
            } else {
                summary = "Done"
            }
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 { parts.append(formatDuration(duration)) }
            if let distance = set.distance, distance > 0 { parts.append("\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)") }
            summary = parts.isEmpty ? "Done" : parts.joined(separator: " / ")
        case .explosive:
            var parts: [String] = []
            if let reps = set.reps { parts.append("\(reps) reps") }
            if let height = set.height { parts.append("@ \(formatHeight(height))") }
            summary = parts.isEmpty ? "Done" : parts.joined(separator: " ")
        case .mobility:
            var parts: [String] = []
            if exercise.mobilityTracking.tracksReps, let reps = set.reps { parts.append("\(reps) reps") }
            if exercise.mobilityTracking.tracksDuration, let duration = set.duration { parts.append(formatDuration(duration)) }
            summary = parts.isEmpty ? "Done" : parts.joined(separator: " · ")
        case .recovery:
            if let duration = set.duration {
                var result = formatDuration(duration)
                if let temp = set.temperature { result += " @ \(temp)°F" }
                summary = result
            } else {
                summary = "Done"
            }
        }
        // Append implement measurable values
        if !set.implementMeasurableValues.isEmpty {
            let measurableStrings = set.implementMeasurableValues.compactMap { (key, value) -> String? in
                if let numericValue = value.numericValue {
                    let formatted = numericValue.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(numericValue))" : String(format: "%.1f", numericValue)
                    return "\(key): \(formatted)"
                } else if let stringValue = value.stringValue {
                    return "\(key): \(stringValue)"
                }
                return nil
            }
            if !measurableStrings.isEmpty {
                summary += " · " + measurableStrings.joined(separator: " · ")
            }
        }
        if let rpe = set.rpe {
            return summary + " @ RPE \(rpe)"
        }
        return summary
    }

    private func logSet() {
        let weight = Double(inputWeight)
        let reps = Int(inputReps)
        let rpeValue = Int(inputRPE)
        let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }

        // Stop timer if running for this set
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            if exercise.exerciseType == .isometric {
                inputHoldTime = elapsed
            } else {
                inputDuration = elapsed
                durationManuallySet = true
            }
        }

        let durationToSave: Int?
        if exercise.exerciseType == .cardio || exercise.exerciseType == .recovery {
            durationToSave = durationManuallySet && inputDuration > 0 ? inputDuration : nil
        } else {
            durationToSave = inputDuration > 0 ? inputDuration : nil
        }

        onLog(
            flatSet,
            weight,
            reps,
            validRPE,
            durationToSave,
            inputHoldTime > 0 ? inputHoldTime : nil,
            Double(inputDistance),
            Double(inputHeight),
            nil, // intensity
            Int(inputTemperature),
            inputBandColor.isEmpty ? nil : inputBandColor,
            inputMeasurableValues.isEmpty ? nil : inputMeasurableValues
        )
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

            if let suggestion = exercise.progressionSuggestion {
                HStack(spacing: AppSpacing.sm) {
                    Text(suggestionSummaryText(for: suggestion))
                        .caption2(color: AppColors.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    if let rationale = compactRationaleText(for: suggestion) {
                        Text(rationale)
                            .caption2(color: AppColors.textTertiary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
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

    private func suggestionSummaryText(for suggestion: ProgressionSuggestion) -> String {
        if let confidenceLabel = suggestion.confidenceLabel {
            return "Engine: \(suggestion.formattedSuggestion) · \(confidenceLabel) confidence"
        }
        if let confidenceText = suggestion.confidenceText {
            return "Engine: \(suggestion.formattedSuggestion) · \(confidenceText)"
        }
        return "Engine: \(suggestion.formattedSuggestion)"
    }

    private func compactRationaleText(for suggestion: ProgressionSuggestion) -> String? {
        guard let rationale = suggestion.rationale?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rationale.isEmpty else {
            return nil
        }
        return rationale.replacingOccurrences(of: "\n", with: " ")
    }
}
