//
//  SetGroupFormView.swift
//  gym app
//
//  Form for creating/editing a set group within an exercise
//

import SwiftUI

struct SetGroupFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var libraryService = LibraryService.shared

    let exerciseType: ExerciseType
    let cardioMetric: CardioMetric
    let mobilityTracking: MobilityTracking
    let distanceUnit: DistanceUnit
    let implementIds: Set<UUID>
    let isBodyweight: Bool
    let existingSetGroup: SetGroup?
    let onSave: (SetGroup) -> Void

    @State private var sets: Int = 1
    @State private var targetReps: Int = 0
    @State private var targetWeight: String = ""
    @State private var targetRPE: Int = 0
    @State private var targetDuration: Int = 0
    @State private var targetDistance: String = ""
    @State private var targetHoldTime: Int = 0
    @State private var restPeriod: Int = 90
    @State private var notes: String = ""

    // Implement measurable inputs
    @State private var implementMeasurableStringValue: String = ""

    // Interval mode
    @State private var isInterval: Bool = false
    @State private var workDuration: Int = 30
    @State private var intervalRestDuration: Int = 30

    private var isEditing: Bool { existingSetGroup != nil }

    /// Returns the primary implement's string-based measurable info (like band color)
    private var implementStringMeasurable: ImplementMeasurableInfo? {
        for id in implementIds {
            guard let implement = libraryService.getImplement(id: id) else { continue }
            if let stringMeasurable = implement.measurableArray.first(where: { $0.isStringBased }) {
                return ImplementMeasurableInfo(
                    implementName: implement.name,
                    measurableName: stringMeasurable.name,
                    unit: stringMeasurable.unit,
                    isStringBased: true
                )
            }
        }
        return nil
    }

    /// Returns true if this exercise uses box (for height input)
    private var usesBox: Bool {
        for id in implementIds {
            guard let implement = libraryService.getImplement(id: id) else { continue }
            if implement.name.lowercased().contains("box") {
                return true
            }
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Interval Mode Toggle
                FormSection(title: "Mode", icon: "timer", iconColor: isInterval ? AppColors.accentCyan : AppColors.textTertiary) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "repeat")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 24)

                        Toggle("Interval Mode", isOn: $isInterval)
                            .tint(AppColors.accentCyan)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.cardBackground)

                    if isInterval {
                        Text("Timer will auto-run through all rounds with work/rest periods")
                            .font(.caption)
                            .foregroundColor(AppColors.accentCyan)
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.bottom, AppSpacing.sm)
                    }
                }

                if isInterval {
                    intervalModeSection
                } else {
                    normalModeSection
                }

                // Notes Section
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextField("Notes (e.g., 'top set', 'back-off')", text: $notes)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.cardBackground)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Set Group" : "Add Set Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    saveSetGroup()
                }
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accentBlue)
            }
        }
        .onAppear {
            loadExistingData()
        }
    }

    // MARK: - Interval Mode Section

    @ViewBuilder
    private var intervalModeSection: some View {
        // Rounds
        FormSection(title: "Rounds", icon: "repeat.circle", iconColor: AppColors.accentCyan) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Rounds")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Stepper("\(sets)", value: $sets, in: 1...50)
                    .fixedSize()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
        }

        // Work Period
        FormSection(title: "Work Period", icon: "flame", iconColor: AppColors.accentBlue) {
            TimePickerView(totalSeconds: $workDuration, maxMinutes: 10, label: "Work Time", secondsStep: 5)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.cardBackground)
        }

        // Rest Period
        FormSection(title: "Rest Period", icon: "pause.circle", iconColor: AppColors.accentTeal) {
            TimePickerView(totalSeconds: $intervalRestDuration, maxMinutes: 10, label: "Rest Time", secondsStep: 5)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.cardBackground)
        }

        // Total duration preview
        FormSection(title: "Summary", icon: "clock", iconColor: AppColors.textSecondary) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "hourglass")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Total Duration")
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(formatTotalDuration())
                    .font(.headline)
                    .foregroundColor(AppColors.accentCyan)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
        }
    }

    // MARK: - Normal Mode Section

    @ViewBuilder
    private var normalModeSection: some View {
        // Sets
        FormSection(title: "Sets", icon: "number.square", iconColor: AppColors.accentBlue) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Number of Sets")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Stepper("\(sets)", value: $sets, in: 1...20)
                    .fixedSize()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
        }

        // Target
        FormSection(title: "Target", icon: "target", iconColor: AppColors.accentCyan) {
            VStack(spacing: 0) {
                targetFieldsForExerciseType
            }
            .background(AppColors.cardBackground)
        }

        // Rest Between Sets
        FormSection(title: "Rest Between Sets", icon: "pause.circle", iconColor: AppColors.accentTeal) {
            TimePickerView(totalSeconds: $restPeriod, maxMinutes: 5, label: "Rest Period", compact: true)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.cardBackground)
        }
    }

    @ViewBuilder
    private var targetFieldsForExerciseType: some View {
        switch exerciseType {
        case .strength:
            // Reps row
            styledRow(icon: "number", label: "Reps") {
                Stepper("\(targetReps)", value: $targetReps, in: 0...100)
                    .fixedSize()
            }

            FormDivider()

            // Weight/equipment input
            if let stringMeasurable = implementStringMeasurable {
                styledRow(icon: "tag", label: stringMeasurable.measurableName) {
                    TextField("Enter \(stringMeasurable.measurableName.lowercased())", text: $implementMeasurableStringValue)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                }
            } else if isBodyweight {
                styledRow(icon: "figure.stand", label: "Added Weight") {
                    HStack(spacing: AppSpacing.xs) {
                        Text("BW +")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $targetWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("lbs")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } else if usesBox {
                styledRow(icon: "square.stack.3d.up", label: "Height") {
                    HStack(spacing: AppSpacing.xs) {
                        TextField("0", text: $targetWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("in")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } else {
                styledRow(icon: "scalemass", label: "Weight") {
                    HStack(spacing: AppSpacing.xs) {
                        TextField("0", text: $targetWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("lbs")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            FormDivider()

            // RPE row
            styledRow(icon: "gauge.with.dots.needle.67percent", label: "RPE") {
                Picker("", selection: $targetRPE) {
                    Text("None").tag(0)
                    ForEach(5...10, id: \.self) { rpe in
                        Text("\(rpe)").tag(rpe)
                    }
                }
                .tint(AppColors.accentCyan)
            }

        case .cardio:
            if cardioMetric.tracksTime {
                TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, maxHours: 4, label: "Target Duration")
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
            }

            if cardioMetric.tracksDistance {
                if cardioMetric.tracksTime {
                    FormDivider()
                }
                distanceInputSection
            }

        case .isometric:
            TimePickerView(totalSeconds: $targetHoldTime, maxMinutes: 5, label: "Hold Time")
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)

        case .mobility:
            if mobilityTracking.tracksReps {
                styledRow(icon: "number", label: "Reps") {
                    Stepper("\(targetReps)", value: $targetReps, in: 1...50)
                        .fixedSize()
                }
            }
            if mobilityTracking.tracksDuration {
                if mobilityTracking.tracksReps {
                    FormDivider()
                }
                TimePickerView(totalSeconds: $targetDuration, maxMinutes: 10, label: "Duration")
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
            }

        case .explosive:
            styledRow(icon: "number", label: "Reps") {
                Stepper("\(targetReps)", value: $targetReps, in: 1...20)
                    .fixedSize()
            }

        case .recovery:
            TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, maxHours: 4, label: "Duration")
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
        }
    }

    private func styledRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            content()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    @ViewBuilder
    private var distanceInputSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Distance")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: AppSpacing.xs) {
                    TextField("0", text: $targetDistance)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(distanceUnit.abbreviation)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.md)

            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(distanceUnit.presets, id: \.self) { preset in
                        Button {
                            targetDistance = formatPreset(preset)
                        } label: {
                            Text("\(formatPreset(preset))\(distanceUnit.abbreviation)")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(AppColors.surfaceLight)
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColors.border, lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
            }
            .padding(.bottom, AppSpacing.md)
        }
    }

    // MARK: - Actions

    private func saveSetGroup() {
        // Determine implement measurable info for storage
        let measurableLabel = implementStringMeasurable?.measurableName
        let measurableUnit = implementStringMeasurable?.unit
        let measurableStringValue = !implementMeasurableStringValue.isEmpty ? implementMeasurableStringValue : nil

        let setGroup = SetGroup(
            id: existingSetGroup?.id ?? UUID(),
            sets: sets,
            targetReps: !isInterval && (exerciseType == .strength || (exerciseType == .mobility && mobilityTracking.tracksReps) || exerciseType == .explosive) ? (targetReps > 0 ? targetReps : nil) : nil,
            targetWeight: !isInterval && implementStringMeasurable == nil ? Double(targetWeight) : nil,
            targetRPE: !isInterval && targetRPE > 0 ? targetRPE : nil,
            targetDuration: !isInterval && ((exerciseType == .cardio && cardioMetric.tracksTime) || (exerciseType == .mobility && mobilityTracking.tracksDuration) || exerciseType == .recovery) && targetDuration > 0 ? targetDuration : nil,
            targetDistance: !isInterval && cardioMetric.tracksDistance ? Double(targetDistance) : nil,
            targetDistanceUnit: !isInterval && cardioMetric.tracksDistance ? distanceUnit : nil,
            targetHoldTime: !isInterval && targetHoldTime > 0 ? targetHoldTime : nil,
            restPeriod: !isInterval ? restPeriod : nil,
            notes: notes.isEmpty ? nil : notes,
            isInterval: isInterval,
            workDuration: isInterval ? workDuration : nil,
            intervalRestDuration: isInterval ? intervalRestDuration : nil,
            implementMeasurableLabel: measurableLabel,
            implementMeasurableUnit: measurableUnit,
            implementMeasurableStringValue: measurableStringValue
        )
        onSave(setGroup)
        dismiss()
    }

    private func loadExistingData() {
        if let existing = existingSetGroup {
            sets = existing.sets
            targetReps = existing.targetReps ?? 0
            targetWeight = existing.targetWeight.map { formatWeight($0) } ?? ""
            targetRPE = existing.targetRPE ?? 0
            targetDuration = existing.targetDuration ?? 0
            targetDistance = existing.targetDistance.map { formatPreset($0) } ?? ""
            targetHoldTime = existing.targetHoldTime ?? 0
            restPeriod = existing.restPeriod ?? 90
            notes = existing.notes ?? ""
            // Interval fields
            isInterval = existing.isInterval
            workDuration = existing.workDuration ?? 30
            intervalRestDuration = existing.intervalRestDuration ?? 30
            // Implement measurable fields
            implementMeasurableStringValue = existing.implementMeasurableStringValue ?? ""
        }
    }

    // MARK: - Formatting Helpers

    private func formatWeight(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func formatTotalDuration() -> String {
        let total = (workDuration * sets) + (intervalRestDuration * max(0, sets - 1))
        let mins = total / 60
        let secs = total % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        }
        return "\(secs)s"
    }

    private func formatPreset(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }
}
