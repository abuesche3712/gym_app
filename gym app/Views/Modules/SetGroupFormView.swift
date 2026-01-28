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

    // AMRAP mode
    @State private var isAMRAP: Bool = false
    @State private var amrapTimeLimit: Int? = nil

    // RPE tracking
    @State private var trackRPE: Bool = true

    // Weight tracking (optional for bodyweight exercises)
    @State private var trackWeight: Bool = true

    // Implement-specific measurables (auto-populated from equipment)
    @State private var implementMeasurableValues: [String: MeasurableValue] = [:]

    struct MeasurableValue {
        var numericValue: String = ""
        var stringValue: String = ""
        let isStringBased: Bool
        let unit: String
        let implementName: String
    }

    private var isEditing: Bool { existingSetGroup != nil }

    /// Returns implement-specific measurables to display (e.g., Box Height, Band Color)
    private var implementSpecificMeasurables: [(key: String, value: MeasurableValue)] {
        var result: [String: MeasurableValue] = [:]

        for id in implementIds {
            guard let implement = libraryService.getImplement(id: id) else { continue }
            for measurable in implement.measurableArray {
                let key = "\(implement.name)_\(measurable.name)"

                // Only add if not already set (preserve existing values)
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

        // Merge with existing values
        var merged = implementMeasurableValues
        for (key, value) in result {
            if merged[key] == nil {
                merged[key] = value
            }
        }

        // Filter to only include measurables for currently selected implements
        // AND skip weight measurables for bodyweight exercises (redundant with Added Weight field)
        let validKeys = result.keys
        return merged.filter { entry in
            guard validKeys.contains(entry.key) else { return false }

            // Skip weight/load measurables for bodyweight exercises
            if isBodyweight {
                let measurableName = extractMeasurableName(from: entry.key).lowercased()
                if measurableName.contains("weight") || measurableName.contains("load") {
                    return false
                }
            }

            return true
        }.sorted { $0.key < $1.key }
    }

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
                // Mode Selection
                FormSection(title: "Mode", icon: "timer", iconColor: (isInterval || isAMRAP) ? AppColors.dominant : AppColors.textTertiary) {
                    VStack(spacing: AppSpacing.sm) {
                        // Interval Mode Toggle
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "repeat")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)

                            Toggle("Interval Mode", isOn: Binding(
                                get: { isInterval },
                                set: { newValue in
                                    isInterval = newValue
                                    if newValue { isAMRAP = false }
                                }
                            ))
                            .tint(AppColors.dominant)
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surfacePrimary)

                        // AMRAP Mode Toggle
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)

                            Toggle("AMRAP Mode", isOn: Binding(
                                get: { isAMRAP },
                                set: { newValue in
                                    isAMRAP = newValue
                                    if newValue { isInterval = false }
                                }
                            ))
                            .tint(AppColors.accent2)
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surfacePrimary)
                    }

                    if isInterval {
                        Text("Timer will auto-run through all rounds with work/rest periods")
                            .font(.caption)
                            .foregroundColor(AppColors.dominant)
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.bottom, AppSpacing.sm)
                    } else if isAMRAP {
                        Text("As Many Reps As Possible - log max reps achieved per set")
                            .font(.caption)
                            .foregroundColor(AppColors.accent2)
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.bottom, AppSpacing.sm)
                    }
                }

                if isInterval {
                    intervalModeSection
                } else if isAMRAP {
                    amrapModeSection
                } else {
                    normalModeSection
                }

                // Notes Section
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextField("Notes (e.g., 'top set', 'back-off')", text: $notes)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surfacePrimary)
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
                .foregroundColor(AppColors.dominant)
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
        FormSection(title: "Rounds", icon: "repeat.circle", iconColor: AppColors.dominant) {
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
            .background(AppColors.surfacePrimary)
        }

        // Work Period
        FormSection(title: "Work Period", icon: "flame", iconColor: AppColors.dominant) {
            TimePickerView(totalSeconds: $workDuration, maxMinutes: 10, label: "Work Time", secondsStep: 5)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
        }

        // Rest Period
        FormSection(title: "Rest Period", icon: "pause.circle", iconColor: AppColors.accent1) {
            TimePickerView(totalSeconds: $intervalRestDuration, maxMinutes: 10, label: "Rest Time", secondsStep: 5)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
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
                    .foregroundColor(AppColors.dominant)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
        }
    }

    // MARK: - AMRAP Mode Section

    @ViewBuilder
    private var amrapModeSection: some View {
        // Sets
        FormSection(title: "AMRAP Sets", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accent2) {
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
            .background(AppColors.surfacePrimary)
        }

        // Time Limit (Optional)
        FormSection(title: "Time Limit (Optional)", icon: "timer", iconColor: AppColors.dominant) {
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "timer")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)

                    Picker("Time Limit", selection: $amrapTimeLimit) {
                        Text("No Limit").tag(nil as Int?)
                        Text("30 seconds").tag(30 as Int?)
                        Text("45 seconds").tag(45 as Int?)
                        Text("60 seconds").tag(60 as Int?)
                        Text("90 seconds").tag(90 as Int?)
                        Text("2 minutes").tag(120 as Int?)
                        Text("3 minutes").tag(180 as Int?)
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)

                if amrapTimeLimit == nil {
                    Text("Track max reps with no time constraint")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.bottom, AppSpacing.sm)
                }
            }
        }

        // Weight/Equipment (for AMRAP sets)
        if exerciseType == .strength {
            FormSection(title: "Load", icon: "scalemass", iconColor: AppColors.dominant) {
                VStack(spacing: 0) {
                    // Weight tracking toggle
                    styledRow(icon: "scalemass", label: "Track Weight") {
                        Toggle("", isOn: $trackWeight)
                            .labelsHidden()
                            .tint(AppColors.dominant)
                    }

                    if trackWeight {
                        FormDivider()

                        if isBodyweight {
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
                    }
                }
                .background(AppColors.surfacePrimary)
            }
        }

        // Rest Between Sets
        FormSection(title: "Rest Between Sets", icon: "pause.circle", iconColor: AppColors.accent1) {
            TimePickerView(totalSeconds: $restPeriod, maxMinutes: 5, label: "Rest Period", compact: true)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
        }
    }

    // MARK: - Normal Mode Section

    @ViewBuilder
    private var normalModeSection: some View {
        // Sets
        FormSection(title: "Sets", icon: "number.square", iconColor: AppColors.dominant) {
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
            .background(AppColors.surfacePrimary)
        }

        // Target
        FormSection(title: "Target", icon: "target", iconColor: AppColors.dominant) {
            VStack(spacing: 0) {
                targetFieldsForExerciseType
            }
            .background(AppColors.surfacePrimary)
        }

        // Equipment-Specific Attributes (automatically shown based on selected equipment)
        if !implementSpecificMeasurables.isEmpty && exerciseType == .strength {
            equipmentAttributesSection
        }

        // Rest Between Sets
        FormSection(title: "Rest Between Sets", icon: "pause.circle", iconColor: AppColors.accent1) {
            TimePickerView(totalSeconds: $restPeriod, maxMinutes: 5, label: "Rest Period", compact: true)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
        }
    }

    // MARK: - Equipment Attributes Section

    @ViewBuilder
    private var equipmentAttributesSection: some View {
        FormSection(
            title: "Equipment Attributes",
            icon: "wrench.and.screwdriver",
            iconColor: AppColors.accent3
        ) {
            VStack(spacing: 0) {
                ForEach(Array(implementSpecificMeasurables.enumerated()), id: \.element.key) { index, item in
                    if index > 0 {
                        FormDivider()
                    }

                    let measurable = item.value
                    let displayLabel = "\(measurable.implementName) - \(extractMeasurableName(from: item.key))"

                    styledRow(icon: "ruler", label: displayLabel) {
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
                            .foregroundColor(AppColors.textPrimary)
                        } else {
                            HStack(spacing: AppSpacing.xs) {
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
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
        }
    }

    private func extractMeasurableName(from key: String) -> String {
        // Key format: "ImplementName_MeasurableName"
        key.components(separatedBy: "_").last ?? key
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

            // RPE toggle
            styledRow(icon: "gauge.with.dots.needle.67percent", label: "Track RPE") {
                Toggle("", isOn: $trackRPE)
                    .labelsHidden()
                    .tint(AppColors.dominant)
            }

            // RPE target (only shown if tracking enabled)
            if trackRPE {
                FormDivider()

                styledRow(icon: "target", label: "Target RPE") {
                    Picker("", selection: $targetRPE) {
                        Text("None").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }
                    .tint(AppColors.dominant)
                }
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
                                        .fill(AppColors.surfaceTertiary)
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColors.surfaceTertiary, lineWidth: 0.5)
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
        // Convert implement measurable values to ImplementMeasurableTarget objects
        var measurableTargets: [ImplementMeasurableTarget] = []
        for (key, value) in implementMeasurableValues {
            // Skip empty values
            let hasValue = value.isStringBased ? !value.stringValue.isEmpty : !value.numericValue.isEmpty

            if hasValue {
                // Extract implement ID from the key
                // Key format: "ImplementName_MeasurableName"
                let components = key.components(separatedBy: "_")
                guard components.count >= 2 else { continue }

                let implementName = components.dropLast().joined(separator: "_")
                let measurableName = components.last!

                // Find the implement ID
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

        // Legacy single measurable support (for backward compatibility)
        let measurableLabel = implementStringMeasurable?.measurableName
        let measurableUnit = implementStringMeasurable?.unit
        let measurableStringValue = !implementMeasurableStringValue.isEmpty ? implementMeasurableStringValue : nil

        let setGroup = SetGroup(
            id: existingSetGroup?.id ?? UUID(),
            sets: sets,
            targetReps: !isInterval && !isAMRAP && (exerciseType == .strength || (exerciseType == .mobility && mobilityTracking.tracksReps) || exerciseType == .explosive) ? (targetReps > 0 ? targetReps : nil) : nil,
            targetWeight: trackWeight && (!isInterval || isAMRAP) && implementStringMeasurable == nil ? Double(targetWeight) : nil,
            targetRPE: !isInterval && !isAMRAP && trackRPE && targetRPE > 0 ? targetRPE : nil,
            targetDuration: !isInterval && !isAMRAP && ((exerciseType == .cardio && cardioMetric.tracksTime) || (exerciseType == .mobility && mobilityTracking.tracksDuration) || exerciseType == .recovery) && targetDuration > 0 ? targetDuration : nil,
            targetDistance: !isInterval && !isAMRAP && cardioMetric.tracksDistance ? Double(targetDistance) : nil,
            targetDistanceUnit: !isInterval && !isAMRAP && cardioMetric.tracksDistance ? distanceUnit : nil,
            targetHoldTime: !isInterval && !isAMRAP && targetHoldTime > 0 ? targetHoldTime : nil,
            restPeriod: !isInterval && !isAMRAP ? restPeriod : (isAMRAP ? restPeriod : nil),
            notes: notes.isEmpty ? nil : notes,
            isInterval: isInterval,
            workDuration: isInterval ? workDuration : nil,
            intervalRestDuration: isInterval ? intervalRestDuration : nil,
            isAMRAP: isAMRAP,
            amrapTimeLimit: isAMRAP ? amrapTimeLimit : nil,
            isUnilateral: false,  // Now tracked at exercise level, not set group level
            trackRPE: trackRPE,
            implementMeasurables: measurableTargets,
            implementMeasurableLabel: measurableLabel,
            implementMeasurableUnit: measurableUnit,
            implementMeasurableStringValue: isAMRAP || !isInterval ? measurableStringValue : nil
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
            // AMRAP fields
            isAMRAP = existing.isAMRAP
            amrapTimeLimit = existing.amrapTimeLimit
            // RPE tracking
            trackRPE = existing.trackRPE
            // Weight tracking - default to true if weight exists
            trackWeight = existing.targetWeight != nil && existing.targetWeight! > 0
            // Equipment-specific measurables
            implementMeasurableValues = [:]
            for target in existing.implementMeasurables {
                // Find implement name
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
            // Legacy implement measurable field
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
