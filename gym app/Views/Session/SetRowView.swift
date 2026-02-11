//
//  SetRowView.swift
//  gym app
//
//  Main set input row component for active session
//
//  Input field components are split into:
//  - StrengthInputsView.swift - Weight/reps inputs
//  - CardioInputsView.swift - Duration/distance inputs
//  - TimeInputPickers.swift - Time picker sheets
//

import SwiftUI

struct SetRowView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise
    var isHighlighted: Bool = false  // Highlight when rest timer ends
    let onLog: (Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, String?, [String: String]?) -> Void  // weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues
    var onDelete: (() -> Void)? = nil  // Optional delete callback
    var onDistanceUnitChange: ((DistanceUnit) -> Void)? = nil  // Callback to change distance unit
    var onUncheck: (() -> Void)? = nil  // Callback to uncheck/edit a completed set

    // Smart friction reduction: last session data for auto-fill hints
    var lastSessionExercise: SessionExercise? = nil

    // Explicit width to prevent layout expansion issues
    var contentWidth: CGFloat? = nil

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: String = ""
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @State private var inputHeight: String = ""  // For explosive exercises (box jumps)
    @State private var inputIntensity: Int = 0  // 1-10 for isometric exercises
    @State private var inputTemperature: String = ""  // For recovery activities (sauna/cold plunge)
    @State private var inputBandColor: String = ""  // For band exercises (e.g., "Red", "Blue")

    // Multi-measurable inputs (e.g., {"Height": "24", "Weight": "20"})
    @State private var inputMeasurableValues: [String: String] = [:]

    @FocusState private var focusedField: SetRowFieldType?

    // Timer state now managed by SessionViewModel for background persistence
    // Local state only for UI that doesn't need to persist
    @State private var showRPEPicker: Bool = false
    @State private var showTimePicker: Bool = false  // For manual time entry on cardio/mobility
    @State private var showHoldTimePicker: Bool = false  // For manual hold time entry on isometric
    @State private var showDistanceUnitPicker: Bool = false  // For changing distance unit
    @State private var durationManuallySet: Bool = false  // Track if user manually set duration via picker
    @State private var justCompleted: Bool = false  // For completion glow animation

    // Computed properties for timer state from ViewModel
    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    // Fingerprint of target values - used to detect when exercise targets change via edit sheet
    private var targetFingerprint: String {
        "\(flatSet.targetWeight ?? 0)-\(flatSet.targetReps ?? 0)-\(flatSet.targetDuration ?? 0)-\(flatSet.targetHoldTime ?? 0)-\(flatSet.targetDistance ?? 0)-\(exercise.exerciseType.rawValue)-\(exercise.cardioMetric.rawValue)-\(exercise.mobilityTracking.rawValue)"
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Set number indicator
            setNumberBadge
                .fixedSize() // Prevent set number from shrinking

            if flatSet.setData.completed {
                // Completed state - show summary
                completedView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            } else {
                // Input fields based on exercise type
                HStack(spacing: AppSpacing.sm) {
                    // Input fields based on exercise type - compact, no internal spacers
                    inputFieldsView
                        .layoutPriority(-1) // Allow compression if needed

                    Spacer(minLength: 0) // Can compress to 0

                    // Log button (delete via swipe only to reduce clutter)
                    logButton
                        .layoutPriority(2) // Highest priority - always keep visible
                        .fixedSize() // Prevent button from shrinking
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: contentWidth) // Constrain the entire HStack
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(width: contentWidth)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(backgroundColor)
        )
        .completionGlow(isActive: justCompleted, color: AppColors.success)
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(isHighlighted ? AppColors.dominant.opacity(0.20) : .clear, lineWidth: 2)
        )
        .shadow(color: isHighlighted ? AppColors.dominant.opacity(0.06) : .clear, radius: isHighlighted ? 4 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timerRunning)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: flatSet.setData.completed)
        .onAppear { loadDefaults() }
        .onChange(of: targetFingerprint) { _, _ in
            // Reload defaults when targets change (e.g., after editing exercise via EditExerciseSheet)
            // Only reload for incomplete sets to preserve logged data
            if !flatSet.setData.completed {
                loadDefaults()
            }
        }
        .onChange(of: sessionViewModel.isExerciseTimerRunning) { wasRunning, isRunning in
            // When exercise timer stops (countdown complete), update input fields with elapsed time
            if wasRunning && !isRunning && sessionViewModel.exerciseTimerSetId == nil {
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
            // Trigger completion glow when a set is newly completed
            if !wasCompleted && isCompleted {
                justCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    justCompleted = false
                }
            }
            // When unchecking a set (completed -> incomplete), reload logged values
            if wasCompleted && !isCompleted {
                durationManuallySet = false
                loadDefaults()
            }
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                totalSeconds: $inputDuration,
                title: "Enter Time",
                onSave: {
                    durationManuallySet = true
                }
            )
        }
        .sheet(isPresented: $showHoldTimePicker) {
            TimePickerSheet(
                totalSeconds: $inputHoldTime,
                title: "Hold Time"
            )
        }
    }

    // MARK: - Subviews

    private var setNumberBadge: some View {
        ZStack {
            if flatSet.setData.completed {
                AnimatedCheckmark(
                    isChecked: true,
                    size: 32,
                    color: AppColors.success,
                    lineWidth: 2.5
                )
            } else {
                if flatSet.isUnilateral, let side = flatSet.setData.side {
                    VStack(spacing: 2) {
                        Text("\(flatSet.setNumber)")
                            .caption2(color: AppColors.textSecondary)
                            .fontWeight(.bold)
                        Text(side.abbreviation)
                            .caption2(color: side == .left ? AppColors.dominant : AppColors.accent2)
                            .fontWeight(.semibold)
                    }
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppColors.surfaceTertiary)
                    )
                } else {
                    Circle()
                        .fill(AppColors.surfaceTertiary)
                        .frame(width: 32, height: 32)
                    Text("\(flatSet.setNumber)")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var backgroundColor: some ShapeStyle {
        if flatSet.setData.completed {
            return AnyShapeStyle(LinearGradient(
                colors: [AppColors.success.opacity(0.08), AppColors.success.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else if timerRunning {
            return AnyShapeStyle(LinearGradient(
                colors: [AppColors.dominant.opacity(0.15), AppColors.dominant.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else if isHighlighted {
            return AnyShapeStyle(LinearGradient(
                colors: [AppColors.dominant.opacity(0.1), AppColors.dominant.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
        return AnyShapeStyle(AppColors.surfaceTertiary)
    }

    @ViewBuilder
    private var completedView: some View {
        Button {
            onUncheck?()
        } label: {
            HStack {
                Text(completedSummary)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "pencil")
                    .subheadline(color: AppColors.textTertiary)
                    .fontWeight(.medium)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit completed set: \(completedSummary)")
        .accessibilityHint("Tap to modify this set")
        .contextMenu {
            Button {
                onUncheck?()
            } label: {
                Label("Edit Set", systemImage: "pencil")
            }

            if let deleteAction = onDelete {
                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    Label("Delete Set", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var inputFieldsView: some View {
        switch exercise.exerciseType {
        case .strength:
            StrengthInputs(
                flatSet: flatSet,
                exercise: exercise,
                inputWeight: $inputWeight,
                inputReps: $inputReps,
                inputRPE: $inputRPE,
                inputHeight: $inputHeight,
                inputBandColor: $inputBandColor,
                inputMeasurableValues: $inputMeasurableValues,
                focusedField: $focusedField
            )
        case .cardio:
            CardioInputs(
                flatSet: flatSet,
                exercise: exercise,
                inputDuration: $inputDuration,
                inputDistance: $inputDistance,
                durationManuallySet: $durationManuallySet,
                showTimePicker: $showTimePicker,
                showDistanceUnitPicker: $showDistanceUnitPicker,
                focusedField: $focusedField,
                onDistanceUnitChange: onDistanceUnitChange
            )
        case .isometric:
            IsometricInputs(
                flatSet: flatSet,
                exercise: exercise,
                inputHoldTime: $inputHoldTime,
                showHoldTimePicker: $showHoldTimePicker
            )
        case .explosive:
            ExplosiveInputs(
                inputReps: $inputReps,
                inputHeight: $inputHeight,
                focusedField: $focusedField
            )
        case .mobility:
            MobilityInputs(
                flatSet: flatSet,
                exercise: exercise,
                inputReps: $inputReps,
                inputDuration: $inputDuration,
                showTimePicker: $showTimePicker,
                focusedField: $focusedField
            )
        case .recovery:
            RecoveryInputs(
                flatSet: flatSet,
                exercise: exercise,
                inputDuration: $inputDuration,
                inputTemperature: $inputTemperature,
                durationManuallySet: $durationManuallySet,
                showTimePicker: $showTimePicker,
                focusedField: $focusedField
            )
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            focusedField = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            HapticManager.shared.setCompleted()

            let rpeValue = Int(inputRPE)
            let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }

            let durationToSave: Int?
            if exercise.exerciseType == .cardio || exercise.exerciseType == .recovery {
                durationToSave = durationManuallySet && inputDuration > 0 ? inputDuration : nil
            } else {
                durationToSave = inputDuration > 0 ? inputDuration : nil
            }

            let hasStringMeasurable = exercise.implementStringMeasurable != nil
            let weightToSave = hasStringMeasurable ? nil : Double(inputWeight)
            let bandColorToSave = hasStringMeasurable && !inputBandColor.isEmpty ? inputBandColor : nil

            onLog(
                weightToSave,
                Int(inputReps),
                validRPE,
                durationToSave,
                inputHoldTime > 0 ? inputHoldTime : nil,
                Double(inputDistance),
                Double(inputHeight),
                inputIntensity > 0 ? inputIntensity : nil,
                Int(inputTemperature),
                bandColorToSave,
                inputMeasurableValues.isEmpty ? nil : inputMeasurableValues
            )
        } label: {
            Image(systemName: "checkmark")
                .body(color: .white)
                .fontWeight(.bold)
                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                .background(
                    Circle()
                        .fill(AppGradients.dominantGradient)
                )
                .shadow(color: AppColors.dominant.opacity(0.10), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.bouncy)
        .accessibilityLabel("Log set")
        .accessibilityHint("Mark this set as completed")
    }

    // MARK: - Completed Summary

    private var completedSummary: String {
        let set = flatSet.setData
        var sidePrefix = ""

        if flatSet.isUnilateral, let side = set.side {
            sidePrefix = "\(side.abbreviation): "
        }

        let mainSummary: String
        switch exercise.exerciseType {
        case .strength:
            if flatSet.isAMRAP {
                if let reps = set.reps {
                    var result = "\(reps) reps"
                    if let timeLimit = flatSet.amrapTimeLimit {
                        result += " (\(formatDurationVerbose(timeLimit)) AMRAP)"
                    } else {
                        result += " (AMRAP)"
                    }
                    if let weight = set.weight, weight > 0 {
                        if exercise.isBodyweight {
                            result += " @ BW + \(formatWeight(weight))"
                        } else {
                            result += " @ \(formatWeight(weight)) lbs"
                        }
                    } else if exercise.isBodyweight {
                        result += " @ BW"
                    }
                    mainSummary = result
                } else {
                    mainSummary = flatSet.amrapTimeLimit != nil ? "AMRAP (\(formatDurationVerbose(flatSet.amrapTimeLimit!)))" : "AMRAP"
                }
            } else {
                if let stringMeasurable = exercise.implementStringMeasurable {
                    if let reps = set.reps {
                        if let band = set.bandColor, !band.isEmpty {
                            var result = "\(band) \(stringMeasurable.implementName.lowercased()) × \(reps)"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        } else {
                            var result = "\(reps) reps"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        }
                    } else {
                        mainSummary = "Completed"
                    }
                } else if exercise.usesBox {
                    if let reps = set.reps {
                        if let height = set.height, height > 0 {
                            var result = "\(Int(height))in × \(reps)"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        } else {
                            var result = "\(reps) reps"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        }
                    } else {
                        mainSummary = "Completed"
                    }
                } else if exercise.isBodyweight {
                    if let reps = set.reps {
                        if let weight = set.weight, weight > 0 {
                            var result = "BW + \(formatWeight(weight)) × \(reps)"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        } else {
                            var result = "BW × \(reps)"
                            if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                            mainSummary = result
                        }
                    } else {
                        mainSummary = "Completed"
                    }
                } else {
                    mainSummary = set.formattedStrength ?? "Completed"
                }
            }
        case .isometric:
            var parts: [String] = []
            if let holdTime = set.holdTime {
                parts.append(formatDuration(holdTime) + " hold")
            }
            if let intensity = set.intensity {
                parts.append("@ \(intensity)/10")
            }
            mainSummary = parts.isEmpty ? "Completed" : parts.joined(separator: " ")
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)")
            }
            mainSummary = parts.isEmpty ? "Completed" : parts.joined(separator: " / ")
        case .explosive:
            var parts: [String] = []
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if let height = set.height {
                parts.append("@ \(formatHeight(height))")
            }
            mainSummary = parts.isEmpty ? "Completed" : parts.joined(separator: " ")
        case .mobility:
            var parts: [String] = []
            if exercise.mobilityTracking.tracksReps, let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if exercise.mobilityTracking.tracksDuration, let duration = set.duration {
                parts.append(formatDuration(duration))
            }
            mainSummary = parts.isEmpty ? "Completed" : parts.joined(separator: " · ")
        case .recovery:
            if let duration = set.duration {
                var result = formatDuration(duration)
                if let temp = set.temperature {
                    result += " @ \(temp)°F"
                }
                mainSummary = result
            } else {
                mainSummary = "Completed"
            }
        }

        // Append multi-measurable values if present
        var finalSummary = sidePrefix + mainSummary
        if !set.implementMeasurableValues.isEmpty {
            let measurableStrings = flatSet.implementMeasurables.compactMap { measurable -> String? in
                guard let value = set.implementMeasurableValues[measurable.measurableName] else { return nil }
                if let numericValue = value.numericValue {
                    return "\(measurable.measurableName): \(formatMeasurableValue(numericValue)) \(measurable.unit)"
                } else if let stringValue = value.stringValue {
                    return "\(measurable.measurableName): \(stringValue) \(measurable.unit)"
                }
                return nil
            }
            if !measurableStrings.isEmpty {
                finalSummary += " · " + measurableStrings.joined(separator: " · ")
            }
        }
        return finalSummary
    }

    private func formatMeasurableValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Load Defaults

    private func loadDefaults() {
        let setData = flatSet.setData

        let lastSessionSet = lastSessionExercise?.completedSetGroups
            .flatMap { $0.sets }
            .first { $0.completed }

        let lastWeight = lastSessionSet?.weight
        let lastReps = lastSessionSet?.reps
        let lastDuration = lastSessionSet?.duration
        let lastHoldTime = lastSessionSet?.holdTime
        let lastDistance = lastSessionSet?.distance
        let lastHeight = lastSessionSet?.height
        let lastBandColor = lastSessionSet?.bandColor ?? lastSessionSet?.implementMeasurableValues["Color"]?.stringValue

        if setData.weight != nil || setData.reps != nil || setData.duration != nil || setData.holdTime != nil || setData.distance != nil {
            inputWeight = setData.weight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
            inputReps = setData.reps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""
            if !durationManuallySet {
                inputDuration = setData.duration ?? flatSet.targetDuration ?? 0
            }
            inputHoldTime = setData.holdTime ?? flatSet.targetHoldTime ?? 0
            inputDistance = setData.distance.map { formatDistanceValue($0) } ?? flatSet.targetDistance.map { formatDistanceValue($0) } ?? ""
        } else {
            if flatSet.isAMRAP {
                inputWeight = lastWeight.map { formatWeight($0) }
                    ?? flatSet.targetWeight.map { formatWeight($0) }
                    ?? ""
                inputReps = lastReps.map { "\($0)" } ?? ""
            } else {
                if let suggestion = exercise.progressionSuggestion {
                    if suggestion.metric == .weight {
                        let delta = max(suggestion.suggestedValue - suggestion.baseValue, 0)

                        switch exercise.progressionRecommendation {
                        case .progress:
                            inputWeight = formatWeight(suggestion.suggestedValue)
                        case .regress:
                            // Regress by the same step used for progression (fallback to 2.5 lbs).
                            let regressionStep = delta > 0 ? delta : 2.5
                            inputWeight = formatWeight(max(0, suggestion.baseValue - regressionStep))
                        case .stay, nil:
                            inputWeight = formatWeight(suggestion.baseValue)
                        }

                        inputReps = lastReps.map { "\($0)" }
                            ?? flatSet.targetReps.map { "\($0)" }
                            ?? ""
                    } else {
                        inputWeight = lastWeight.map { formatWeight($0) }
                            ?? flatSet.targetWeight.map { formatWeight($0) }
                            ?? ""

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
                        case .stay, nil:
                            prefilledReps = max(1, baseReps)
                        }

                        inputReps = "\(prefilledReps)"
                    }
                } else {
                    inputWeight = lastWeight.map { formatWeight($0) }
                        ?? flatSet.targetWeight.map { formatWeight($0) }
                        ?? ""
                    inputReps = lastReps.map { "\($0)" }
                        ?? flatSet.targetReps.map { "\($0)" }
                        ?? ""
                }
            }
            inputHoldTime = lastHoldTime ?? flatSet.targetHoldTime ?? 0
            if !durationManuallySet {
                inputDuration = lastDuration ?? flatSet.targetDuration ?? 0
            }
            inputDistance = lastDistance.map { formatDistanceValue($0) }
                ?? flatSet.targetDistance.map { formatDistanceValue($0) }
                ?? ""
        }

        inputRPE = setData.rpe.map { "\($0)" } ?? ""
        inputHeight = setData.height.map { formatHeightValue($0) }
            ?? lastHeight.map { formatHeightValue($0) }
            ?? ""
        inputIntensity = setData.intensity ?? 0
        inputTemperature = setData.temperature.map { "\($0)" } ?? ""
        inputBandColor = setData.bandColor
            ?? setData.implementMeasurableValues["Color"]?.stringValue
            ?? lastBandColor
            ?? ""

        inputMeasurableValues = [:]
        for measurable in flatSet.implementMeasurables {
            if let loggedValue = setData.implementMeasurableValues[measurable.measurableName] {
                if let numericValue = loggedValue.numericValue {
                    inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(numericValue)
                } else if let stringValue = loggedValue.stringValue {
                    inputMeasurableValues[measurable.measurableName] = stringValue
                }
            } else if let lastSessionValue = lastSessionSet?.implementMeasurableValues[measurable.measurableName] {
                if let numericValue = lastSessionValue.numericValue {
                    inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(numericValue)
                } else if let stringValue = lastSessionValue.stringValue {
                    inputMeasurableValues[measurable.measurableName] = stringValue
                }
            } else if let targetNumeric = measurable.targetValue {
                inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(targetNumeric)
            } else if let targetString = measurable.targetStringValue {
                inputMeasurableValues[measurable.measurableName] = targetString
            }
        }
    }
}
