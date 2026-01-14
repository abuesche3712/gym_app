//
//  SetGroupFormView.swift
//  gym app
//
//  Form for creating/editing a set group within an exercise
//

import SwiftUI

struct SetGroupFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseType: ExerciseType
    let cardioMetric: CardioMetric
    let distanceUnit: DistanceUnit
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

    private var isEditing: Bool { existingSetGroup != nil }

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
            TextField("Target Weight (lbs)", text: $targetWeight)
                .keyboardType(.decimalPad)
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

        case .mobility:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)

        case .explosive:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...20)
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
        let setGroup = SetGroup(
            id: existingSetGroup?.id ?? UUID(),
            sets: sets,
            targetReps: !isInterval && (exerciseType == .strength || exerciseType == .mobility || exerciseType == .explosive) ? (targetReps > 0 ? targetReps : nil) : nil,
            targetWeight: !isInterval ? Double(targetWeight) : nil,
            targetRPE: !isInterval && targetRPE > 0 ? targetRPE : nil,
            targetDuration: !isInterval && cardioMetric.tracksTime && targetDuration > 0 ? targetDuration : nil,
            targetDistance: !isInterval && cardioMetric.tracksDistance ? Double(targetDistance) : nil,
            targetDistanceUnit: !isInterval && cardioMetric.tracksDistance ? distanceUnit : nil,
            targetHoldTime: !isInterval && targetHoldTime > 0 ? targetHoldTime : nil,
            restPeriod: !isInterval ? restPeriod : nil,
            notes: notes.isEmpty ? nil : notes,
            isInterval: isInterval,
            workDuration: isInterval ? workDuration : nil,
            intervalRestDuration: isInterval ? intervalRestDuration : nil
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

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
