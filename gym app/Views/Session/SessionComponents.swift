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
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.success)
            } else {
                Text("\(setNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCurrent ? AppColors.accentBlue : AppColors.textTertiary)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent ? AppColors.accentBlue : .clear, lineWidth: 2)
        )
        .animation(AppAnimation.quick, value: isCompleted)
        .animation(AppAnimation.quick, value: isCurrent)
    }

    private var backgroundColor: Color {
        if isCompleted {
            return AppColors.success.opacity(0.15)
        } else if isCurrent {
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
    let isExpanded: Bool  // Kept for API compatibility but not used
    let onTap: () -> Void  // Kept for API compatibility but not used
    let onLog: (Double?, Int?, Int?, Int?, Int?, Double?) -> Void
    var onDelete: (() -> Void)? = nil  // Optional delete callback

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case weight, reps, distance
    }

    // Inline timer state
    @State private var timerRunning: Bool = false
    @State private var timerSecondsRemaining: Int = 0
    @State private var timer: Timer?
    @State private var timerStartTime: Date?
    @State private var showRPEPicker: Bool = false

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

            if flatSet.setData.completed {
                // Completed state - show summary
                completedView
            } else {
                // Input fields based on exercise type
                inputFieldsView

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
                .fill(backgroundColor)
        )
        .animation(.easeInOut(duration: 0.2), value: timerRunning)
        .animation(.easeInOut(duration: 0.2), value: flatSet.setData.completed)
        .onAppear { loadDefaults() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Subviews

    private var setNumberBadge: some View {
        ZStack {
            Circle()
                .fill(flatSet.setData.completed ? AppColors.success.opacity(0.15) : AppColors.surfaceLight)
                .frame(width: 32, height: 32)

            if flatSet.setData.completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.success)
            } else {
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
        Text(completedSummary)
            .font(.subheadline.weight(.medium))
            .foregroundColor(AppColors.textPrimary)
        Spacer()
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
        case .mobility, .explosive:
            repsOnlyInputs
        }
    }

    // MARK: - Strength Inputs

    private var strengthInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Weight input
            HStack(spacing: 2) {
                TextField("0", text: $inputWeight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.cardBackground))
                    .focused($focusedField, equals: .weight)

                Text("lbs")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Text("×")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)

            // Reps input
            HStack(spacing: 2) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.cardBackground))
                    .focused($focusedField, equals: .reps)

                Text("reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // RPE button
            Menu {
                Button("--") { inputRPE = 0 }
                ForEach(5...10, id: \.self) { rpe in
                    Button("RPE \(rpe)") { inputRPE = rpe }
                }
            } label: {
                Text(inputRPE > 0 ? "RPE \(inputRPE)" : "RPE")
                    .font(.caption.weight(.medium))
                    .foregroundColor(inputRPE > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.cardBackground))
            }
        }
    }

    // MARK: - Cardio Inputs
    // Always show both time and distance inputs - user can log either or both

    private var cardioInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            // Time display with timer - always shown for cardio
            HStack(spacing: 4) {
                if timerRunning {
                    Text(formatDuration(timerSecondsRemaining))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.accentBlue)
                        .monospacedDigit()
                        .frame(minWidth: 50)
                } else {
                    Text(formatDuration(inputDuration))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(inputDuration > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                        .frame(minWidth: 50)
                }

                // Timer button - show if there's a time target to count down from
                if hasTimedTarget {
                    Button {
                        toggleTimer()
                    } label: {
                        Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(timerRunning ? AppColors.warning : AppColors.accentBlue)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accentBlue.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("/")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)

            // Distance input - always shown for cardio
            HStack(spacing: 2) {
                TextField("0", text: $inputDistance)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.cardBackground))
                    .focused($focusedField, equals: .distance)

                Text(exercise.distanceUnit.abbreviation)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Isometric Inputs

    private var isometricInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: 4) {
                if timerRunning {
                    Text(formatDuration(timerSecondsRemaining))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(timerSecondsRemaining <= 10 ? AppColors.warning : AppColors.accentBlue)
                        .monospacedDigit()
                        .frame(minWidth: 50)
                } else {
                    Text(formatDuration(inputHoldTime))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50)
                }

                Text("hold")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)

                if hasTimedTarget {
                    Button {
                        toggleTimer()
                    } label: {
                        Image(systemName: timerRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(timerRunning ? AppColors.warning : AppColors.accentBlue)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(timerRunning ? AppColors.warning.opacity(0.15) : AppColors.accentBlue.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    // MARK: - Reps Only Inputs

    private var repsOnlyInputs: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: 2) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.cardBackground))
                    .focused($focusedField, equals: .reps)

                Text("reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
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

    private var logButton: some View {
        Button {
            focusedField = nil
            onLog(
                Double(inputWeight),
                Int(inputReps),
                inputRPE > 0 ? inputRPE : nil,
                inputDuration > 0 ? inputDuration : nil,
                inputHoldTime > 0 ? inputHoldTime : nil,
                Double(inputDistance)
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
        .buttonStyle(.plain)
    }

    // MARK: - Completed Summary

    private var completedSummary: String {
        let set = flatSet.setData
        switch exercise.exerciseType {
        case .strength:
            return set.formattedStrength ?? "Completed"
        case .isometric:
            return set.formattedIsometric ?? "Completed"
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
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "Completed"
        }
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

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

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
            // Haptic for last 3 seconds
            if remaining <= 3 && timerSecondsRemaining > 3 {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
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
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if exercise.exerciseType == .isometric {
            inputHoldTime = targetTimerSeconds
        } else {
            inputDuration = targetTimerSeconds
        }
    }

    // MARK: - Helpers

    private func loadDefaults() {
        inputWeight = flatSet.targetWeight.map { formatWeight($0) } ?? ""
        inputReps = flatSet.targetReps.map { "\($0)" } ?? ""
        inputHoldTime = flatSet.targetHoldTime ?? 0
        inputDuration = flatSet.targetDuration ?? 0
        inputDistance = flatSet.targetDistance.map { formatDistance($0) } ?? ""
        inputRPE = 0
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) { return "\(Int(weight))" }
        return String(format: "%.1f", weight)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) { return "\(Int(distance))" }
        return String(format: "%.2f", distance)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}
