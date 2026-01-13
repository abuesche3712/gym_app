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
    @State private var exerciseType: ExerciseType = .strength
    @State private var progressionType: ProgressionType = .none
    @State private var notes: String = ""
    @State private var setGroups: [SetGroup] = []

    @State private var showingAddSetGroup = false
    @State private var editingSetGroup: EditingIndex?

    private var isEditing: Bool { exercise != nil }

    var body: some View {
        Form {
            Section("Exercise Info") {
                TextField("Name", text: $name)

                Picker("Type", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Picker("Progression", selection: $progressionType) {
                    ForEach(ProgressionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

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

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
            }
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
                SetGroupFormView(exerciseType: exerciseType, existingSetGroup: nil) { newSetGroup in
                    setGroups.append(newSetGroup)
                }
            }
        }
        .sheet(item: $editingSetGroup) { editing in
            NavigationStack {
                SetGroupFormView(exerciseType: exerciseType, existingSetGroup: setGroups[editing.index]) { updatedSetGroup in
                    setGroups[editing.index] = updatedSetGroup
                }
            }
        }
        .onAppear {
            if let exercise = exercise {
                name = exercise.name
                exerciseType = exercise.exerciseType
                progressionType = exercise.progressionType
                notes = exercise.notes ?? ""
                setGroups = exercise.setGroups
            }
            // New exercises start with no set groups - user adds them explicitly
        }
    }

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

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        guard var module = moduleViewModel.getModule(id: moduleId) else { return }

        if var existingExercise = exercise {
            // Update existing
            existingExercise.name = trimmedName
            existingExercise.exerciseType = exerciseType
            existingExercise.progressionType = progressionType
            existingExercise.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingExercise.setGroups = setGroups
            existingExercise.updatedAt = Date()

            if let index = module.exercises.firstIndex(where: { $0.id == existingExercise.id }) {
                module.exercises[index] = existingExercise
            }
        } else {
            // Create new
            let newExercise = Exercise(
                name: trimmedName,
                exerciseType: exerciseType,
                setGroups: setGroups,
                progressionType: progressionType,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
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

// MARK: - Set Group Form

struct SetGroupFormView: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseType: ExerciseType
    let existingSetGroup: SetGroup?
    let onSave: (SetGroup) -> Void

    @State private var sets: Int = 1
    @State private var targetReps: Int = 0
    @State private var targetWeight: String = ""
    @State private var targetRPE: Int = 0
    @State private var targetDuration: Int = 0
    @State private var targetHoldTime: Int = 0
    @State private var restPeriod: Int = 90
    @State private var notes: String = ""

    private var isEditing: Bool { existingSetGroup != nil }

    var body: some View {
        Form {
            Section("Sets") {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
            }

            Section("Target") {
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
                    TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, label: "Duration")

                case .isometric:
                    TimePickerView(totalSeconds: $targetHoldTime, maxMinutes: 5, label: "Hold Time")

                case .mobility:
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)

                case .explosive:
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...20)
                }
            }

            Section("Rest Between Sets") {
                TimePickerView(totalSeconds: $restPeriod, maxMinutes: 5, label: "Rest Period", compact: true)
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
                    let setGroup = SetGroup(
                        id: existingSetGroup?.id ?? UUID(),
                        sets: sets,
                        targetReps: exerciseType == .strength || exerciseType == .mobility || exerciseType == .explosive ? (targetReps > 0 ? targetReps : nil) : nil,
                        targetWeight: Double(targetWeight),
                        targetRPE: targetRPE > 0 ? targetRPE : nil,
                        targetDuration: targetDuration > 0 ? targetDuration : nil,
                        targetHoldTime: targetHoldTime > 0 ? targetHoldTime : nil,
                        restPeriod: restPeriod,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onSave(setGroup)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let existing = existingSetGroup {
                sets = existing.sets
                targetReps = existing.targetReps ?? 0
                targetWeight = existing.targetWeight.map { String(format: "%.0f", $0) } ?? ""
                targetRPE = existing.targetRPE ?? 0
                targetDuration = existing.targetDuration ?? 0
                targetHoldTime = existing.targetHoldTime ?? 0
                restPeriod = existing.restPeriod ?? 90
                notes = existing.notes ?? ""
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseFormView(exercise: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
