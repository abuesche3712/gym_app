//
//  CardioInputsView.swift
//  gym app
//
//  Cardio and other duration-based exercise input fields
//

import SwiftUI

// MARK: - Cardio Inputs

struct CardioInputs: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise

    @Binding var inputDuration: Int
    @Binding var inputDistance: String
    @Binding var durationManuallySet: Bool
    @Binding var showTimePicker: Bool
    @Binding var showDistanceUnitPicker: Bool

    var focusedField: FocusState<SetRowFieldType?>.Binding
    var onDistanceUnitChange: ((DistanceUnit) -> Void)?

    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    private var timerSecondsRemaining: Int {
        timerRunning && !sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var stopwatchSeconds: Int {
        timerRunning && sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Time input box - only show if tracking time
            if exercise.cardioMetric.tracksTime {
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
                                    .subheadline(color: timerRunning ? AppColors.warning : AppColors.dominant)
                                    .fontWeight(.semibold)
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
                                    .subheadline(color: timerRunning ? AppColors.warning : AppColors.accent1)
                                    .fontWeight(.semibold)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.12)))
                            }
                            .buttonStyle(.bouncy)
                            .accessibilityLabel(timerRunning ? "Stop stopwatch" : "Start stopwatch")
                        }
                    }

                    Text("time")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Distance input box - only show if tracking distance
            if exercise.cardioMetric.tracksDistance {
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
                            .focused(focusedField, equals: .distance)

                        // Tappable unit selector
                        Button {
                            showDistanceUnitPicker = true
                        } label: {
                            Text(exercise.distanceUnit.abbreviation)
                                .caption(color: AppColors.dominant)
                                .fontWeight(.medium)
                                .frame(minWidth: 24)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.dominant.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("distance")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
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

    private func toggleTimer() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
            durationManuallySet = true
        } else {
            sessionViewModel.startExerciseTimer(seconds: flatSet.targetDuration ?? 0, setId: flatSet.id)
        }
    }

    private func toggleStopwatch() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
            durationManuallySet = true
        } else {
            sessionViewModel.startExerciseStopwatch(setId: flatSet.id)
        }
    }
}

// MARK: - Isometric Inputs

struct IsometricInputs: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise

    @Binding var inputHoldTime: Int
    @Binding var showHoldTimePicker: Bool

    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    private var timerSecondsRemaining: Int {
        timerRunning && !sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var targetTimerSeconds: Int {
        flatSet.targetHoldTime ?? 0
    }

    var body: some View {
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
                            .subheadline(color: timerRunning ? AppColors.warning : AppColors.dominant)
                            .fontWeight(.semibold)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.dominant.opacity(0.12)))
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel(timerRunning ? "Stop hold timer" : "Start hold timer")
                }

                Text("hold")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func toggleTimer() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputHoldTime = elapsed
        } else {
            sessionViewModel.startExerciseTimer(seconds: targetTimerSeconds, setId: flatSet.id)
        }
    }
}

// MARK: - Mobility Inputs

struct MobilityInputs: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise

    @Binding var inputReps: String
    @Binding var inputDuration: Int
    @Binding var showTimePicker: Bool

    var focusedField: FocusState<SetRowFieldType?>.Binding

    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    private var timerSecondsRemaining: Int {
        timerRunning && !sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var stopwatchSeconds: Int {
        timerRunning && sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    private var targetTimerSeconds: Int {
        flatSet.targetDuration ?? 0
    }

    var body: some View {
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
                        .focused(focusedField, equals: .reps)

                    Text("reps")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Show duration if tracking includes duration
            if exercise.mobilityTracking.tracksDuration {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        // Time display - tappable for manual entry
                        Button {
                            showTimePicker = true
                        } label: {
                            Text(timerRunning ? (targetTimerSeconds > 0 ? formatDuration(timerSecondsRemaining) : formatDuration(stopwatchSeconds)) : formatDuration(inputDuration))
                                .monoMedium(color: timerRunning ? (timerSecondsRemaining <= 10 && targetTimerSeconds > 0 ? AppColors.warning : AppColors.dominant) : (inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary))
                                .multilineTextAlignment(.center)
                                .frame(width: 56, alignment: .center)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        }
                        .buttonStyle(.plain)

                        // Timer/Stopwatch button
                        Button {
                            toggleTimer()
                        } label: {
                            Image(systemName: timerRunning ? "stop.fill" : (targetTimerSeconds > 0 ? "play.fill" : "stopwatch"))
                                .subheadline(color: timerRunning ? AppColors.warning : AppColors.accent1)
                                .fontWeight(.semibold)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.12)))
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel(timerRunning ? "Stop timer" : (targetTimerSeconds > 0 ? "Start countdown" : "Start stopwatch"))
                    }

                    Text("time")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func toggleTimer() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
        } else {
            if targetTimerSeconds > 0 {
                // Use countdown timer if there's a target duration
                sessionViewModel.startExerciseTimer(seconds: targetTimerSeconds, setId: flatSet.id)
            } else {
                // Use stopwatch if no target duration
                sessionViewModel.startExerciseStopwatch(setId: flatSet.id)
            }
        }
    }
}

// MARK: - Explosive Inputs

struct ExplosiveInputs: View {
    @Binding var inputReps: String
    @Binding var inputHeight: String

    var focusedField: FocusState<SetRowFieldType?>.Binding

    var body: some View {
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
                    .focused(focusedField, equals: .reps)

                Text("reps")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
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
                    .focused(focusedField, equals: .height)

                Text("in")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Recovery Inputs

struct RecoveryInputs: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise

    @Binding var inputDuration: Int
    @Binding var inputTemperature: String
    @Binding var durationManuallySet: Bool
    @Binding var showTimePicker: Bool

    var focusedField: FocusState<SetRowFieldType?>.Binding

    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    private var stopwatchSeconds: Int {
        timerRunning && sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Activity type indicator
            if let activityType = exercise.recoveryActivityType {
                HStack(spacing: 2) {
                    Image(systemName: activityType.icon)
                        .caption(color: AppColors.accent1)
                        .fontWeight(.medium)
                    Text(activityType.displayName)
                        .caption2(color: AppColors.textSecondary)
                        .fontWeight(.medium)
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
                            .subheadline(color: timerRunning ? AppColors.warning : AppColors.accent1)
                            .fontWeight(.semibold)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accent1.opacity(0.12)))
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel(timerRunning ? "Stop stopwatch" : "Start stopwatch")
                }

                Text("time")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
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
                        .focused(focusedField, equals: .temperature)

                    Text("°F")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func toggleStopwatch() {
        if timerRunning {
            let elapsed = sessionViewModel.stopExerciseTimer()
            inputDuration = elapsed
            durationManuallySet = true
        } else {
            sessionViewModel.startExerciseStopwatch(setId: flatSet.id)
        }
    }
}
