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

    // Interval mode
    @State private var isInterval: Bool = false
    @State private var workDuration: Int = 30
    @State private var intervalRestDuration: Int = 30

    // AMRAP mode
    @State private var isAMRAP: Bool = false
    @State private var amrapTimeLimit: Int? = nil

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
                // Mode selection (for applicable exercise types)
                if exerciseType == .strength || exerciseType == .explosive || exerciseType == .cardio {
                    Section("Mode") {
                        Toggle("Interval Mode", isOn: Binding(
                            get: { isInterval },
                            set: { newValue in
                                isInterval = newValue
                                if newValue { isAMRAP = false }
                            }
                        ))
                        .tint(AppColors.dominant)

                        if isInterval {
                            Text("Timer auto-runs through all rounds with work/rest periods")
                                .caption(color: AppColors.dominant)
                        }

                        if exerciseType == .strength || exerciseType == .explosive {
                            Toggle("AMRAP Mode", isOn: Binding(
                                get: { isAMRAP },
                                set: { newValue in
                                    isAMRAP = newValue
                                    if newValue { isInterval = false }
                                }
                            ))
                            .tint(AppColors.accent2)

                            if isAMRAP {
                                Text("As Many Reps As Possible - log max reps achieved")
                                    .caption(color: AppColors.accent2)
                            }
                        }
                    }
                }

                // Interval-specific settings
                if isInterval {
                    Section("Interval Settings") {
                        Stepper("Rounds: \(sets)", value: $sets, in: max(1, completedLogicalSetsMin)...50)

                        HStack {
                            Text("Work Duration")
                            Spacer()
                            Picker("Work", selection: $workDuration) {
                                ForEach([10, 15, 20, 25, 30, 35, 40, 45, 60, 90, 120], id: \.self) { seconds in
                                    Text(formatRestTime(seconds)).tag(seconds)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("Rest Duration")
                            Spacer()
                            Picker("Rest", selection: $intervalRestDuration) {
                                ForEach([5, 10, 15, 20, 25, 30, 45, 60, 90], id: \.self) { seconds in
                                    Text(formatRestTime(seconds)).tag(seconds)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Total duration preview
                        HStack {
                            Text("Total Duration")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatIntervalTotalDuration())
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.dominant)
                        }
                    }
                } else if isAMRAP {
                    // AMRAP-specific settings
                    Section("AMRAP Settings") {
                        Stepper("Sets: \(sets)", value: $sets, in: max(1, completedLogicalSetsMin)...20)

                        Picker("Time Limit", selection: $amrapTimeLimit) {
                            Text("No Limit").tag(nil as Int?)
                            Text("30 seconds").tag(30 as Int?)
                            Text("45 seconds").tag(45 as Int?)
                            Text("60 seconds").tag(60 as Int?)
                            Text("90 seconds").tag(90 as Int?)
                            Text("2 minutes").tag(120 as Int?)
                            Text("3 minutes").tag(180 as Int?)
                        }

                        if amrapTimeLimit == nil {
                            Text("Track max reps with no time constraint")
                                .caption(color: .secondary)
                        }
                    }
                } else {
                    // Normal mode - show sets section
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
                }

                // Show individual sets if available (history editing)
                if hasIndividualSets && !isInterval {
                    Section("Individual Sets") {
                        if isUnilateral {
                            // Group by set number so L/R pairs are shown together
                            let pairedSets = groupEditableSetsForDisplay()
                            ForEach(Array(pairedSets.enumerated()), id: \.offset) { pairIndex, pair in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set \(pairIndex + 1)")
                                        .subheadline()
                                        .fontWeight(.medium)
                                    ForEach(pair, id: \.id) { set in
                                        let setIndex = editableSets.firstIndex(where: { $0.id == set.id }) ?? 0
                                        Button {
                                            editingSetIndex = setIndex
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text(set.side?.abbreviation ?? "?")
                                                    .caption(color: set.side == .left ? AppColors.dominant : AppColors.accent2)
                                                    .fontWeight(.bold)
                                                    .frame(width: 20)
                                                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(set.completed ? AppColors.success : .secondary)
                                                Text(setDataPreview(set))
                                                    .subheadline(color: .secondary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .caption(color: AppColors.textTertiary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
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
                }

                // Targets section (hide for interval mode)
                if !isInterval {
                    Section("Targets") {
                        targetFieldsForExerciseType
                    }
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

        // Load interval mode values
        isInterval = setGroup.isInterval
        workDuration = setGroup.workDuration ?? 30
        intervalRestDuration = setGroup.intervalRestDuration ?? 30

        // Load AMRAP mode values
        isAMRAP = setGroup.isAMRAP
        amrapTimeLimit = setGroup.amrapTimeLimit

        // Load equipment measurable values
        for target in setGroup.implementMeasurables {
            guard let implement = libraryService.getImplement(id: target.implementId) else { continue }
            let key = "\(implement.name)_\(target.measurableName)"
            implementMeasurableValues[key] = MeasurableValue(
                numericValue: target.targetValue.map { formatWeight($0) } ?? "",
                stringValue: target.targetStringValue ?? "",
                isStringBased: target.isStringBased,
                unit: target.unit,
                implementName: implement.name
            )
        }
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

        // Save interval mode values
        setGroup.isInterval = isInterval
        setGroup.workDuration = isInterval ? workDuration : nil
        setGroup.intervalRestDuration = isInterval ? intervalRestDuration : nil

        // Save AMRAP mode values
        setGroup.isAMRAP = isAMRAP
        setGroup.amrapTimeLimit = isAMRAP ? amrapTimeLimit : nil

        // Save equipment measurable values
        var measurableTargets: [ImplementMeasurableTarget] = []
        for (key, value) in implementMeasurableValues {
            let hasValue = value.isStringBased ? !value.stringValue.isEmpty : !value.numericValue.isEmpty
            if hasValue {
                let components = key.components(separatedBy: "_")
                guard components.count >= 2 else { continue }
                let implementName = components.dropLast().joined(separator: "_")
                let measurableName = components.last!

                guard let implementId = implementIds.first(where: { id in
                    libraryService.getImplement(id: id)?.name == implementName
                }) else { continue }

                measurableTargets.append(ImplementMeasurableTarget(
                    implementId: implementId,
                    measurableName: measurableName,
                    unit: value.unit,
                    isStringBased: value.isStringBased,
                    targetValue: value.isStringBased ? nil : Double(value.numericValue),
                    targetStringValue: value.isStringBased ? value.stringValue : nil
                ))
            }
        }
        setGroup.implementMeasurables = measurableTargets

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

    /// Groups editable sets into L/R pairs for unilateral display
    private func groupEditableSetsForDisplay() -> [[SetData]] {
        var pairs: [[SetData]] = []
        var currentPair: [SetData] = []
        for set in editableSets {
            currentPair.append(set)
            if set.side == .right || set.side == nil {
                pairs.append(currentPair)
                currentPair = []
            }
        }
        if !currentPair.isEmpty { pairs.append(currentPair) }
        return pairs
    }

    private func formatIntervalTotalDuration() -> String {
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
}
