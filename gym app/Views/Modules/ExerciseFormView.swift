//
//  ExerciseFormView.swift
//  gym app
//
//  Form for creating/editing an exercise
//

import SwiftUI

// Helper for sheet(item:) with Int index
struct EditingIndex: Identifiable {
    let id: Int
    var index: Int { id }
}

struct ExerciseFormView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?
    let moduleId: UUID

    @State private var name: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength
    @State private var trackTime: Bool = true
    @State private var trackDistance: Bool = false
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var trackReps: Bool = true
    @State private var trackDuration: Bool = false
    @State private var notes: String = ""
    @State private var setGroups: [SetGroup] = []

    // Library system fields
    @State private var muscleGroupIds: Set<UUID> = []
    @State private var implementIds: Set<UUID> = []

    @State private var showingAddSetGroup = false
    @State private var editingSetGroup: EditingIndex?
    @State private var showingExercisePicker = false

    private var isEditing: Bool { exercise != nil }

    /// Check if Bodyweight implement is selected
    private var hasBodyweightImplement: Bool {
        let libraryService = LibraryService.shared
        return implementIds.contains { id in
            libraryService.getImplement(id: id)?.name.lowercased() == "bodyweight"
        }
    }

    /// Computed CardioTracking from toggle states
    private var cardioMetric: CardioTracking {
        if trackTime && trackDistance {
            return .both
        } else if trackDistance {
            return .distanceOnly
        } else {
            return .timeOnly
        }
    }

    /// Computed MobilityTracking from toggle states
    private var mobilityTracking: MobilityTracking {
        if trackReps && trackDuration {
            return .both
        } else if trackDuration {
            return .durationOnly
        } else {
            return .repsOnly
        }
    }

    var body: some View {
        Form {
            exerciseSection
            musclesAndEquipmentSection
            setsSection
            notesSection
        }
        .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveExercise()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingAddSetGroup) {
            NavigationStack {
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit,
                    implementIds: implementIds,
                    existingSetGroup: nil
                ) { newSetGroup in
                    setGroups.append(newSetGroup)
                }
            }
        }
        .sheet(item: $editingSetGroup) { editing in
            NavigationStack {
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit,
                    implementIds: implementIds,
                    existingSetGroup: setGroups[editing.index]
                ) { updatedSetGroup in
                    setGroups[editing.index] = updatedSetGroup
                }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                selectedTemplate: $selectedTemplate,
                customName: $name,
                onSelect: { template in
                    if let template = template {
                        name = template.name
                        exerciseType = template.exerciseType
                        selectedTemplate = template
                        // Copy muscle groups and implements from template
                        muscleGroupIds = template.muscleGroupIds
                        implementIds = template.implementIds
                    }
                },
                onSelectWithDetails: { template, muscles, implements in
                    if let template = template {
                        name = template.name
                        exerciseType = template.exerciseType
                        selectedTemplate = template
                        // Copy muscle groups and implements from template
                        muscleGroupIds = template.muscleGroupIds
                        implementIds = template.implementIds
                    }
                    // Also merge any additional selections from the picker
                    muscleGroupIds.formUnion(muscles)
                    implementIds.formUnion(implements)
                }
            )
        }
        .onAppear {
            loadExistingExercise()
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        Section("Exercise") {
            // Exercise selection button
            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Text("Exercise")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(name.isEmpty ? "Select or type..." : name)
                        .foregroundColor(name.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            // Cardio-specific options
            if exerciseType == .cardio {
                cardioOptionsSection
            }

            // Mobility-specific options
            if exerciseType == .mobility {
                mobilityOptionsSection
            }
        }
    }

    @ViewBuilder
    private var cardioOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track During Workout")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Time", isOn: $trackTime)
            Toggle("Distance", isOn: $trackDistance)
                .onChange(of: trackDistance) { _, newValue in
                    if !newValue && !trackTime {
                        trackTime = true
                    }
                }
                .onChange(of: trackTime) { _, newValue in
                    if !newValue && !trackDistance {
                        trackDistance = true
                    }
                }
        }

        if trackDistance {
            Picker("Distance Unit", selection: $distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
        }
    }

    @ViewBuilder
    private var mobilityOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track During Workout")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Reps", isOn: $trackReps)
                .onChange(of: trackReps) { _, newValue in
                    if !newValue && !trackDuration {
                        trackDuration = true
                    }
                }
            Toggle("Duration", isOn: $trackDuration)
                .onChange(of: trackDuration) { _, newValue in
                    if !newValue && !trackReps {
                        trackReps = true
                    }
                }
        }
    }

    // MARK: - Muscles & Equipment Section

    private var musclesAndEquipmentSection: some View {
        Section("Muscles & Equipment") {
            // Muscle Groups
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Muscles Worked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !muscleGroupIds.isEmpty {
                        Text("\(muscleGroupIds.count) selected")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                MuscleGroupGridCompact(selectedIds: $muscleGroupIds)
            }
            .padding(.vertical, 4)

            // Equipment
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Equipment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !implementIds.isEmpty {
                        Text("\(implementIds.count) selected")
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
                ImplementGridCompact(selectedIds: $implementIds)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Sets Section

    private var setsSection: some View {
        Section {
            if setGroups.isEmpty {
                Text("No sets defined - tap + to add")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, setGroup in
                    Button {
                        editingSetGroup = EditingIndex(id: index)
                    } label: {
                        SetGroupEditRow(setGroup: binding(for: index), index: index + 1)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteSetGroup)
                .onMove(perform: moveSetGroup)
            }

            Button {
                showingAddSetGroup = true
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

    // MARK: - Notes Section

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 60)
        }
    }

    // MARK: - Helpers

    private func binding(for index: Int) -> Binding<SetGroup> {
        Binding(
            get: { setGroups[index] },
            set: { setGroups[index] = $0 }
        )
    }

    private func deleteSetGroup(at offsets: IndexSet) {
        setGroups.remove(atOffsets: offsets)
    }

    private func moveSetGroup(from source: IndexSet, to destination: Int) {
        setGroups.move(fromOffsets: source, toOffset: destination)
    }

    private func loadExistingExercise() {
        if let exercise = exercise {
            name = exercise.name
            exerciseType = exercise.exerciseType
            trackTime = exercise.cardioMetric.tracksTime
            trackDistance = exercise.cardioMetric.tracksDistance
            trackReps = exercise.mobilityTracking.tracksReps
            trackDuration = exercise.mobilityTracking.tracksDuration
            distanceUnit = exercise.distanceUnit
            notes = exercise.notes ?? ""
            setGroups = exercise.setGroups
            muscleGroupIds = exercise.muscleGroupIds
            implementIds = exercise.implementIds
            if let templateId = exercise.templateId {
                selectedTemplate = ExerciseLibrary.shared.template(id: templateId)
            }
        }
    }

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        guard var module = moduleViewModel.getModule(id: moduleId) else { return }

        if var existingExercise = exercise {
            // Update existing
            existingExercise.name = trimmedName
            existingExercise.templateId = selectedTemplate?.id
            existingExercise.exerciseType = exerciseType
            existingExercise.cardioMetric = cardioMetric
            existingExercise.mobilityTracking = mobilityTracking
            existingExercise.distanceUnit = distanceUnit
            existingExercise.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingExercise.setGroups = setGroups
            existingExercise.muscleGroupIds = muscleGroupIds
            existingExercise.implementIds = implementIds
            existingExercise.isBodyweight = hasBodyweightImplement
            existingExercise.updatedAt = Date()

            if let index = module.exercises.firstIndex(where: { $0.id == existingExercise.id }) {
                module.exercises[index] = existingExercise
            }
        } else {
            // Create new
            let newExercise = Exercise(
                name: trimmedName,
                templateId: selectedTemplate?.id,
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                mobilityTracking: mobilityTracking,
                distanceUnit: distanceUnit,
                setGroups: setGroups,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                muscleGroupIds: muscleGroupIds,
                implementIds: implementIds,
                isBodyweight: hasBodyweightImplement
            )
            module.exercises.append(newExercise)
        }

        module.updatedAt = Date()
        moduleViewModel.saveModule(module)
        dismiss()
    }
}

// MARK: - Set Group Edit Row

struct SetGroupEditRow: View {
    @Binding var setGroup: SetGroup
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Group \(index)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let notes = setGroup.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(setGroup.formattedTarget)
                .font(.headline)

            if let rest = setGroup.formattedRest {
                Text(rest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ExerciseFormView(exercise: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
