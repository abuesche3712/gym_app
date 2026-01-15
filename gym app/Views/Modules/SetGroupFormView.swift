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
    let distanceUnit: DistanceUnit
    let implementIds: Set<UUID>
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

    // Interval mode
    @State private var isInterval: Bool = false
    @State private var workDuration: Int = 30
    @State private var intervalRestDuration: Int = 30

    // Implement-specific measurable
    @State private var implementMeasurableValue: String = ""
    @State private var implementMeasurableStringValue: String = ""

    private var isEditing: Bool { existingSetGroup != nil }

    /// Determine the primary implement measurable to show
    private var primaryImplementMeasurable: (label: String, unit: String, isStringBased: Bool)? {
        // Find the first non-weight implement measurable
        for implementId in implementIds {
            guard let implement = libraryService.getImplement(id: implementId) else { continue }
            let measurables = implement.measurableArray

            // Skip weight-based implements (Barbell, Dumbbell, Cable, Machine, Kettlebell)
            if measurables.contains(where: { $0.name == "Weight" || $0.name == "Added Weight" }) {
                continue
            }

            // Found a non-weight implement - use its measurable
            if let measurable = measurables.first {
                return (label: measurable.name, unit: measurable.unit, isStringBased: measurable.isStringBased)
            }
        }
        return nil
    }

    /// Check if we should show weight field (no special implement measurable)
    private var showWeightField: Bool {
        primaryImplementMeasurable == nil
    }

    var body: some View {
        Form {
            // Interval Mode Toggle
            Section {
                Toggle(isOn: $isInterval) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(isInterval ? .orange : .secondary)
                        Text("Interval Mode")
                    }
                }
            } footer: {
                if isInterval {
                    Text("Timer will auto-run through all rounds with work/rest periods")
                        .foregroundColor(.orange)
                }
            }

            if isInterval {
                intervalModeSection
            } else {
                normalModeSection
            }

            Section("Notes") {
                TextField("Notes (e.g., 'top set', 'back-off')", text: $notes)
            }
        }
        .navigationTitle(isEditing ? "Edit Set Group" : "Add Set Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    saveSetGroup()
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
    }

    // MARK: - Interval Mode Section

    @ViewBuilder
    private var intervalModeSection: some View {
        Section("Rounds") {
            Stepper("Rounds: \(sets)", value: $sets, in: 1...50)
        }

        Section("Work Period") {
            TimePickerView(totalSeconds: $workDuration, maxMinutes: 10, label: "Work Time", secondsStep: 5)
        }

        Section("Rest Period") {
            TimePickerView(totalSeconds: $intervalRestDuration, maxMinutes: 10, label: "Rest Time", secondsStep: 5)
        }

        // Total duration preview
        Section {
            HStack {
                Text("Total Duration")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTotalDuration())
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Normal Mode Section

    @ViewBuilder
    private var normalModeSection: some View {
        Section("Sets") {
            Stepper("Sets: \(sets)", value: $sets, in: 1...20)
        }

        Section("Target") {
            targetFieldsForExerciseType
        }

        Section("Rest Between Sets") {
            TimePickerView(totalSeconds: $restPeriod, maxMinutes: 5, label: "Rest Period", compact: true)
        }
    }

    @ViewBuilder
    private var targetFieldsForExerciseType: some View {
        switch exerciseType {
        case .strength:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 0...100)

            // Show implement-specific measurable OR weight
            if let measurable = primaryImplementMeasurable {
                if measurable.isStringBased {
                    // String-based measurable (e.g., Band Color)
                    TextField("\(measurable.label)", text: $implementMeasurableStringValue)
                } else {
                    // Numeric measurable (e.g., Box Height)
                    let unitLabel = measurable.unit.isEmpty ? "" : " (\(measurable.unit))"
                    TextField("\(measurable.label)\(unitLabel)", text: $implementMeasurableValue)
                        .keyboardType(.decimalPad)
                }
            } else {
                // Default weight field
                TextField("Target Weight (lbs)", text: $targetWeight)
                    .keyboardType(.decimalPad)
            }

            Picker("RPE", selection: $targetRPE) {
                Text("None").tag(0)
                ForEach(5...10, id: \.self) { rpe in
                    Text("\(rpe)").tag(rpe)
                }
            }

        case .cardio:
            if cardioMetric.tracksTime {
                TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, label: "Target Duration")
            }

            if cardioMetric.tracksDistance {
                distanceInputSection
            }

        case .isometric:
            TimePickerView(totalSeconds: $targetHoldTime, maxMinutes: 5, label: "Hold Time")
            implementMeasurableField

        case .mobility:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)
            implementMeasurableField

        case .explosive:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...20)
            implementMeasurableField

        case .recovery:
            TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, label: "Duration")
        }
    }

    /// Reusable implement measurable field (for non-strength exercise types)
    @ViewBuilder
    private var implementMeasurableField: some View {
        if let measurable = primaryImplementMeasurable {
            if measurable.isStringBased {
                TextField("\(measurable.label)", text: $implementMeasurableStringValue)
            } else {
                let unitLabel = measurable.unit.isEmpty ? "" : " (\(measurable.unit))"
                TextField("\(measurable.label)\(unitLabel)", text: $implementMeasurableValue)
                    .keyboardType(.decimalPad)
            }
        }
    }

    @ViewBuilder
    private var distanceInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Distance (\(distanceUnit.abbreviation))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Enter distance", text: $targetDistance)
                .keyboardType(.decimalPad)
                .font(.title2)

            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(distanceUnit.presets, id: \.self) { preset in
                        Button {
                            targetDistance = formatPreset(preset)
                        } label: {
                            Text("\(formatPreset(preset))\(distanceUnit.abbreviation)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveSetGroup() {
        // Determine implement measurable values
        let measurable = primaryImplementMeasurable
        let implLabel = measurable?.label
        let implUnit = measurable?.unit
        let implValue: Double? = measurable != nil && !measurable!.isStringBased ? Double(implementMeasurableValue) : nil
        let implStringValue: String? = measurable?.isStringBased == true && !implementMeasurableStringValue.isEmpty ? implementMeasurableStringValue : nil

        // Only use targetWeight if we're NOT using an implement measurable
        let weightValue: Double? = measurable == nil ? Double(targetWeight) : nil

        let setGroup = SetGroup(
            id: existingSetGroup?.id ?? UUID(),
            sets: sets,
            targetReps: !isInterval && (exerciseType == .strength || exerciseType == .mobility || exerciseType == .explosive) ? (targetReps > 0 ? targetReps : nil) : nil,
            targetWeight: !isInterval ? weightValue : nil,
            targetRPE: !isInterval && targetRPE > 0 ? targetRPE : nil,
            targetDuration: !isInterval && cardioMetric.tracksTime && targetDuration > 0 ? targetDuration : nil,
            targetDistance: !isInterval && cardioMetric.tracksDistance ? Double(targetDistance) : nil,
            targetDistanceUnit: !isInterval && cardioMetric.tracksDistance ? distanceUnit : nil,
            targetHoldTime: !isInterval && targetHoldTime > 0 ? targetHoldTime : nil,
            restPeriod: !isInterval ? restPeriod : nil,
            notes: notes.isEmpty ? nil : notes,
            isInterval: isInterval,
            workDuration: isInterval ? workDuration : nil,
            intervalRestDuration: isInterval ? intervalRestDuration : nil,
            implementMeasurableLabel: implLabel,
            implementMeasurableUnit: implUnit,
            implementMeasurableValue: implValue,
            implementMeasurableStringValue: implStringValue
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
            implementMeasurableValue = existing.implementMeasurableValue.map { formatWeight($0) } ?? ""
            implementMeasurableStringValue = existing.implementMeasurableStringValue ?? ""
        }
    }

    // MARK: - Formatting Helpers

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
