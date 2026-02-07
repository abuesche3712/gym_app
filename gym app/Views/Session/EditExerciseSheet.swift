//
//  EditExerciseSheet.swift
//  gym app
//
//  Full-featured exercise editing sheet for live sessions
//

import SwiftUI

// MARK: - Edit Exercise Picker Type

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

// MARK: - Editable Set Group

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

    // Interval mode fields
    var isInterval: Bool
    var workDuration: Int?
    var intervalRestDuration: Int?

    // AMRAP mode fields
    var isAMRAP: Bool
    var amrapTimeLimit: Int?

    // Equipment-specific measurable targets
    var implementMeasurables: [ImplementMeasurableTarget]
}

// MARK: - Edit Exercise Sheet

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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
                allSets: group.sets.allSatisfy({ $0.completed }) ? group.sets : [],
                isInterval: group.isInterval,
                workDuration: group.workDuration,
                intervalRestDuration: group.intervalRestDuration,
                isAMRAP: group.isAMRAP,
                amrapTimeLimit: group.amrapTimeLimit,
                implementMeasurables: group.implementMeasurables
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
            allSets: [],
            isInterval: false,
            workDuration: nil,
            intervalRestDuration: nil,
            isAMRAP: false,
            amrapTimeLimit: nil,
            implementMeasurables: []
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
                    isInterval: editableGroup.isInterval,
                    workDuration: editableGroup.workDuration,
                    intervalRestDuration: editableGroup.intervalRestDuration,
                    isAMRAP: editableGroup.isAMRAP,
                    amrapTimeLimit: editableGroup.amrapTimeLimit,
                    isUnilateral: editableGroup.isUnilateral,
                    trackRPE: editableGroup.trackRPE,
                    implementMeasurables: editableGroup.implementMeasurables
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
