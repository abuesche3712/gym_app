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

// MARK: - Set Row View (Expandable)

struct SetRowView: View {
    let flatSet: FlatSet
    let exercise: SessionExercise
    let isExpanded: Bool
    let onTap: () -> Void
    let onLog: (Double?, Int?, Int?, Int?, Int?, Double?) -> Void

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed row - always visible
            Button(action: onTap) {
                HStack(spacing: AppSpacing.md) {
                    // Set number indicator
                    ZStack {
                        Circle()
                            .fill(flatSet.setData.completed ? AppColors.success.opacity(0.15) : AppColors.surfaceLight)
                            .frame(width: 36, height: 36)

                        if flatSet.setData.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.success)
                        } else {
                            Text("\(flatSet.setNumber)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Set info
                    VStack(alignment: .leading, spacing: 2) {
                        if flatSet.setData.completed {
                            Text(completedSummary)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                        } else {
                            Text(targetSummary)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Expand indicator
                    if !flatSet.setData.completed {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(flatSet.setData.completed ? AppColors.success.opacity(0.05) : (isExpanded ? AppColors.accentBlue.opacity(0.05) : AppColors.surfaceLight))
                )
            }
            .buttonStyle(.plain)
            .disabled(flatSet.setData.completed)

            // Expanded input section
            if isExpanded && !flatSet.setData.completed {
                VStack(spacing: AppSpacing.md) {
                    inputFields

                    // Log button
                    Button {
                        isInputFocused = false
                        onLog(
                            Double(inputWeight),
                            Int(inputReps),
                            inputRPE > 0 ? inputRPE : nil,
                            inputDuration > 0 ? inputDuration : nil,
                            inputHoldTime > 0 ? inputHoldTime : nil,
                            Double(inputDistance)
                        )
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Log Set \(flatSet.setNumber)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppGradients.accentGradient)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .stroke(AppColors.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .onAppear { loadDefaults() }
    }

    private var targetSummary: String {
        switch exercise.exerciseType {
        case .strength:
            let weight = flatSet.targetWeight.map { formatWeight($0) + " lbs" } ?? ""
            let reps = flatSet.targetReps.map { "\($0) reps" } ?? ""
            if !weight.isEmpty && !reps.isEmpty {
                return "\(weight) × \(reps)"
            }
            return weight.isEmpty ? reps : weight
        case .isometric:
            return flatSet.targetHoldTime.map { "\($0)s hold" } ?? "Hold"
        case .cardio:
            if exercise.isDistanceBased {
                return flatSet.targetDistance.map { "\(formatDistance($0)) \(exercise.distanceUnit.abbreviation)" } ?? "Distance"
            }
            return flatSet.targetDuration.map { formatDuration($0) } ?? "Duration"
        case .mobility, .explosive:
            return flatSet.targetReps.map { "\($0) reps" } ?? "Reps"
        }
    }

    private var completedSummary: String {
        let set = flatSet.setData
        switch exercise.exerciseType {
        case .strength:
            return set.formattedStrength ?? "Completed"
        case .isometric:
            return set.formattedIsometric ?? "Completed"
        case .cardio:
            if exercise.isDistanceBased {
                if let duration = set.duration {
                    return formatDuration(duration)
                }
            } else {
                if let distance = set.distance {
                    return "\(formatDistance(distance)) \(exercise.distanceUnit.abbreviation)"
                }
            }
            return "Completed"
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "Completed"
        }
    }

    @ViewBuilder
    private var inputFields: some View {
        switch exercise.exerciseType {
        case .strength:
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEIGHT")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("RPE")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    Picker("RPE", selection: $inputRPE) {
                        Text("--").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 60)
                    .clipped()
                }
            }

        case .isometric:
            TimePickerView(totalSeconds: $inputHoldTime, maxMinutes: 5, label: "Hold Time")

        case .cardio:
            if exercise.isDistanceBased {
                TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, label: "Time")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE (\(exercise.distanceUnit.abbreviation.uppercased()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }
            }

        case .mobility, .explosive:
            VStack(alignment: .leading, spacing: 4) {
                Text("REPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                    .focused($isInputFocused)
            }
        }
    }

    private func loadDefaults() {
        inputWeight = flatSet.targetWeight.map { formatWeight($0) } ?? ""
        inputReps = flatSet.targetReps.map { "\($0)" } ?? ""
        inputHoldTime = flatSet.targetHoldTime ?? 0
        inputRPE = 0

        if exercise.exerciseType == .cardio {
            inputDuration = 0
            inputDistance = ""
        } else {
            inputDuration = flatSet.targetDuration ?? 0
            inputDistance = flatSet.targetDistance.map { formatDistance($0) } ?? ""
        }
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
