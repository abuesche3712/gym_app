//
//  SessionComponents.swift
//  gym app
//
//  Reusable UI components for session views
//

import SwiftUI

// MARK: - Set Indicator

struct SetIndicator: View {
    let setNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    var restTime: Int = 90

    var body: some View {
        ZStack {
            if isCompleted {
                // Use animated checkmark for completed sets
                AnimatedCheckmark(
                    isChecked: true,
                    size: 40,
                    color: AppColors.success,
                    lineWidth: 3
                )
            } else {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)

                Text("\(setNumber)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(isCurrent ? AppColors.dominant : AppColors.textTertiary)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent && !isCompleted ? AppColors.dominant : .clear, lineWidth: 2)
        )
        .animation(AppAnimation.quick, value: isCompleted)
        .animation(AppAnimation.quick, value: isCurrent)
    }

    private var backgroundColor: Color {
        if isCurrent {
            return AppColors.dominant.opacity(0.15)
        } else {
            return AppColors.surfaceTertiary
        }
    }
}

// MARK: - Set Row View (Inline Inputs)

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
    // Smart friction reduction: previous completed set in current session for "same as last"
    var previousCompletedSet: SetData? = nil

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

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case weight, reps, distance, height, rpe, temperature, bandColor
    }

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

    private var timerSecondsRemaining: Int {
        timerRunning && !sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var stopwatchSeconds: Int {
        timerRunning && sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var hasTimedTarget: Bool {
        (exercise.exerciseType == .cardio && exercise.tracksTime && flatSet.targetDuration != nil) ||
        (exercise.exerciseType == .isometric && flatSet.targetHoldTime != nil)
    }

    private var targetTimerSeconds: Int {
        if exercise.exerciseType == .isometric {
            return flatSet.targetHoldTime ?? 0
        }
        return flatSet.targetDuration ?? 0
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

                    // Same as last set button (friction reduction)
                    if previousCompletedSet != nil {
                        sameAsLastButton
                            .layoutPriority(1) // Keep visible
                            .fixedSize() // Prevent button from shrinking
                    }

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
        .onChange(of: sessionViewModel.isExerciseTimerRunning) { wasRunning, isRunning in
            // When exercise timer stops (countdown complete), update input fields
            if wasRunning && !isRunning && sessionViewModel.exerciseTimerSetId == nil {
                // Timer completed or was stopped - sync the elapsed time
                // Note: The ViewModel already calculated the result when stopping
                // We just need to check if this was our timer by checking if values changed
                if exercise.exerciseType == .isometric && sessionViewModel.exerciseTimerTotal > 0 {
                    inputHoldTime = sessionViewModel.exerciseTimerTotal
                } else if sessionViewModel.exerciseTimerTotal > 0 {
                    inputDuration = sessionViewModel.exerciseTimerTotal
                    durationManuallySet = true
                }
            }
        }
        .onChange(of: flatSet.setData.completed) { wasCompleted, isCompleted in
            // Trigger completion glow when a set is newly completed
            if !wasCompleted && isCompleted {
                justCompleted = true
                // Reset the flag after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    justCompleted = false
                }
            }
            // When unchecking a set (completed -> incomplete), reload logged values
            if wasCompleted && !isCompleted {
                durationManuallySet = false  // Reset so we can load the logged duration
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
                // Use animated checkmark for completed sets
                AnimatedCheckmark(
                    isChecked: true,
                    size: 32,
                    color: AppColors.success,
                    lineWidth: 2.5
                )
            } else {
                if flatSet.isUnilateral, let side = flatSet.setData.side {
                    // Unilateral set - show L/R indicator
                    VStack(spacing: 2) {
                        Text("\(flatSet.setNumber)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(side.abbreviation)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(side == .left ? AppColors.dominant : AppColors.accent2)
                    }
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppColors.surfaceTertiary)
                    )
                } else {
                    // Normal bilateral set
                    Circle()
                        .fill(AppColors.surfaceTertiary)
                        .frame(width: 32, height: 32)
                    Text("\(flatSet.setNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppColors.textSecondary)
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
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit completed set: \(completedSummary)")
        .accessibilityHint("Tap to modify this set")
    }

    @ViewBuilder
    private var inputFieldsView: some View {
        switch exercise.exerciseType {
        case .strength:
            strengthInputs
        case .cardio:
            cardioInputs
        case .isometric:
            isometricInputs
        case .explosive:
            explosiveInputs
        case .mobility:
            mobilityInputs
        case .recovery:
            recoveryInputs
        }
    }

    // MARK: - Multi-Measurable Input Field

    @ViewBuilder
    private func measurableInputField(measurable: ImplementMeasurableTarget) -> some View {
        VStack(spacing: 4) {
            TextField(measurable.isStringBased ? measurable.measurableName : "0", text: Binding(
                get: { inputMeasurableValues[measurable.measurableName] ?? "" },
                set: { inputMeasurableValues[measurable.measurableName] = $0 }
            ))
            .keyboardType(measurable.isStringBased ? .default : .decimalPad)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: measurable.isStringBased ? 60 : 48)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))

            Text(measurable.unit)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Strength Inputs

    private var strengthInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // AMRAP indicator/timer
            if flatSet.isAMRAP {
                if let timeLimit = flatSet.amrapTimeLimit {
                    // Timed AMRAP - show countdown button
                    amrapTimerButton(timeLimit: timeLimit)
                } else {
                    // Untimed AMRAP - show badge
                    VStack(spacing: 4) {
                        Image(systemName: "infinity")
                            .font(.body.weight(.bold))
                            .foregroundColor(AppColors.accent2)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.accent2.opacity(0.12))
                            )

                        Text("AMRAP")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.accent2)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }

            // Primary inputs: implement measurable × reps OR weight × reps
            if let stringMeasurable = exercise.implementStringMeasurable {
                // String-based implement input (e.g., band color)
                VStack(spacing: 4) {
                    TextField(stringMeasurable.measurableName, text: $inputBandColor)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .bandColor)

                    Text(stringMeasurable.implementName.lowercased())
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if exercise.usesBox {
                // Box height input
                VStack(spacing: 4) {
                    TextField("0", text: $inputHeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .height)

                    Text("in")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if exercise.isBodyweight {
                // Bodyweight with optional added weight
                HStack(spacing: 2) {
                    Text("BW+")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.dominant)

                    VStack(spacing: 4) {
                        TextField("0", text: $inputWeight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                            .focused($focusedField, equals: .weight)

                        Text("lbs")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                // Standard weight input
                VStack(spacing: 4) {
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .weight)

                    Text("lbs")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Text("×")
                .font(.callout.weight(.medium))
                .foregroundColor(AppColors.textTertiary)

            // Reps input box
            VStack(spacing: 4) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    .focused($focusedField, equals: .reps)

                Text(flatSet.isAMRAP ? "AMRAP" : "reps")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(flatSet.isAMRAP ? AppColors.accent2 : AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)

            // Multi-measurable inputs (up to 2 additional attributes like Height, Incline, etc.)
            ForEach(flatSet.implementMeasurables.prefix(2)) { measurable in
                measurableInputField(measurable: measurable)
            }

            // Secondary input: RPE (not shown for AMRAP to reduce clutter, or if tracking disabled)
            if !flatSet.isAMRAP && flatSet.trackRPE {
                VStack(spacing: 4) {
                    TextField("-", text: $inputRPE)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .rpe)
                        .onChange(of: inputRPE) { _, newValue in
                            // Validate RPE is 1-10
                            if let rpe = Int(newValue), rpe > 10 {
                                inputRPE = "10"
                            }
                        }

                    Text("RPE")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // MARK: - Cardio Inputs
    // Always show both time and distance inputs - user can log either or both

    private var cardioInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Time input box
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    if let targetDuration = flatSet.targetDuration, targetDuration > 0 {
                        // Has time target - show countdown timer
                        Button {
                            showTimePicker = true
                        } label: {
                            Text(timerRunning ? formatDuration(timerSecondsRemaining) : formatDuration(inputDuration))
                                .monoMedium(color: timerRunning ? (timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.dominant) : (inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary))
                                .multilineTextAlignment(.center)
                                .frame(width: 56, alignment: .center)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleTimer()
                        } label: {
                            Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(timerRunning ? AppColors.warning : AppColors.dominant)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.dominant.opacity(0.12)))
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel(timerRunning ? "Stop timer" : "Start timer")
                    } else {
                        // No time target (distance-based) - show stopwatch
                        Button {
                            showTimePicker = true
                        } label: {
                            Text(timerRunning ? formatDuration(stopwatchSeconds) : formatDuration(inputDuration))
                                .font(.system(size: 16, weight: timerRunning ? .bold : .semibold, design: .rounded))
                                .foregroundColor(timerRunning ? AppColors.dominant : (inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary))
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .frame(width: 56, alignment: .center)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Time: \(formatDuration(inputDuration))")

                        Button {
                            toggleStopwatch()
                        } label: {
                            Image(systemName: timerRunning ? "stop.fill" : "stopwatch")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(timerRunning ? AppColors.warning : AppColors.accent1)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.12)))
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel(timerRunning ? "Stop stopwatch" : "Start stopwatch")
                    }
                }

                Text("time")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)

            // Distance input box
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .distance)

                    // Tappable unit selector
                    Button {
                        showDistanceUnitPicker = true
                    } label: {
                        Text(exercise.distanceUnit.abbreviation)
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.dominant)
                            .frame(minWidth: 24)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.dominant.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                Text("distance")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .confirmationDialog("Distance Unit", isPresented: $showDistanceUnitPicker, titleVisibility: .visible) {
            ForEach(DistanceUnit.allCases) { unit in
                Button(unit.displayName) {
                    onDistanceUnitChange?(unit)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Isometric Inputs

    private var isometricInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    // Always tappable for manual entry
                    Button {
                        showHoldTimePicker = true
                    } label: {
                        Text(timerRunning ? formatDuration(timerSecondsRemaining) : formatDuration(inputHoldTime))
                            .monoMedium(color: timerRunning ? (timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.dominant) : (inputHoldTime > 0 ? AppColors.textPrimary : AppColors.textTertiary))
                            .multilineTextAlignment(.center)
                            .frame(width: 56, alignment: .center)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    }
                    .buttonStyle(.plain)

                    // Timer button (always show for isometric)
                    Button {
                        toggleTimer()
                    } label: {
                        Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(timerRunning ? AppColors.warning : AppColors.dominant)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.dominant.opacity(0.12)))
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel(timerRunning ? "Stop hold timer" : "Start hold timer")
                }

                Text("hold")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Reps Only Inputs (Mobility)

    private var repsOnlyInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(spacing: 4) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    .focused($focusedField, equals: .reps)

                Text("reps")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Mobility Inputs (Reps, Duration, or Both)

    private var mobilityInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Show reps if tracking includes reps
            if exercise.mobilityTracking.tracksReps {
                VStack(spacing: 4) {
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .reps)

                    Text("reps")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Show duration if tracking includes duration
            if exercise.mobilityTracking.tracksDuration {
                VStack(spacing: 4) {
                    Button {
                        showTimePicker = true
                    } label: {
                        Text(formatDuration(inputDuration))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(width: 56, alignment: .center)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    }
                    .buttonStyle(.plain)

                    Text("time")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // MARK: - Explosive Inputs (Box Jumps, etc.)

    private var explosiveInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Reps input box
            VStack(spacing: 4) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    .focused($focusedField, equals: .reps)

                Text("reps")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)

            // Height input box
            VStack(spacing: 4) {
                TextField("0", text: $inputHeight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    .focused($focusedField, equals: .height)

                Text("in")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Recovery Inputs (Sauna, Cold Plunge, Stretching, etc.)

    private var recoveryInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Activity type indicator
            if let activityType = exercise.recoveryActivityType {
                HStack(spacing: 2) {
                    Image(systemName: activityType.icon)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.accent1)
                    Text(activityType.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Duration - tappable for manual entry
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    // Time display
                    Button {
                        showTimePicker = true
                    } label: {
                        Text(timerRunning ? formatDuration(stopwatchSeconds) : formatDuration(inputDuration))
                            .monoMedium(color: timerRunning ? AppColors.dominant : (inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary))
                            .multilineTextAlignment(.center)
                            .frame(width: 56, alignment: .center)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    }
                    .buttonStyle(.plain)

                    // Stopwatch toggle button
                    Button {
                        toggleStopwatch()
                    } label: {
                        Image(systemName: timerRunning ? "stop.fill" : "stopwatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(timerRunning ? AppColors.warning : AppColors.accent1)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.12)))
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel(timerRunning ? "Stop stopwatch" : "Start stopwatch")
                }

                Text("time")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)

            // Temperature (only for sauna/cold plunge)
            if let activityType = exercise.recoveryActivityType, activityType.supportsTemperature {
                VStack(spacing: 4) {
                    TextField(activityType == .sauna ? "180" : "50", text: $inputTemperature)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused($focusedField, equals: .temperature)

                    Text("°F")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // MARK: - Delete Button

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button {
            focusedField = nil
            action()
        } label: {
            Image(systemName: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.error)
                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                .background(
                    Circle()
                        .fill(AppColors.error.opacity(0.1))
                )
        }
        .buttonStyle(.bouncy)
        .accessibilityLabel("Delete set")
    }

    // MARK: - Log Button

    // MARK: - Same as Last Set Button (Friction Reduction)
    private var sameAsLastButton: some View {
        Button {
            guard let prevSet = previousCompletedSet else { return }
            // Copy values from previous completed set
            if let weight = prevSet.weight {
                inputWeight = formatWeight(weight)
            }
            if let reps = prevSet.reps {
                inputReps = "\(reps)"
            }
            if let duration = prevSet.duration {
                inputDuration = duration
                durationManuallySet = true
            }
            if let holdTime = prevSet.holdTime {
                inputHoldTime = holdTime
            }
            if let distance = prevSet.distance {
                inputDistance = formatDistanceValue(distance)
            }
            if let band = prevSet.bandColor {
                inputBandColor = band
            }
            // Copy multi-measurable values
            for measurable in flatSet.implementMeasurables {
                if let value = prevSet.implementMeasurableValues[measurable.measurableName] {
                    if let numericValue = value.numericValue {
                        inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(numericValue)
                    } else if let stringValue = value.stringValue {
                        inputMeasurableValues[measurable.measurableName] = stringValue
                    }
                }
            }
            // Light haptic to confirm action
            HapticManager.shared.soft()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.dominant)
                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                .background(
                    Circle()
                        .fill(AppColors.dominant.opacity(0.15))
                )
        }
        .buttonStyle(.bouncy)
        .accessibilityLabel("Copy previous set")
        .accessibilityHint("Fills in values from the last completed set")
    }

    private var logButton: some View {
        Button {
            // Dismiss keyboard explicitly (focusedField = nil doesn't always work for number pads)
            focusedField = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            // Trigger haptic feedback for set completion
            HapticManager.shared.setCompleted()

            let rpeValue = Int(inputRPE)
            let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }

            // For cardio/recovery, only save duration if user explicitly set it (timer/stopwatch/picker)
            // This prevents scheduled duration from being saved as if it were actual completed time
            let durationToSave: Int?
            if exercise.exerciseType == .cardio || exercise.exerciseType == .recovery {
                durationToSave = durationManuallySet && inputDuration > 0 ? inputDuration : nil
            } else {
                durationToSave = inputDuration > 0 ? inputDuration : nil
            }

            // For string-based implement measurables (e.g., band color), pass nil weight
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
                .font(.body.weight(.bold))
                .foregroundColor(.white)
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

        // Add side indicator for unilateral sets
        if flatSet.isUnilateral, let side = set.side {
            sidePrefix = "\(side.abbreviation): "
        }

        let mainSummary: String
        switch exercise.exerciseType {
        case .strength:
            // AMRAP sets get special formatting
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

                // String-based implement measurables (e.g., band color) show that instead of weight
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
                    // Box format: "24in × 10" for box jumps
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
                    // Bodyweight format: "BW + 25 × 10" or "BW × 10" if no added weight
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
            // Show whatever was actually logged (time, distance, or both)
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

    // MARK: - Timer Functions (now using SessionViewModel for background persistence)

    private func toggleTimer() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            if exercise.exerciseType == .isometric {
                inputHoldTime = elapsed
            } else {
                inputDuration = elapsed
                durationManuallySet = true
            }
        } else {
            sessionViewModel.startExerciseTimer(seconds: targetTimerSeconds, setId: flatSet.id)
        }
    }

    // MARK: - Stopwatch Functions (for distance-based cardio)

    private func toggleStopwatch() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
            durationManuallySet = true
        } else {
            sessionViewModel.startExerciseStopwatch(setId: flatSet.id)
        }
    }

    // MARK: - AMRAP Timer Button

    @ViewBuilder
    private func amrapTimerButton(timeLimit: Int) -> some View {
        Button {
            toggleAMRAPTimer(timeLimit: timeLimit)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(timerRunning ? AppColors.accent2 : AppColors.surfaceTertiary)
                        .frame(width: 36, height: 36)

                    if timerRunning {
                        Text("\(timerSecondsRemaining)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "timer")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Text(formatDurationVerbose(timeLimit))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private func toggleAMRAPTimer(timeLimit: Int) {
        if timerRunning {
            _ = sessionViewModel.stopExerciseTimer()
        } else {
            sessionViewModel.startExerciseTimer(seconds: timeLimit, setId: flatSet.id)
        }
    }

    // MARK: - Helpers

    private func loadDefaults() {
        let setData = flatSet.setData

        // Get last session values for this exercise (for smart auto-fill)
        let lastSessionSet = lastSessionExercise?.completedSetGroups
            .flatMap { $0.sets }
            .first { $0.completed }

        // Extract last session values
        let lastWeight = lastSessionSet?.weight
        let lastReps = lastSessionSet?.reps
        let lastDuration = lastSessionSet?.duration
        let lastHoldTime = lastSessionSet?.holdTime
        let lastDistance = lastSessionSet?.distance
        let lastHeight = lastSessionSet?.height
        let lastBandColor = lastSessionSet?.bandColor

        // If set was previously logged, load logged values for editing
        // Otherwise auto-fill with: last session values > target values > empty
        if setData.weight != nil || setData.reps != nil || setData.duration != nil || setData.holdTime != nil || setData.distance != nil {
            // Load logged values (user is editing a completed set)
            inputWeight = setData.weight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
            inputReps = setData.reps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""
            if !durationManuallySet {
                inputDuration = setData.duration ?? flatSet.targetDuration ?? 0
            }
            inputHoldTime = setData.holdTime ?? flatSet.targetHoldTime ?? 0
            inputDistance = setData.distance.map { formatDistanceValue($0) } ?? flatSet.targetDistance.map { formatDistanceValue($0) } ?? ""
        } else {
            // Smart auto-fill for new sets
            // For AMRAP: pre-fill with last AMRAP score as reference, but don't show target
            if flatSet.isAMRAP {
                inputWeight = lastWeight.map { formatWeight($0) }
                    ?? flatSet.targetWeight.map { formatWeight($0) }
                    ?? ""
                inputReps = lastReps.map { "\($0)" } ?? ""  // Show last AMRAP score as reference
            } else {
                // Normal sets: Priority: last session values > target values > empty
                inputWeight = lastWeight.map { formatWeight($0) }
                    ?? flatSet.targetWeight.map { formatWeight($0) }
                    ?? ""
                inputReps = lastReps.map { "\($0)" }
                    ?? flatSet.targetReps.map { "\($0)" }
                    ?? ""
            }
            inputHoldTime = lastHoldTime ?? flatSet.targetHoldTime ?? 0
            if !durationManuallySet {
                inputDuration = lastDuration ?? flatSet.targetDuration ?? 0
            }
            inputDistance = lastDistance.map { formatDistanceValue($0) }
                ?? flatSet.targetDistance.map { formatDistanceValue($0) }
                ?? ""
        }

        // Secondary fields: logged value > last session > empty
        inputRPE = setData.rpe.map { "\($0)" } ?? ""
        inputHeight = setData.height.map { formatHeightValue($0) }
            ?? lastHeight.map { formatHeightValue($0) }
            ?? ""
        inputIntensity = setData.intensity ?? 0
        inputTemperature = setData.temperature.map { "\($0)" } ?? ""
        inputBandColor = setData.bandColor ?? lastBandColor ?? ""

        // Multi-measurable values: logged value > last session value > target value > empty
        inputMeasurableValues = [:]
        for measurable in flatSet.implementMeasurables {
            if let loggedValue = setData.implementMeasurableValues[measurable.measurableName] {
                // Use logged value
                if let numericValue = loggedValue.numericValue {
                    inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(numericValue)
                } else if let stringValue = loggedValue.stringValue {
                    inputMeasurableValues[measurable.measurableName] = stringValue
                }
            } else if let lastSessionValue = lastSessionSet?.implementMeasurableValues[measurable.measurableName] {
                // Use last session value
                if let numericValue = lastSessionValue.numericValue {
                    inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(numericValue)
                } else if let stringValue = lastSessionValue.stringValue {
                    inputMeasurableValues[measurable.measurableName] = stringValue
                }
            } else if let targetNumeric = measurable.targetValue {
                // Use target value
                inputMeasurableValues[measurable.measurableName] = formatMeasurableValue(targetNumeric)
            } else if let targetString = measurable.targetStringValue {
                inputMeasurableValues[measurable.measurableName] = targetString
            }
        }
    }
}

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var totalSeconds: Int
    var title: String = "Time"
    var maxHours: Int = 4
    var onSave: (() -> Void)? = nil

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                HStack(spacing: 0) {
                    // Hours picker
                    Picker("Hours", selection: $hours) {
                        ForEach(0...maxHours, id: \.self) { hr in
                            Text("\(hr)").tag(hr)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("hr")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 30)

                    // Minutes picker
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text(String(format: "%02d", min)).tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("min")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 35)

                    // Seconds picker
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("sec")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 35)
                }
                .frame(height: 150)

                Spacer()
            }
            .padding(AppSpacing.lg)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                        onSave?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.dominant)
                }
            }
            .onAppear {
                hours = totalSeconds / 3600
                minutes = (totalSeconds % 3600) / 60
                seconds = totalSeconds % 60
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
