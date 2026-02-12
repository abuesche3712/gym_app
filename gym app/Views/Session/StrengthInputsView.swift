//
//  StrengthInputsView.swift
//  gym app
//
//  Strength exercise input fields (weight/reps)
//

import SwiftUI

struct StrengthInputs: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let flatSet: FlatSet
    let exercise: SessionExercise

    @Binding var inputWeight: String
    @Binding var inputReps: String
    @Binding var inputRPE: String
    @Binding var inputHeight: String
    @Binding var inputBandColor: String
    @Binding var inputMeasurableValues: [String: String]

    var focusedField: FocusState<SetRowFieldType?>.Binding

    private var timerRunning: Bool {
        sessionViewModel.isExerciseTimerRunning && sessionViewModel.exerciseTimerSetId == flatSet.id
    }

    private var timerSecondsRemaining: Int {
        timerRunning && !sessionViewModel.exerciseTimerIsStopwatch ? sessionViewModel.exerciseTimerSeconds : 0
    }

    var body: some View {
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
                            .body(color: AppColors.accent2)
                            .fontWeight(.bold)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.accent2.opacity(0.12))
                            )

                        Text("AMRAP")
                            .caption2(color: AppColors.accent2)
                            .fontWeight(.medium)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }

            // Primary inputs: implement measurable × reps OR weight × reps
            if let stringMeasurable = exercise.implementStringMeasurable {
                // String-based implement input (e.g., band color)
                VStack(spacing: 4) {
                    TextField(stringMeasurable.measurableName, text: $inputBandColor)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused(focusedField, equals: .bandColor)

                    Text(stringMeasurable.implementName.lowercased())
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if exercise.usesBox {
                // Box height input
                VStack(spacing: 4) {
                    TextField("0", text: $inputHeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused(focusedField, equals: .height)

                    Text("in")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            } else if exercise.isBodyweight {
                // Bodyweight exercise
                if exercise.tracksAddedWeight {
                    // Show "BW +" with added weight input
                    HStack(spacing: 4) {
                        Text("BW")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.dominant)

                        Text("+")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)

                        VStack(spacing: 4) {
                            TextField("0", text: $inputWeight)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .frame(width: 44)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                                .focused(focusedField, equals: .weight)

                            Text("lbs")
                                .caption2(color: AppColors.textTertiary)
                                .fontWeight(.medium)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                } else {
                    // Just show "BW" badge without added weight input
                    VStack(spacing: 4) {
                        Text("BW")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.dominant)
                            )

                        Text("body")
                            .caption2(color: AppColors.textTertiary)
                            .fontWeight(.medium)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                // Standard weight input
                VStack(spacing: 4) {
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused(focusedField, equals: .weight)

                    Text("lbs")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)

                    // Progression suggestion hint
                    if let suggestion = exercise.progressionSuggestion,
                       suggestion.metric == .weight,
                       !flatSet.setData.completed {
                        Text(suggestionHintText(for: suggestion))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(directionColor(for: suggestion))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Text("×")
                .subheadline(color: AppColors.textTertiary)
                .fontWeight(.medium)

            // Reps input box
            VStack(spacing: 4) {
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                    .focused(focusedField, equals: .reps)

                Text(flatSet.isAMRAP ? "AMRAP" : "reps")
                    .caption2(color: flatSet.isAMRAP ? AppColors.accent2 : AppColors.textTertiary)
                    .fontWeight(.medium)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))
                        .focused(focusedField, equals: .rpe)
                        .onChange(of: inputRPE) { _, newValue in
                            // Validate RPE is 1-10
                            if let rpe = Int(newValue), rpe > 10 {
                                inputRPE = "10"
                            }
                        }

                    Text("RPE")
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
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
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: measurable.isStringBased ? 60 : 48)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePrimary))

            Text(measurable.unit)
                .caption2(color: AppColors.textTertiary)
                .fontWeight(.medium)
        }
        .fixedSize(horizontal: true, vertical: false)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "timer")
                            .body(color: AppColors.textSecondary)
                            .fontWeight(.medium)
                    }
                }

                Text(formatDurationVerbose(timeLimit))
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
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

    private func directionSymbol(for suggestion: ProgressionSuggestion) -> String {
        if suggestion.percentageApplied > 0.01 { return "▲" }
        if suggestion.percentageApplied < -0.01 { return "▼" }
        return "■"
    }

    private func directionColor(for suggestion: ProgressionSuggestion) -> Color {
        if suggestion.percentageApplied > 0.01 { return AppColors.success }
        if suggestion.percentageApplied < -0.01 { return AppColors.warning }
        return AppColors.dominant
    }

    private func suggestionHintText(for suggestion: ProgressionSuggestion) -> String {
        if let label = suggestion.confidenceLabel {
            return "\(directionSymbol(for: suggestion)) \(suggestion.formattedValue) · \(label)"
        }
        return "\(directionSymbol(for: suggestion)) \(suggestion.formattedValue)"
    }
}

// MARK: - Field Type Enum

enum SetRowFieldType: Hashable {
    case weight, reps, distance, height, rpe, temperature, bandColor
}
