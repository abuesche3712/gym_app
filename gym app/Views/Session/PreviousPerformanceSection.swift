//
//  PreviousPerformanceSection.swift
//  gym app
//
//  Previous workout data display for active session
//

import SwiftUI

struct PreviousPerformanceSection: View {
    let exerciseName: String
    let lastData: SessionExercise?
    var fromSameWorkout: Bool = true

    var body: some View {
        Group {
            if let lastData = lastData {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .subheadline(color: AppColors.textTertiary)
                        Text(fromSameWorkout ? "Last Session" : "Last Performed")
                            .subheadline(color: AppColors.textSecondary)
                            .fontWeight(.semibold)

                        Spacer()

                        // Show progression recommendation if set
                        if let progression = lastData.progressionRecommendation {
                            HStack(spacing: 4) {
                                Image(systemName: progression.icon)
                                    .caption(color: progression.color)
                                Text(progression.displayName)
                                    .caption(color: progression.color)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(progression.color.opacity(0.15))
                            )
                        }
                    }

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(lastData.completedSetGroups) { setGroup in
                            if setGroup.isInterval {
                                // Show intervals as summary: "x rounds (y on/z off)"
                                PreviousIntervalRow(setGroup: setGroup, exercise: lastData)
                            } else {
                                ForEach(setGroup.sets) { set in
                                    PreviousSetRow(set: set, exercise: lastData)
                                }
                            }
                        }
                    }

                    // Show notes from last session if present
                    if let notes = lastData.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .caption(color: AppColors.textTertiary)
                                Text("Notes")
                                    .caption(color: AppColors.textTertiary)
                                    .fontWeight(.semibold)
                            }

                            Text(notes)
                                .caption(color: AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceTertiary.opacity(0.5))
                )
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "clock.arrow.circlepath")
                        .subheadline(color: AppColors.textTertiary)
                    Text("No exercise history")
                        .subheadline(color: AppColors.textTertiary)
                }
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceTertiary.opacity(0.3))
                )
            }
        }
    }
}

// MARK: - Previous Set Row

struct PreviousSetRow: View {
    let set: SetData
    let exercise: SessionExercise

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Set number badge
            Text("\(set.setNumber)")
                .caption(color: AppColors.textTertiary)
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppColors.surfaceTertiary))

            // Metrics based on exercise type
            HStack(spacing: AppSpacing.sm) {
                switch exercise.exerciseType {
                case .strength:
                    strengthMetrics
                case .isometric:
                    isometricMetrics
                case .cardio:
                    cardioMetrics
                case .explosive:
                    explosiveMetrics
                case .mobility:
                    mobilityMetrics
                case .recovery:
                    recoveryMetrics
                }

                // Equipment measurables (e.g., box height, band weight, etc.)
                equipmentMeasurablesPills
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var strengthMetrics: some View {
        // Check for string-based implement measurable (e.g., band color)
        if let stringMeasurable = exercise.implementStringMeasurable {
            if let bandColor = set.bandColor, !bandColor.isEmpty {
                MetricPill(value: bandColor, label: stringMeasurable.implementName.lowercased(), color: AppColors.accent3)
            }
            if let reps = set.reps {
                MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
            }
        } else if let bandColor = set.bandColor, !bandColor.isEmpty {
            // Show band color even if implement isn't loaded (for historical data)
            MetricPill(value: bandColor, label: "band", color: AppColors.accent3)
            if let reps = set.reps {
                MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
            }
        } else if exercise.isBodyweight {
            if let reps = set.reps {
                if let weight = set.weight, weight > 0 {
                    MetricPill(value: "BW+\(formatWeight(weight))", label: nil, color: AppColors.dominant)
                } else {
                    MetricPill(value: "BW", label: nil, color: AppColors.dominant)
                }
                MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
            }
        } else {
            if let weight = set.weight {
                MetricPill(value: formatWeight(weight), label: "lbs", color: AppColors.dominant)
            }
            if let reps = set.reps {
                MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
            }
        }
        if let rpe = set.rpe {
            MetricPill(value: "\(rpe)", label: "RPE", color: AppColors.warning)
        }
    }

    @ViewBuilder
    private var isometricMetrics: some View {
        if let holdTime = set.holdTime {
            MetricPill(value: formatDuration(holdTime), label: "hold", color: AppColors.dominant)
        }
        if let intensity = set.intensity {
            MetricPill(value: "\(intensity)/10", label: nil, color: AppColors.warning)
        }
    }

    @ViewBuilder
    private var cardioMetrics: some View {
        if let duration = set.duration, duration > 0 {
            MetricPill(value: formatDuration(duration), label: "time", color: AppColors.dominant)
        }
        if let distance = set.distance, distance > 0 {
            MetricPill(value: formatDistanceValue(distance), label: exercise.distanceUnit.abbreviation, color: AppColors.accent1)
        }
    }

    @ViewBuilder
    private var explosiveMetrics: some View {
        if let reps = set.reps {
            MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
        }
        if let height = set.height {
            MetricPill(value: formatHeight(height), label: nil, color: AppColors.dominant)
        }
    }

    @ViewBuilder
    private var mobilityMetrics: some View {
        if let reps = set.reps {
            MetricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
        }
        if let duration = set.duration, duration > 0 {
            MetricPill(value: formatDuration(duration), label: nil, color: AppColors.dominant)
        }
    }

    @ViewBuilder
    private var recoveryMetrics: some View {
        if let duration = set.duration {
            MetricPill(value: formatDuration(duration), label: nil, color: AppColors.dominant)
        }
        if let temp = set.temperature {
            MetricPill(value: "\(temp)°F", label: nil, color: AppColors.warning)
        }
    }

    @ViewBuilder
    private var equipmentMeasurablesPills: some View {
        if !set.implementMeasurableValues.isEmpty {
            ForEach(Array(set.implementMeasurableValues.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                if let numericValue = value.numericValue {
                    MetricPill(
                        value: formatMeasurableValue(numericValue),
                        label: key,
                        color: AppColors.accent3
                    )
                } else if let stringValue = value.stringValue {
                    MetricPill(value: stringValue, label: key, color: AppColors.accent3)
                }
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
}

// MARK: - Previous Interval Row

struct PreviousIntervalRow: View {
    let setGroup: CompletedSetGroup
    let exercise: SessionExercise

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Interval icon
            Image(systemName: "timer")
                .caption(color: AppColors.warning)
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppColors.surfaceTertiary))

            // Interval summary: "x rounds (y on / z off)"
            HStack(spacing: AppSpacing.sm) {
                MetricPill(
                    value: "\(setGroup.rounds)",
                    label: "rounds",
                    color: AppColors.warning
                )

                Text("(\(formatDuration(setGroup.workDuration ?? 0)) on / \(formatDuration(setGroup.intervalRestDuration ?? 0)) off)")
                    .caption(color: AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let value: String
    let label: String?
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .subheadline(color: color)
                .fontWeight(.semibold)
            if let label = label {
                Text(label)
                    .caption2(color: AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}
