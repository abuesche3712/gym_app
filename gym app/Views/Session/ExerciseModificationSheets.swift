//
//  ExerciseModificationSheets.swift
//  gym app
//
//  Sheets for modifying exercises during a live session
//

import SwiftUI

// MARK: - Edit Exercise Sheet (Full Featured)

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
    @State private var showingExercisePicker = false

    // Cardio tracking options
    @State private var trackTime: Bool = true
    @State private var trackDistance: Bool = false
    @State private var distanceUnit: DistanceUnit = .meters

    // Mobility tracking options
    @State private var trackReps: Bool = true
    @State private var trackDuration: Bool = false

    // Set groups
    @State private var setGroups: [EditableSetGroup] = []
    @State private var editingSetGroupIndex: Int? = nil

    // Muscle groups (display-only)
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []

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
        var completedSetsCount: Int  // Number of already completed sets
        var completedSets: [SetData]  // The actual completed sets to preserve
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
                musclesSection
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
                        .foregroundColor(AppColors.accentBlue)
                        .disabled(exerciseName.isEmpty)
                }
            }
            .onAppear { loadCurrentValues() }
            .sheet(isPresented: $showingExercisePicker) {
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
                            if template.exerciseType == .cardio {
                                trackTime = template.cardioMetric.tracksTime
                                trackDistance = template.cardioMetric.tracksDistance
                                distanceUnit = template.distanceUnit
                            }
                        }
                    }
                )
            }
            .sheet(item: Binding(
                get: { editingSetGroupIndex.map { EditingIndex(id: $0) } },
                set: { editingSetGroupIndex = $0?.id }
            )) { editing in
                EditSetGroupSheet(
                    setGroup: $setGroups[editing.index],
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit
                )
            }
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
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
                    editingSetGroupIndex = index
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Group \(index + 1)")
                        .font(.subheadline.weight(.medium))
                    if setGroup.completedSetsCount > 0 {
                        Text("(\(setGroup.completedSetsCount) done)")
                            .font(.caption)
                            .foregroundColor(AppColors.success)
                    }
                }

                Text(setGroupSummary(setGroup))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(setGroup.sets) sets")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
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

    // MARK: - Muscles Section

    @ViewBuilder
    private var musclesSection: some View {
        if !primaryMuscles.isEmpty || !secondaryMuscles.isEmpty {
            Section("Muscles") {
                if !primaryMuscles.isEmpty {
                    HStack {
                        Text("Primary")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
                if !secondaryMuscles.isEmpty {
                    HStack {
                        Text("Secondary")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.accentBlue)
                Text("Completed sets are preserved. Changes apply to remaining sets.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
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

        // Convert CompletedSetGroups to EditableSetGroups
        setGroups = exercise.completedSetGroups.map { group in
            let completedSets = group.sets.filter { $0.completed }
            let firstSet = group.sets.first

            return EditableSetGroup(
                id: group.setGroupId,
                sets: group.sets.count,
                targetWeight: firstSet?.weight,
                targetReps: firstSet?.reps,
                targetDuration: firstSet?.duration,
                targetHoldTime: firstSet?.holdTime,
                targetDistance: firstSet?.distance,
                restPeriod: group.restPeriod ?? 90,
                completedSetsCount: completedSets.count,
                completedSets: completedSets
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
            completedSetsCount: 0,
            completedSets: []
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

            // First, add any completed sets (preserve them exactly)
            sets.append(contentsOf: editableGroup.completedSets)

            // Then add remaining incomplete sets with targets
            let remainingSets = editableGroup.sets - editableGroup.completedSetsCount
            for i in 0..<remainingSets {
                let setNumber = editableGroup.completedSetsCount + i + 1
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

            if !sets.isEmpty {
                newSetGroups.append(CompletedSetGroup(
                    setGroupId: editableGroup.id,
                    restPeriod: editableGroup.restPeriod,
                    sets: sets
                ))
            }
        }

        updatedExercise.completedSetGroups = newSetGroups

        onSave(moduleIndex, exerciseIndex, updatedExercise)
        dismiss()
    }
}

// MARK: - Edit Set Group Sheet

struct EditSetGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var setGroup: EditExerciseSheet.EditableSetGroup

    let exerciseType: ExerciseType
    let cardioMetric: CardioTracking
    let mobilityTracking: MobilityTracking
    let distanceUnit: DistanceUnit

    @State private var sets: Int = 3
    @State private var targetWeight: String = ""
    @State private var targetReps: Int = 10
    @State private var targetDuration: Int = 0
    @State private var targetHoldTime: Int = 0
    @State private var targetDistance: String = ""
    @State private var restPeriod: Int = 90
    @State private var showTimePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sets") {
                    Stepper("Total Sets: \(sets)", value: $sets, in: max(1, setGroup.completedSetsCount)...20)

                    if setGroup.completedSetsCount > 0 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text("\(setGroup.completedSetsCount) sets already completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .onAppear { loadValues() }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(totalSeconds: $targetDuration, title: "Target Time")
            }
        }
        .presentationDetents([.medium])
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
    }

    private func saveChanges() {
        setGroup.sets = sets
        setGroup.targetWeight = Double(targetWeight)
        setGroup.targetReps = targetReps
        setGroup.targetDuration = targetDuration
        setGroup.targetHoldTime = targetHoldTime
        setGroup.targetDistance = Double(targetDistance)
        setGroup.restPeriod = restPeriod
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
            .foregroundColor(AppColors.accentBlue)
            .disabled(exerciseName.isEmpty)
        }
    }
}

