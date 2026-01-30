//
//  ExerciseModificationSheets.swift
//  gym app
//
//  Sheets for modifying exercises during a live session
//

import SwiftUI

// MARK: - Edit Exercise Sheet (Full Featured)

// Enum for different picker types
enum EditExercisePickerType: Identifiable, Equatable {
    case exercise
    case setGroup(Int)
    case equipment
    case muscles

    var id: String {
        switch self {
        case .exercise: return "exercise"
        case .setGroup(let index): return "setGroup_\(index)"
        case .equipment: return "equipment"
        case .muscles: return "muscles"
        }
    }
}

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: SessionExercise
    let moduleIndex: Int
    let exerciseIndex: Int
    let onSave: (Int, Int, SessionExercise) -> Void

    // Exercise details
    @State private var exerciseName: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength

    // Cardio tracking options
    @State private var trackTime: Bool = true
    @State private var trackDistance: Bool = false
    @State private var distanceUnit: DistanceUnit = .meters

    // Mobility tracking options
    @State private var trackReps: Bool = true
    @State private var trackDuration: Bool = false

    // Set groups
    @State private var setGroups: [EditableSetGroup] = []

    // Muscle groups and equipment
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []
    @State private var selectedImplementIds: Set<UUID> = []

    // Unified picker state
    @State private var activePicker: EditExercisePickerType? = nil

    // Helper struct for editing set groups
    struct EditableSetGroup: Identifiable {
        let id: UUID
        var sets: Int
        var targetWeight: Double?
        var targetReps: Int?
        var targetDuration: Int?
        var targetHoldTime: Int?
        var targetDistance: Double?
        var restPeriod: Int
        var isUnilateral: Bool
        var trackRPE: Bool
        var completedSetsCount: Int  // Number of already completed sets
        var completedSets: [SetData]  // The actual completed sets to preserve
        var allSets: [SetData]  // All sets (completed and incomplete) for history editing
    }

    private var cardioMetric: CardioTracking {
        if trackTime && trackDistance { return .both }
        else if trackDistance { return .distanceOnly }
        else { return .timeOnly }
    }

    private var mobilityTracking: MobilityTracking {
        if trackReps && trackDuration { return .both }
        else if trackDuration { return .durationOnly }
        else { return .repsOnly }
    }

    var body: some View {
        NavigationStack {
            Form {
                exerciseSection
                trackingOptionsSection
                setGroupsSection
                musclesAndEquipmentSection
                infoSection
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.dominant)
                        .disabled(exerciseName.isEmpty)
                }
            }
            .onAppear { loadCurrentValues() }
            .sheet(item: $activePicker) { pickerType in
                pickerSheet(for: pickerType)
            }
            .onChange(of: activePicker) { oldValue, newValue in
                // When set group sheet dismisses, auto-save changes to update the active session immediately
                if case .setGroup = oldValue, newValue == nil {
                    saveChanges()
                }
            }
        }
    }

    // MARK: - Unified Picker Sheet

    @ViewBuilder
    private func pickerSheet(for type: EditExercisePickerType) -> some View {
        switch type {
        case .exercise:
            ExercisePickerView(
                selectedTemplate: $selectedTemplate,
                customName: $exerciseName,
                onSelect: { template in
                    if let template = template {
                        exerciseName = template.name
                        exerciseType = template.exerciseType
                        selectedTemplate = template
                        primaryMuscles = template.primaryMuscles
                        secondaryMuscles = template.secondaryMuscles
                        selectedImplementIds = template.implementIds
                        if template.exerciseType == .cardio {
                            trackTime = template.cardioMetric.tracksTime
                            trackDistance = template.cardioMetric.tracksDistance
                            distanceUnit = template.distanceUnit
                        }
                    }
                }
            )

        case .setGroup(let index):
            EditSetGroupSheet(
                setGroup: $setGroups[index],
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                mobilityTracking: mobilityTracking,
                distanceUnit: distanceUnit,
                implementIds: selectedImplementIds
            )

        case .equipment:
            NavigationStack {
                ImplementPickerView(selectedIds: $selectedImplementIds)
                    .navigationTitle("Equipment")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                activePicker = nil
                            }
                            .foregroundColor(AppColors.dominant)
                        }
                    }
            }

        case .muscles:
            NavigationStack {
                MuscleGroupEnumPickerView(
                    primaryMuscles: $primaryMuscles,
                    secondaryMuscles: $secondaryMuscles
                )
                .navigationTitle("Muscles")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            activePicker = nil
                        }
                        .foregroundColor(AppColors.dominant)
                    }
                }
            }
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        Section("Exercise") {
            Button {
                activePicker = .exercise
            } label: {
                HStack {
                    Text("Exercise")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(exerciseName.isEmpty ? "Select exercise..." : exerciseName)
                        .foregroundColor(exerciseName.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
        }
    }

    // MARK: - Tracking Options Section

    @ViewBuilder
    private var trackingOptionsSection: some View {
        if exerciseType == .cardio {
            Section("Cardio Tracking") {
                Toggle("Track Time", isOn: $trackTime)
                    .onChange(of: trackTime) { _, newValue in
                        if !newValue && !trackDistance { trackDistance = true }
                    }
                Toggle("Track Distance", isOn: $trackDistance)
                    .onChange(of: trackDistance) { _, newValue in
                        if !newValue && !trackTime { trackTime = true }
                    }

                if trackDistance {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
        }

        if exerciseType == .mobility {
            Section("Mobility Tracking") {
                Toggle("Track Reps", isOn: $trackReps)
                    .onChange(of: trackReps) { _, newValue in
                        if !newValue && !trackDuration { trackDuration = true }
                    }
                Toggle("Track Duration", isOn: $trackDuration)
                    .onChange(of: trackDuration) { _, newValue in
                        if !newValue && !trackReps { trackReps = true }
                    }
            }
        }
    }

    // MARK: - Set Groups Section

    private var setGroupsSection: some View {
        Section {
            ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, setGroup in
                Button {
                    activePicker = .setGroup(index)
                } label: {
                    setGroupRow(setGroup, index: index)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteSetGroup)

            Button {
                addSetGroup()
            } label: {
                Label("Add Set Group", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Sets")
                Spacer()
                Text("Tap to edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setGroupRow(_ setGroup: EditableSetGroup, index: Int) -> some View {
        // For unilateral, show logical completed count (half of actual SetData count)
        let completedLogical = setGroup.isUnilateral ? setGroup.completedSetsCount / 2 : setGroup.completedSetsCount

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Group \(index + 1)")
                        .subheadline()
                        .fontWeight(.medium)
                    if completedLogical > 0 {
                        Text("(\(completedLogical) done)")
                            .caption(color: AppColors.success)
                    }
                }

                Text(setGroupSummary(setGroup))
                    .caption(color: .secondary)
            }

            Spacer()

            Text("\(setGroup.sets) sets")
                .subheadline(color: .secondary)

            Image(systemName: "chevron.right")
                .caption(color: AppColors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func setGroupSummary(_ setGroup: EditableSetGroup) -> String {
        var parts: [String] = []

        switch exerciseType {
        case .strength:
            if let w = setGroup.targetWeight, w > 0 { parts.append("\(formatWeight(w)) lbs") }
            if let r = setGroup.targetReps, r > 0 { parts.append("\(r) reps") }
        case .cardio:
            if trackTime, let d = setGroup.targetDuration, d > 0 { parts.append(formatDuration(d)) }
            if trackDistance, let dist = setGroup.targetDistance, dist > 0 { parts.append("\(formatDistanceValue(dist)) \(distanceUnit.abbreviation)") }
        case .isometric:
            if let h = setGroup.targetHoldTime, h > 0 { parts.append("\(h)s hold") }
        case .mobility:
            if trackReps, let r = setGroup.targetReps, r > 0 { parts.append("\(r) reps") }
            if trackDuration, let d = setGroup.targetDuration, d > 0 { parts.append(formatDuration(d)) }
        case .explosive:
            if let r = setGroup.targetReps, r > 0 { parts.append("\(r) reps") }
        case .recovery:
            if let d = setGroup.targetDuration, d > 0 { parts.append(formatDuration(d)) }
        }

        parts.append("\(setGroup.restPeriod)s rest")
        return parts.joined(separator: " · ")
    }

    // MARK: - Muscles & Equipment Section

    private var musclesAndEquipmentSection: some View {
        Section("Muscles & Equipment") {
            // Equipment row
            Button {
                activePicker = .equipment
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(AppColors.accent1)
                        .frame(width: 24)

                    Text("Equipment")
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    equipmentValueText
                        .multilineTextAlignment(.trailing)
                }
            }
            .buttonStyle(.plain)

            // Muscles row
            Button {
                activePicker = .muscles
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(AppColors.dominant)
                        .frame(width: 24)

                    Text("Muscles")
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    muscleValueText
                        .multilineTextAlignment(.trailing)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var equipmentValueText: some View {
        Group {
            if selectedImplementIds.isEmpty {
                Text("None")
                    .foregroundColor(AppColors.textTertiary)
            } else {
                Text(equipmentNames(for: selectedImplementIds).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var muscleValueText: some View {
        Group {
            if primaryMuscles.isEmpty && secondaryMuscles.isEmpty {
                Text("None")
                    .foregroundColor(AppColors.textTertiary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    if !primaryMuscles.isEmpty {
                        Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .subheadline(color: AppColors.dominant)
                            .lineLimit(1)
                    }
                    if !secondaryMuscles.isEmpty {
                        Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .caption(color: AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func equipmentNames(for ids: Set<UUID>) -> [String] {
        let library = LibraryService.shared
        return ids.compactMap { id in
            library.getImplement(id: id)?.name
        }.sorted()
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.dominant)
                Text("Completed sets are preserved. Changes apply to remaining sets.")
                    .caption(color: AppColors.textSecondary)
            }
        }
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {
        exerciseName = exercise.exerciseName
        exerciseType = exercise.exerciseType
        trackTime = exercise.cardioMetric.tracksTime
        trackDistance = exercise.cardioMetric.tracksDistance
        distanceUnit = exercise.distanceUnit
        trackReps = exercise.mobilityTracking.tracksReps
        trackDuration = exercise.mobilityTracking.tracksDuration
        primaryMuscles = exercise.primaryMuscles
        secondaryMuscles = exercise.secondaryMuscles
        selectedImplementIds = exercise.implementIds

        // Convert CompletedSetGroups to EditableSetGroups
        setGroups = exercise.completedSetGroups.map { group in
            let completedSets = group.sets.filter { $0.completed }
            let firstSet = group.sets.first

            // For unilateral exercises, the logical set count is half the SetData count
            // (since each logical set has left + right)
            let logicalSetCount = group.isUnilateral ? group.sets.count / 2 : group.sets.count
            let completedLogicalSetsCount = group.isUnilateral ? completedSets.count / 2 : completedSets.count

            return EditableSetGroup(
                id: group.setGroupId,
                sets: logicalSetCount,
                targetWeight: firstSet?.weight,
                targetReps: firstSet?.reps,
                targetDuration: firstSet?.duration,
                targetHoldTime: firstSet?.holdTime,
                targetDistance: firstSet?.distance,
                restPeriod: group.restPeriod ?? 90,
                isUnilateral: group.isUnilateral,
                trackRPE: group.trackRPE,
                completedSetsCount: completedSets.count,  // Keep actual count for preserving completed sets
                completedSets: completedSets,
                allSets: group.sets  // Store all sets for history editing
            )
        }

        // Ensure at least one set group exists
        if setGroups.isEmpty {
            addSetGroup()
        }
    }

    // MARK: - Set Group Management

    private func addSetGroup() {
        let newGroup = EditableSetGroup(
            id: UUID(),
            sets: 3,
            targetWeight: exerciseType == .strength ? 0 : nil,
            targetReps: [.strength, .explosive, .mobility].contains(exerciseType) ? 10 : nil,
            targetDuration: [.cardio, .recovery].contains(exerciseType) ? 0 : nil,
            targetHoldTime: exerciseType == .isometric ? 30 : nil,
            targetDistance: exerciseType == .cardio && trackDistance ? 0 : nil,
            restPeriod: 90,
            isUnilateral: false,
            trackRPE: true,
            completedSetsCount: 0,
            completedSets: [],
            allSets: []
        )
        setGroups.append(newGroup)
    }

    private func deleteSetGroup(at offsets: IndexSet) {
        // Don't allow deleting groups that have completed sets
        let indicesToRemove = offsets.filter { setGroups[$0].completedSetsCount == 0 }
        setGroups.remove(atOffsets: IndexSet(indicesToRemove))

        // Ensure at least one group remains
        if setGroups.isEmpty {
            addSetGroup()
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        var updatedExercise = exercise
        updatedExercise.exerciseName = exerciseName
        updatedExercise.exerciseType = exerciseType
        updatedExercise.cardioMetric = cardioMetric
        updatedExercise.mobilityTracking = mobilityTracking
        updatedExercise.distanceUnit = distanceUnit

        // Convert EditableSetGroups back to CompletedSetGroups
        var newSetGroups: [CompletedSetGroup] = []

        for editableGroup in setGroups {
            var sets: [SetData] = []

            // If we have allSets (from history editing), use those directly
            if !editableGroup.allSets.isEmpty {
                sets = editableGroup.allSets
            } else {
                // Otherwise, build from completed sets + new incomplete sets
                // First, add any completed sets (preserve them exactly)
                sets.append(contentsOf: editableGroup.completedSets)

                // Calculate remaining sets based on whether it's unilateral
                // For unilateral: completedSetsCount is actual SetData count (2 per logical set)
                // editableGroup.sets is the LOGICAL set count (user facing)
                let completedLogicalSets = editableGroup.isUnilateral
                    ? editableGroup.completedSetsCount / 2
                    : editableGroup.completedSetsCount
                let remainingLogicalSets = editableGroup.sets - completedLogicalSets

                // Then add remaining incomplete sets with targets
                for i in 0..<remainingLogicalSets {
                    let setNumber = completedLogicalSets + i + 1

                    if editableGroup.isUnilateral {
                        // For unilateral, create left and right pairs
                        sets.append(SetData(
                            setNumber: setNumber,
                            weight: editableGroup.targetWeight,
                            reps: editableGroup.targetReps,
                            completed: false,
                            duration: editableGroup.targetDuration,
                            distance: editableGroup.targetDistance,
                            holdTime: editableGroup.targetHoldTime,
                            side: .left
                        ))
                        sets.append(SetData(
                            setNumber: setNumber,
                            weight: editableGroup.targetWeight,
                            reps: editableGroup.targetReps,
                            completed: false,
                            duration: editableGroup.targetDuration,
                            distance: editableGroup.targetDistance,
                            holdTime: editableGroup.targetHoldTime,
                            side: .right
                        ))
                    } else {
                        // Normal bilateral set
                        sets.append(SetData(
                            setNumber: setNumber,
                            weight: editableGroup.targetWeight,
                            reps: editableGroup.targetReps,
                            completed: false,
                            duration: editableGroup.targetDuration,
                            distance: editableGroup.targetDistance,
                            holdTime: editableGroup.targetHoldTime
                        ))
                    }
                }
            }

            if !sets.isEmpty {
                newSetGroups.append(CompletedSetGroup(
                    setGroupId: editableGroup.id,
                    restPeriod: editableGroup.restPeriod,
                    sets: sets,
                    isUnilateral: editableGroup.isUnilateral,
                    trackRPE: editableGroup.trackRPE
                ))
            }
        }

        updatedExercise.completedSetGroups = newSetGroups
        updatedExercise.primaryMuscles = primaryMuscles
        updatedExercise.secondaryMuscles = secondaryMuscles
        updatedExercise.implementIds = selectedImplementIds

        onSave(moduleIndex, exerciseIndex, updatedExercise)
        dismiss()
    }
}

// MARK: - Edit Set Group Sheet

struct EditSetGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var libraryService = LibraryService.shared
    @Binding var setGroup: EditExerciseSheet.EditableSetGroup

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
                        Text("30s").tag(30)
                        Text("45s").tag(45)
                        Text("60s").tag(60)
                        Text("90s").tag(90)
                        Text("2 min").tag(120)
                        Text("3 min").tag(180)
                        Text("5 min").tag(300)
                    }
                    .pickerStyle(.segmented)
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
}

// MARK: - Add Exercise to Module Sheet

struct AddExerciseToModuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let moduleName: String
    let onAdd: (String, ExerciseType, CardioTracking, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioTracking = .timeOnly
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var showingExercisePicker = false

    var body: some View {
        NavigationStack {
            Form {
                moduleInfoSection
                exercisePickerSection
                cardioSettingsSection
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedTemplate: $selectedTemplate,
                    customName: $exerciseName,
                    onSelect: { template in
                        if let template = template {
                            exerciseName = template.name
                            exerciseType = template.exerciseType
                            selectedTemplate = template
                            // Set cardio settings from template
                            if template.exerciseType == .cardio {
                                cardioMetric = template.cardioMetric
                                distanceUnit = template.distanceUnit
                            }
                        }
                    }
                )
            }
        }
    }

    private var moduleInfoSection: some View {
        Section {
            HStack {
                Text("Adding to")
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(moduleName)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private var exercisePickerSection: some View {
        Section("Exercise") {
            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Text("Exercise")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(exerciseName.isEmpty ? "Select exercise..." : exerciseName)
                        .foregroundColor(exerciseName.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !exerciseName.isEmpty {
                HStack {
                    Text("Type")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(exerciseType.displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var cardioSettingsSection: some View {
        if exerciseType == .cardio && !exerciseName.isEmpty {
            Section("Cardio Settings") {
                Picker("Track", selection: $cardioMetric) {
                    Text("Time").tag(CardioTracking.timeOnly)
                    Text("Distance").tag(CardioTracking.distanceOnly)
                    Text("Both").tag(CardioTracking.both)
                }
                .pickerStyle(.segmented)

                if cardioMetric.tracksDistance {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                onAdd(exerciseName, exerciseType, cardioMetric, distanceUnit)
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundColor(AppColors.dominant)
            .disabled(exerciseName.isEmpty)
        }
    }
}

// MARK: - Edit Individual Set Sheet

struct EditIndividualSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: SetData

    let exerciseType: ExerciseType
    let cardioMetric: CardioTracking
    let mobilityTracking: MobilityTracking
    let distanceUnit: DistanceUnit

    @State private var isCompleted: Bool = false
    @State private var weight: String = ""
    @State private var reps: Int = 0
    @State private var duration: Int = 0
    @State private var distance: String = ""
    @State private var holdTime: Int = 0
    @State private var rpe: Int? = nil
    @State private var showTimePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Toggle("Completed", isOn: $isCompleted)
                        .tint(AppColors.success)
                }

                Section("Set Data") {
                    setFieldsForExerciseType
                }

                if exerciseType == .strength {
                    Section("RPE (Optional)") {
                        Picker("RPE", selection: Binding(
                            get: { rpe ?? 0 },
                            set: { rpe = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Not set").tag(0)
                            ForEach(5...10, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Edit Set \(set.setNumber)")
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
                TimePickerSheet(totalSeconds: $duration, title: "Duration")
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var setFieldsForExerciseType: some View {
        switch exerciseType {
        case .strength:
            HStack {
                Text("Weight")
                Spacer()
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("lbs")
                    .foregroundColor(.secondary)
            }
            Stepper("Reps: \(reps)", value: $reps, in: 0...100)

        case .cardio:
            if cardioMetric.tracksTime {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(duration > 0 ? formatDuration(duration) : "Not set")
                            .foregroundColor(duration > 0 ? .primary : .secondary)
                    }
                }
            }
            if cardioMetric.tracksDistance {
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("0", text: $distance)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(distanceUnit.abbreviation)
                        .foregroundColor(.secondary)
                }
            }

        case .isometric:
            Stepper("Hold Time: \(holdTime)s", value: $holdTime, in: 0...600, step: 5)

        case .mobility:
            if mobilityTracking.tracksReps {
                Stepper("Reps: \(reps)", value: $reps, in: 0...100)
            }
            if mobilityTracking.tracksDuration {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(duration > 0 ? formatDuration(duration) : "Not set")
                            .foregroundColor(duration > 0 ? .primary : .secondary)
                    }
                }
            }

        case .explosive:
            Stepper("Reps: \(reps)", value: $reps, in: 0...50)

        case .recovery:
            Button {
                showTimePicker = true
            } label: {
                HStack {
                    Text("Duration")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(duration > 0 ? formatDuration(duration) : "Not set")
                        .foregroundColor(duration > 0 ? .primary : .secondary)
                }
            }
        }
    }

    private func loadValues() {
        isCompleted = set.completed
        weight = set.weight.map { formatWeight($0) } ?? ""
        reps = set.reps ?? 0
        duration = set.duration ?? 0
        distance = set.distance.map { formatDistanceValue($0) } ?? ""
        holdTime = set.holdTime ?? 0
        rpe = set.rpe
    }

    private func saveChanges() {
        set.completed = isCompleted
        set.weight = Double(weight)
        set.reps = reps > 0 ? reps : nil
        set.duration = duration > 0 ? duration : nil
        set.distance = Double(distance)
        set.holdTime = holdTime > 0 ? holdTime : nil
        set.rpe = rpe
        dismiss()
    }
}

