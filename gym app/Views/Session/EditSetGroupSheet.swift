//
//  EditSetGroupSheet.swift
//  gym app
//
//  Sheet for editing a set group within an exercise
//

import SwiftUI

struct EditSetGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var libraryService = LibraryService.shared
    @Binding var setGroup: EditableSetGroup

    let exerciseType: ExerciseType
    let cardioMetric: CardioTracking
    let mobilityTracking: MobilityTracking
    let distanceUnit: DistanceUnit
    let implementIds: Set<UUID>

    @State private var sets: Int = 3
    @State private var targetWeight: String = ""
    @State private var targetReps: Int = 10
    @State private var targetDuration: Int = 0
    @State private var targetHoldTime: Int = 0
    @State private var targetDistance: String = ""
    @State private var restPeriod: Int = 90
    @State private var showTimePicker = false
    @State private var editableSets: [SetData] = []
    @State private var editingSetIndex: Int? = nil
    @State private var isUnilateral: Bool = false
    @State private var trackRPE: Bool = true

    // Equipment-specific measurable values
    @State private var implementMeasurableValues: [String: MeasurableValue] = [:]

    struct MeasurableValue {
        var numericValue: String = ""
        var stringValue: String = ""
        let isStringBased: Bool
        let unit: String
        let implementName: String
    }

    /// Returns implement-specific measurables to display
    private var implementSpecificMeasurables: [(key: String, value: MeasurableValue)] {
        var result: [String: MeasurableValue] = [:]

        for id in implementIds {
            guard let implement = libraryService.getImplement(id: id) else { continue }
            for measurable in implement.measurableArray {
                let key = "\(implement.name)_\(measurable.name)"
                if implementMeasurableValues[key] == nil {
                    result[key] = MeasurableValue(
                        numericValue: "",
                        stringValue: "",
                        isStringBased: measurable.isStringBased,
                        unit: measurable.unit,
                        implementName: implement.name
                    )
                }
            }
        }

        var merged = implementMeasurableValues
        for (key, value) in result {
            if merged[key] == nil {
                merged[key] = value
            }
        }

        let validKeys = result.keys
        return merged.filter { validKeys.contains($0.key) }.sorted { $0.key < $1.key }
    }

    private func extractMeasurableName(from key: String) -> String {
        key.components(separatedBy: "_").last ?? key
    }

    private var hasIndividualSets: Bool {
        !setGroup.allSets.isEmpty
    }

    /// Minimum sets based on completed logical sets (accounting for unilateral pairs)
    private var completedLogicalSetsMin: Int {
        setGroup.isUnilateral ? setGroup.completedSetsCount / 2 : setGroup.completedSetsCount
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sets") {
                    Stepper("Total Sets: \(sets)", value: $sets, in: max(1, completedLogicalSetsMin)...20)

                    if setGroup.completedSetsCount > 0 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text("\(completedLogicalSetsMin) sets already completed")
                                .caption(color: .secondary)
                        }
                    }
                }

                // Show individual sets if available (history editing)
                if hasIndividualSets {
                    Section("Individual Sets") {
                        ForEach(Array(editableSets.enumerated()), id: \.element.id) { index, set in
                            Button {
                                editingSetIndex = index
                            } label: {
                                individualSetRow(set, index: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Targets") {
                    targetFieldsForExerciseType
                }

                Section("Rest Between Sets") {
                    Picker("Rest", selection: $restPeriod) {
                        ForEach([15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 240, 300], id: \.self) { seconds in
                            Text(formatRestTime(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                // Equipment Attributes (if any)
                if !implementSpecificMeasurables.isEmpty && exerciseType == .strength {
                    Section("Equipment Attributes") {
                        ForEach(Array(implementSpecificMeasurables.enumerated()), id: \.element.key) { index, item in
                            let measurable = item.value
                            let displayLabel = "\(measurable.implementName) - \(extractMeasurableName(from: item.key))"

                            HStack {
                                Text(displayLabel)
                                Spacer()
                                if measurable.isStringBased {
                                    TextField("Enter value", text: Binding(
                                        get: { implementMeasurableValues[item.key]?.stringValue ?? "" },
                                        set: { newValue in
                                            var updated = implementMeasurableValues[item.key] ?? measurable
                                            updated.stringValue = newValue
                                            implementMeasurableValues[item.key] = updated
                                        }
                                    ))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                } else {
                                    HStack(spacing: 4) {
                                        TextField("0", text: Binding(
                                            get: { implementMeasurableValues[item.key]?.numericValue ?? "" },
                                            set: { newValue in
                                                var updated = implementMeasurableValues[item.key] ?? measurable
                                                updated.numericValue = newValue
                                                implementMeasurableValues[item.key] = updated
                                            }
                                        ))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)

                                        Text(measurable.unit)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Options (unilateral, RPE tracking)
                Section("Options") {
                    if exerciseType != .cardio {
                        Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                            .tint(AppColors.accent3)
                    }
                    if exerciseType == .strength || exerciseType == .explosive {
                        Toggle("Track RPE", isOn: $trackRPE)
                            .tint(AppColors.dominant)
                    }
                }
            }
            .navigationTitle("Edit Set Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.dominant)
                }
            }
            .onAppear { loadValues() }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(totalSeconds: $targetDuration, title: "Target Time")
            }
            .sheet(item: Binding(
                get: { editingSetIndex.map { EditingIndex(id: $0) } },
                set: { editingSetIndex = $0?.id }
            )) { editing in
                EditIndividualSetSheet(
                    set: $editableSets[editing.index],
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit
                )
            }
        }
        .presentationDetents([(hasIndividualSets || !implementSpecificMeasurables.isEmpty) ? .large : .medium])
    }

    @ViewBuilder
    private func individualSetRow(_ set: SetData, index: Int) -> some View {
        HStack {
            // Set number and completion status
            HStack(spacing: 8) {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.completed ? AppColors.success : .secondary)

                Text("Set \(index + 1)")
                    .subheadline()
                    .fontWeight(.medium)
            }

            Spacer()

            // Set data preview
            Text(setDataPreview(set))
                .subheadline(color: .secondary)

            Image(systemName: "chevron.right")
                .caption(color: AppColors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func setDataPreview(_ set: SetData) -> String {
        switch exerciseType {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                return "\(formatWeight(weight)) × \(reps)"
            } else if let reps = set.reps {
                return "\(reps) reps"
            }
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 { parts.append(formatDuration(duration)) }
            if let distance = set.distance, distance > 0 { parts.append("\(formatDistanceValue(distance)) \(distanceUnit.abbreviation)") }
            return parts.joined(separator: " - ")
        case .isometric:
            if let holdTime = set.holdTime { return "\(holdTime)s hold" }
        case .mobility:
            var parts: [String] = []
            if let reps = set.reps { parts.append("\(reps) reps") }
            if let duration = set.duration, duration > 0 { parts.append(formatDuration(duration)) }
            return parts.joined(separator: " - ")
        case .explosive:
            if let reps = set.reps { return "\(reps) reps" }
        case .recovery:
            if let duration = set.duration { return formatDuration(duration) }
        }
        return set.completed ? "Completed" : "Incomplete"
    }

    @ViewBuilder
    private var targetFieldsForExerciseType: some View {
        switch exerciseType {
        case .strength:
            HStack {
                Text("Weight")
                Spacer()
                TextField("0", text: $targetWeight)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("lbs")
                    .foregroundColor(.secondary)
            }
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)

        case .cardio:
            if cardioMetric.tracksTime {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(targetDuration > 0 ? formatDuration(targetDuration) : "Not set")
                            .foregroundColor(targetDuration > 0 ? .primary : .secondary)
                    }
                }
            }
            if cardioMetric.tracksDistance {
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("0", text: $targetDistance)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(distanceUnit.abbreviation)
                        .foregroundColor(.secondary)
                }
            }

        case .isometric:
            Stepper("Hold: \(targetHoldTime)s", value: $targetHoldTime, in: 5...300, step: 5)

        case .mobility:
            if mobilityTracking.tracksReps {
                Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)
            }
            if mobilityTracking.tracksDuration {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(targetDuration > 0 ? formatDuration(targetDuration) : "Not set")
                            .foregroundColor(targetDuration > 0 ? .primary : .secondary)
                    }
                }
            }

        case .explosive:
            Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)

        case .recovery:
            Button {
                showTimePicker = true
            } label: {
                HStack {
                    Text("Duration")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(targetDuration > 0 ? formatDuration(targetDuration) : "Not set")
                        .foregroundColor(targetDuration > 0 ? .primary : .secondary)
                }
            }
        }
    }

    private func loadValues() {
        sets = setGroup.sets
        targetWeight = setGroup.targetWeight.map { formatWeight($0) } ?? ""
        targetReps = setGroup.targetReps ?? 10
        targetDuration = setGroup.targetDuration ?? 0
        targetHoldTime = setGroup.targetHoldTime ?? 30
        targetDistance = setGroup.targetDistance.map { formatDistanceValue($0) } ?? ""
        restPeriod = setGroup.restPeriod
        isUnilateral = setGroup.isUnilateral
        trackRPE = setGroup.trackRPE
        editableSets = setGroup.allSets
    }

    private func saveChanges() {
        setGroup.sets = sets
        setGroup.targetWeight = Double(targetWeight)
        setGroup.targetReps = targetReps
        setGroup.targetDuration = targetDuration
        setGroup.targetHoldTime = targetHoldTime
        setGroup.targetDistance = Double(targetDistance)
        setGroup.restPeriod = restPeriod
        setGroup.isUnilateral = isUnilateral
        setGroup.trackRPE = trackRPE
        // Update allSets if we were editing individual sets
        if !editableSets.isEmpty {
            setGroup.allSets = editableSets
            setGroup.completedSets = editableSets.filter { $0.completed }
            setGroup.completedSetsCount = setGroup.completedSets.count
        }
        dismiss()
    }

    private func formatRestTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds % 60 == 0 {
            let minutes = seconds / 60
            return "\(minutes) min"
        } else {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes):\(String(format: "%02d", secs))"
        }
    }
}
