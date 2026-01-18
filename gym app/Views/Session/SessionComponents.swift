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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCurrent ? AppColors.accentBlue : AppColors.textTertiary)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent && !isCompleted ? AppColors.accentBlue : .clear, lineWidth: 2)
        )
        .animation(AppAnimation.quick, value: isCompleted)
        .animation(AppAnimation.quick, value: isCurrent)
    }

    private var backgroundColor: Color {
        if isCurrent {
            return AppColors.accentBlue.opacity(0.15)
        } else {
            return AppColors.surfaceLight
        }
    }
}

// MARK: - Set Row View (Inline Inputs)

struct SetRowView: View {
    let flatSet: FlatSet
    let exercise: SessionExercise
    var isHighlighted: Bool = false  // Highlight when rest timer ends
    let onLog: (Double?, Int?, Int?, Int?, Int?, Double?, Double?, Int?, Int?, Int?) -> Void  // weight, reps, rpe, duration, holdTime, distance, height, quality, intensity, temperature
    var onDelete: (() -> Void)? = nil  // Optional delete callback
    var onDistanceUnitChange: ((DistanceUnit) -> Void)? = nil  // Callback to change distance unit
    var onUncheck: (() -> Void)? = nil  // Callback to uncheck/edit a completed set

    // Smart friction reduction: last session data for auto-fill hints
    var lastSessionExercise: SessionExercise? = nil
    // Smart friction reduction: previous completed set in current session for "same as last"
    var previousCompletedSet: SetData? = nil

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: String = ""
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @State private var inputHeight: String = ""  // For explosive exercises (box jumps)
    @State private var inputQuality: Int = 0  // 1-5 for explosive exercises
    @State private var inputIntensity: Int = 0  // 1-10 for isometric exercises
    @State private var inputTemperature: String = ""  // For recovery activities (sauna/cold plunge)
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case weight, reps, distance, height, rpe, temperature
    }

    // Inline timer state (countdown for time targets, stopwatch for distance targets)
    @State private var timerRunning: Bool = false
    @State private var timerSecondsRemaining: Int = 0  // For countdown timer
    @State private var stopwatchSeconds: Int = 0  // For stopwatch (counts up)
    @State private var timer: Timer?
    @State private var timerStartTime: Date?
    @State private var isStopwatchMode: Bool = false  // true = counting up, false = counting down
    @State private var showRPEPicker: Bool = false
    @State private var showTimePicker: Bool = false  // For manual time entry on distance-based cardio
    @State private var showDistanceUnitPicker: Bool = false  // For changing distance unit
    @State private var durationManuallySet: Bool = false  // Track if user manually set duration via picker
    @State private var justCompleted: Bool = false  // For completion glow animation
    @State private var swipeOffset: CGFloat = 0  // For swipe-to-complete gesture
    @State private var isSwipeActive: Bool = false  // Track if swipe threshold reached

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

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack(alignment: .leading) {
            // Swipe background (revealed on swipe)
            if !flatSet.setData.completed {
                HStack {
                    Image(systemName: isSwipeActive ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.leading, AppSpacing.lg)
                    Text(isSwipeActive ? "Release to log" : "Swipe to log")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(isSwipeActive ? AppColors.success : AppColors.success.opacity(0.7))
                )
            }

            // Main content
            HStack(spacing: AppSpacing.sm) {
                // Set number indicator
                setNumberBadge

                if flatSet.setData.completed {
                    // Completed state - show summary
                    completedView
                } else {
                    // Input fields based on exercise type - fills available space
                    inputFieldsView
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Same as last set button (friction reduction)
                    if previousCompletedSet != nil {
                        sameAsLastButton
                    }

                    // Delete button (if available and set not completed)
                    if let onDelete = onDelete {
                        deleteButton(action: onDelete)
                    }

                    // Log button
                    logButton
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isHighlighted ? AppColors.accentBlue.opacity(0.08) : backgroundColor)
            )
            .offset(x: swipeOffset)
            .gesture(
                flatSet.setData.completed ? nil : DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only allow right swipe
                        if value.translation.width > 0 {
                            swipeOffset = value.translation.width
                            isSwipeActive = swipeOffset > swipeThreshold
                            if isSwipeActive && !flatSet.setData.completed {
                                HapticManager.shared.soft()
                            }
                        }
                    }
                    .onEnded { value in
                        if swipeOffset > swipeThreshold {
                            // Complete the set via swipe
                            triggerSwipeComplete()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                            isSwipeActive = false
                        }
                    }
            )
        }
        .completionGlow(isActive: justCompleted, color: AppColors.success)
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(isHighlighted ? AppColors.accentBlue.opacity(0.5) : .clear, lineWidth: 2)
        )
        .shadow(color: isHighlighted ? AppColors.accentBlue.opacity(0.3) : .clear, radius: isHighlighted ? 4 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.easeInOut(duration: 0.2), value: timerRunning)
        .animation(.easeInOut(duration: 0.2), value: flatSet.setData.completed)
        .onAppear { loadDefaults() }
        .onDisappear { stopTimer() }
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
                Circle()
                    .fill(AppColors.surfaceLight)
                    .frame(width: 32, height: 32)
                Text("\(flatSet.setNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var backgroundColor: Color {
        if flatSet.setData.completed {
            return AppColors.success.opacity(0.05)
        } else if timerRunning {
            return AppColors.accentBlue.opacity(0.1)
        }
        return AppColors.surfaceLight
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    // MARK: - Strength Inputs

    private var strengthInputs: some View {
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: weight × reps
            HStack(spacing: AppSpacing.sm) {
                // Weight input box (with BW prefix for bodyweight exercises)
                HStack(spacing: 4) {
                    if exercise.isBodyweight {
                        Text("BW +")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.accentBlue)
                    }

                    VStack(spacing: 4) {
                        TextField(exercise.isBodyweight ? "0" : "0", text: $inputWeight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 44)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                            .focused($focusedField, equals: .weight)

                        Text("lbs")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Text("×")
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)

                // Reps input box
                VStack(spacing: 4) {
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 40)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        .focused($focusedField, equals: .reps)

                    Text("reps")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)

            // Secondary input: RPE
            VStack(spacing: 4) {
                TextField("-", text: $inputRPE)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
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
            .frame(width: 60)
        }
    }

    // MARK: - Cardio Inputs
    // Always show both time and distance inputs - user can log either or both

    private var cardioInputs: some View {
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: time + distance
            HStack(spacing: AppSpacing.sm) {
                // Time input box
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        if let targetDuration = flatSet.targetDuration, targetDuration > 0 {
                            // Has time target - show countdown timer
                            if timerRunning {
                                Text(formatDuration(timerSecondsRemaining))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.accentBlue)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .frame(width: 70, alignment: .center)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                            } else {
                                // Tappable to manually edit time
                                Button {
                                    showTimePicker = true
                                } label: {
                                    Text(formatDuration(inputDuration))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 70, alignment: .center)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                toggleTimer()
                            } label: {
                                Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(timerRunning ? AppColors.warning : AppColors.accentBlue)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accentBlue.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        } else {
                            // No time target (distance-based) - show stopwatch to time the run
                            if timerRunning {
                                Text(formatDuration(stopwatchSeconds))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.accentBlue)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .frame(width: 70, alignment: .center)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                            } else {
                                Button {
                                    showTimePicker = true
                                } label: {
                                    Text(formatDuration(inputDuration))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 70, alignment: .center)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                toggleStopwatch()
                            } label: {
                                Image(systemName: timerRunning ? "stop.fill" : "stopwatch")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(timerRunning ? AppColors.warning : AppColors.accentTeal)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accentTeal.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("time")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }

                // Distance input box
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("0", text: $inputDistance)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 40)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                            .focused($focusedField, equals: .distance)

                        // Tappable unit selector
                        Button {
                            showDistanceUnitPicker = true
                        } label: {
                            Text(exercise.distanceUnit.abbreviation)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.accentBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.accentBlue.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("distance")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)
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
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: hold time
            HStack(spacing: AppSpacing.sm) {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        if timerRunning {
                            Text(formatDuration(timerSecondsRemaining))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.accentBlue)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .frame(width: 70, alignment: .center)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        } else {
                            Text(formatDuration(inputHoldTime))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .frame(width: 70, alignment: .center)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        }

                        if hasTimedTarget {
                            Button {
                                toggleTimer()
                            } label: {
                                Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(timerRunning ? AppColors.warning : AppColors.accentBlue)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accentBlue.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("hold")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Reps Only Inputs (Mobility)

    private var repsOnlyInputs: some View {
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: reps only
            HStack(spacing: AppSpacing.sm) {
                VStack(spacing: 4) {
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 40)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        .focused($focusedField, equals: .reps)

                    Text("reps")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Mobility Inputs (Reps, Duration, or Both)

    private var mobilityInputs: some View {
        HStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                // Show reps if tracking includes reps
                if exercise.mobilityTracking.tracksReps {
                    VStack(spacing: 4) {
                        TextField("0", text: $inputReps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 40)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                            .focused($focusedField, equals: .reps)

                        Text("reps")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                // Show duration if tracking includes duration
                if exercise.mobilityTracking.tracksDuration {
                    VStack(spacing: 4) {
                        Button {
                            showTimePicker = true
                        } label: {
                            Text(formatDuration(inputDuration))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                                .multilineTextAlignment(.center)
                                .frame(width: 70, alignment: .center)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        }
                        .buttonStyle(.plain)

                        Text("time")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Explosive Inputs (Box Jumps, etc.)

    private var explosiveInputs: some View {
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: reps + height
            HStack(spacing: AppSpacing.sm) {
                // Reps input box
                VStack(spacing: 4) {
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 40)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        .focused($focusedField, equals: .reps)

                    Text("reps")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }

                // Height input box
                VStack(spacing: 4) {
                    TextField("0", text: $inputHeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 40)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        .focused($focusedField, equals: .height)

                    Text("in")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)

            // Secondary input: Quality picker (1-5)
            VStack(spacing: 4) {
                Menu {
                    Button("--") { inputQuality = 0 }
                    ForEach(1...5, id: \.self) { quality in
                        Button("\(quality)") { inputQuality = quality }
                    }
                } label: {
                    Text(inputQuality > 0 ? "\(inputQuality)" : "-")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(inputQuality > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                }

                Text("quality")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(width: 60)
        }
    }

    // MARK: - Recovery Inputs (Sauna, Cold Plunge, Stretching, etc.)

    private var recoveryInputs: some View {
        HStack(spacing: AppSpacing.md) {
            // Primary inputs: activity type + duration
            HStack(spacing: AppSpacing.sm) {
                // Activity type indicator
                if let activityType = exercise.recoveryActivityType {
                    HStack(spacing: 4) {
                        Image(systemName: activityType.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.teal)
                        Text(activityType.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Duration with timer/stopwatch
                VStack(spacing: 4) {
                    Button {
                        toggleStopwatch()
                    } label: {
                        HStack(spacing: 4) {
                            if timerRunning {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.error)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.success)
                            }
                            Text(timerRunning ? formatDuration(stopwatchSeconds) : (inputDuration > 0 ? formatDuration(inputDuration) : "0:00"))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(timerRunning ? AppColors.accentBlue : AppColors.textPrimary)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 100, alignment: .center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(timerRunning ? AppColors.accentBlue.opacity(0.1) : AppColors.cardBackground))
                    }
                    .buttonStyle(.plain)

                    Text("duration")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer(minLength: 0)

            // Secondary input: Temperature (only for sauna/cold plunge)
            if let activityType = exercise.recoveryActivityType, activityType.supportsTemperature {
                VStack(spacing: 4) {
                    TextField(activityType == .sauna ? "180" : "50", text: $inputTemperature)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
                        .focused($focusedField, equals: .temperature)

                    Text("°F")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(width: 60)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.error)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(AppColors.error.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
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
                inputDistance = formatDistance(distance)
            }
            // Light haptic to confirm action
            HapticManager.shared.soft()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(AppColors.accentBlue.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .help("Same as last set")
    }

    private var logButton: some View {
        Button {
            focusedField = nil
            // Trigger haptic feedback for set completion
            HapticManager.shared.setCompleted()

            let rpeValue = Int(inputRPE)
            let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }
            onLog(
                Double(inputWeight),
                Int(inputReps),
                validRPE,
                inputDuration > 0 ? inputDuration : nil,
                inputHoldTime > 0 ? inputHoldTime : nil,
                Double(inputDistance),
                Double(inputHeight),
                inputQuality > 0 ? inputQuality : nil,
                inputIntensity > 0 ? inputIntensity : nil,
                Int(inputTemperature)
            )
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(AppGradients.accentGradient)
                )
        }
        .buttonStyle(.bouncy)
    }

    // MARK: - Completed Summary

    private var completedSummary: String {
        let set = flatSet.setData
        switch exercise.exerciseType {
        case .strength:
            if exercise.isBodyweight {
                // Bodyweight format: "BW + 25 × 10" or "BW × 10" if no added weight
                if let reps = set.reps {
                    if let weight = set.weight, weight > 0 {
                        var result = "BW + \(formatWeight(weight)) × \(reps)"
                        if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                        return result
                    } else {
                        var result = "BW × \(reps)"
                        if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                        return result
                    }
                }
                return "Completed"
            }
            return set.formattedStrength ?? "Completed"
        case .isometric:
            var parts: [String] = []
            if let holdTime = set.holdTime {
                parts.append(formatDuration(holdTime) + " hold")
            }
            if let intensity = set.intensity {
                parts.append("@ \(intensity)/10")
            }
            return parts.isEmpty ? "Completed" : parts.joined(separator: " ")
        case .cardio:
            // Show whatever was actually logged (time, distance, or both)
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistance(distance)) \(exercise.distanceUnit.abbreviation)")
            }
            return parts.isEmpty ? "Completed" : parts.joined(separator: " / ")
        case .explosive:
            var parts: [String] = []
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if let height = set.height {
                parts.append("@ \(formatHeight(height))")
            }
            if let quality = set.quality {
                parts.append("(\(quality)/5)")
            }
            return parts.isEmpty ? "Completed" : parts.joined(separator: " ")
        case .mobility:
            var parts: [String] = []
            if exercise.mobilityTracking.tracksReps, let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if exercise.mobilityTracking.tracksDuration, let duration = set.duration {
                parts.append(formatDuration(duration))
            }
            return parts.isEmpty ? "Completed" : parts.joined(separator: " · ")
        case .recovery:
            if let duration = set.duration {
                var result = formatDuration(duration)
                if let temp = set.temperature {
                    result += " @ \(temp)°F"
                }
                return result
            }
            return "Completed"
        }
    }

    private func formatHeight(_ height: Double) -> String {
        if height == floor(height) {
            return "\(Int(height)) in"
        }
        return String(format: "%.1f in", height)
    }

    // MARK: - Timer Functions

    private func toggleTimer() {
        if timerRunning {
            stopTimer()
            let elapsed = targetTimerSeconds - timerSecondsRemaining
            if exercise.exerciseType == .isometric {
                inputHoldTime = elapsed
            } else {
                inputDuration = elapsed
            }
        } else {
            startTimer()
        }
    }

    private func startTimer() {
        timerStartTime = Date()
        timerSecondsRemaining = targetTimerSeconds
        timerRunning = true

        HapticManager.shared.impact()

        updateTimerFromStartTime()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            updateTimerFromStartTime()
        }

        // Listen for foreground to update timer
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            updateTimerFromStartTime()
        }
    }

    private func updateTimerFromStartTime() {
        guard let startTime = timerStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let remaining = targetTimerSeconds - elapsed

        if remaining > 0 {
            // Haptic for last 3 seconds countdown
            if remaining <= 3 && timerSecondsRemaining > 3 {
                HapticManager.shared.tap()
            }
            timerSecondsRemaining = remaining
        } else {
            timerComplete()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        timerStartTime = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func timerComplete() {
        stopTimer()
        HapticManager.shared.timerComplete()

        if exercise.exerciseType == .isometric {
            inputHoldTime = targetTimerSeconds
        } else {
            inputDuration = targetTimerSeconds
        }
    }

    // MARK: - Stopwatch Functions (for distance-based cardio)

    private func toggleStopwatch() {
        if timerRunning {
            stopStopwatch()
        } else {
            startStopwatch()
        }
    }

    private func startStopwatch() {
        timerStartTime = Date()
        stopwatchSeconds = 0
        timerRunning = true
        isStopwatchMode = true

        HapticManager.shared.impact()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateStopwatch()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateStopwatch()
        }
    }

    private func updateStopwatch() {
        guard let startTime = timerStartTime else { return }
        stopwatchSeconds = Int(Date().timeIntervalSince(startTime))
    }

    private func stopStopwatch() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        isStopwatchMode = false
        inputDuration = stopwatchSeconds
        timerStartTime = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)

        HapticManager.shared.timerComplete()
    }

    // MARK: - Swipe Complete

    private func triggerSwipeComplete() {
        focusedField = nil
        HapticManager.shared.setCompleted()

        let rpeValue = Int(inputRPE)
        let validRPE = rpeValue.flatMap { $0 >= 1 && $0 <= 10 ? $0 : nil }
        onLog(
            Double(inputWeight),
            Int(inputReps),
            validRPE,
            inputDuration > 0 ? inputDuration : nil,
            inputHoldTime > 0 ? inputHoldTime : nil,
            Double(inputDistance),
            Double(inputHeight),
            inputQuality > 0 ? inputQuality : nil,
            inputIntensity > 0 ? inputIntensity : nil,
            Int(inputTemperature)
        )
    }

    // MARK: - Helpers

    private func loadDefaults() {
        let setData = flatSet.setData

        // Get last session values for this exercise (for smart auto-fill)
        let lastSessionSet = lastSessionExercise?.completedSetGroups
            .flatMap { $0.sets }
            .first { $0.completed }

        // If set was previously logged, load logged values for editing
        // Otherwise load target values for new sets
        if setData.weight != nil || setData.reps != nil || setData.duration != nil || setData.holdTime != nil || setData.distance != nil {
            // Load logged values
            inputWeight = setData.weight.map { formatWeight($0) } ?? flatSet.targetWeight.map { formatWeight($0) } ?? ""
            inputReps = setData.reps.map { "\($0)" } ?? flatSet.targetReps.map { "\($0)" } ?? ""
            // Only load duration if user hasn't manually set it via time picker
            if !durationManuallySet {
                inputDuration = setData.duration ?? flatSet.targetDuration ?? 0
            }
            inputHoldTime = setData.holdTime ?? flatSet.targetHoldTime ?? 0
            inputDistance = setData.distance.map { formatDistance($0) } ?? flatSet.targetDistance.map { formatDistance($0) } ?? ""
        } else {
            // Smart auto-fill: Use last session values if no target values exist
            // Priority: target values > last session values > empty
            let lastWeight = lastSessionSet?.weight
            let lastReps = lastSessionSet?.reps
            let lastDuration = lastSessionSet?.duration
            let lastHoldTime = lastSessionSet?.holdTime
            let lastDistance = lastSessionSet?.distance

            inputWeight = flatSet.targetWeight.map { formatWeight($0) }
                ?? lastWeight.map { formatWeight($0) }
                ?? ""
            inputReps = flatSet.targetReps.map { "\($0)" }
                ?? lastReps.map { "\($0)" }
                ?? ""
            inputHoldTime = flatSet.targetHoldTime ?? lastHoldTime ?? 0
            // Only load duration if user hasn't manually set it via time picker
            if !durationManuallySet {
                inputDuration = flatSet.targetDuration ?? lastDuration ?? 0
            }
            inputDistance = flatSet.targetDistance.map { formatDistance($0) }
                ?? lastDistance.map { formatDistance($0) }
                ?? ""
        }

        // Always load these from setData if present
        inputRPE = setData.rpe.map { "\($0)" } ?? ""
        inputHeight = setData.height.map { formatHeight($0).replacingOccurrences(of: " in", with: "") } ?? ""
        inputQuality = setData.quality ?? 0
        inputIntensity = setData.intensity ?? 0
        inputTemperature = setData.temperature.map { "\($0)" } ?? ""
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
                    .foregroundColor(AppColors.accentBlue)
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
