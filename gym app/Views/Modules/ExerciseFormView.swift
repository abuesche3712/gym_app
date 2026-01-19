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

    let instance: ExerciseInstance?
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

    // Muscle groups from template
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []

    @State private var showingAddSetGroup = false
    @State private var editingSetGroup: EditingIndex?
    @State private var showingExercisePicker = false

    private var isEditing: Bool { instance != nil }

    /// Check if exercise is bodyweight-based
    private var isBodyweight: Bool {
        selectedTemplate?.isBodyweight ?? false
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
                        // Copy muscle groups from template
                        primaryMuscles = template.primaryMuscles
                        secondaryMuscles = template.secondaryMuscles
                    }
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

    // MARK: - Muscles Section

    private var musclesAndEquipmentSection: some View {
        Section("Muscles") {
            if !primaryMuscles.isEmpty || !secondaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    if !primaryMuscles.isEmpty {
                        HStack {
                            Text("Primary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                        }
                    }
                    if !secondaryMuscles.isEmpty {
                        HStack {
                            Text("Secondary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("No muscles specified")
                    .foregroundColor(.secondary)
            }
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
        if let instance = instance {
            // Instance now stores all data directly
            name = instance.name
            exerciseType = instance.exerciseType
            trackTime = instance.cardioMetric.tracksTime
            trackDistance = instance.cardioMetric.tracksDistance
            trackReps = instance.mobilityTracking.tracksReps
            trackDuration = instance.mobilityTracking.tracksDuration
            distanceUnit = instance.distanceUnit
            notes = instance.notes ?? ""
            setGroups = instance.setGroups
            primaryMuscles = instance.primaryMuscles
            secondaryMuscles = instance.secondaryMuscles
            // Template lookup is optional now
            if let templateId = instance.templateId {
                selectedTemplate = ExerciseLibrary.shared.template(id: templateId)
            }
        }
    }

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        guard var module = moduleViewModel.getModule(id: moduleId) else { return }

        if var existingInstance = instance {
            // Update existing instance - all data stored directly
            existingInstance.name = trimmedName
            existingInstance.exerciseType = exerciseType
            existingInstance.cardioMetric = cardioMetric
            existingInstance.distanceUnit = distanceUnit
            existingInstance.mobilityTracking = mobilityTracking
            existingInstance.primaryMuscles = primaryMuscles
            existingInstance.secondaryMuscles = secondaryMuscles
            existingInstance.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingInstance.setGroups = setGroups
            existingInstance.updatedAt = Date()

            module.updateExercise(existingInstance)
        } else {
            // Create new instance - copy all data from template if selected
            let newInstance = ExerciseInstance(
                templateId: selectedTemplate?.id,
                name: trimmedName,
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                distanceUnit: distanceUnit,
                mobilityTracking: mobilityTracking,
                isBodyweight: selectedTemplate?.isBodyweight ?? false,
                recoveryActivityType: selectedTemplate?.recoveryActivityType,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                setGroups: setGroups,
                order: module.exercises.count,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            module.addExercise(newInstance)
        }

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
        ExerciseFormView(instance: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
