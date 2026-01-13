//
//  ExerciseFormView.swift
//  gym app
//
//  Form for creating/editing an exercise
//

import SwiftUI

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
                    Text("No sets defined")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, setGroup in
                        SetGroupEditRow(setGroup: binding(for: index), index: index + 1)
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
                Text("Sets")
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
                SetGroupFormView(exerciseType: exerciseType) { newSetGroup in
                    setGroups.append(newSetGroup)
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
            } else {
                // Default set group for new exercises
                setGroups = [SetGroup(sets: 3, targetReps: 10, restPeriod: 90)]
            }
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
    let onSave: (SetGroup) -> Void

    @State private var sets: Int = 3
    @State private var targetReps: Int = 10
    @State private var targetWeight: String = ""
    @State private var targetRPE: Int = 0
    @State private var targetDuration: Int = 0
    @State private var targetHoldTime: Int = 0
    @State private var restPeriod: Int = 90
    @State private var notes: String = ""

    var body: some View {
        Form {
            Section("Sets") {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
            }

            Section("Target") {
                switch exerciseType {
                case .strength:
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)
                    TextField("Target Weight (lbs)", text: $targetWeight)
                        .keyboardType(.decimalPad)
                    Picker("RPE", selection: $targetRPE) {
                        Text("None").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }

                case .cardio:
                    Stepper("Duration: \(targetDuration)s", value: $targetDuration, in: 0...3600, step: 30)

                case .isometric:
                    Stepper("Hold Time: \(targetHoldTime)s", value: $targetHoldTime, in: 5...300, step: 5)

                case .mobility:
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...50)

                case .explosive:
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...20)
                }
            }

            Section("Rest") {
                Picker("Rest Period", selection: $restPeriod) {
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                    Text("90s").tag(90)
                    Text("2 min").tag(120)
                    Text("3 min").tag(180)
                    Text("4 min").tag(240)
                    Text("5 min").tag(300)
                }
            }

            Section("Notes") {
                TextField("Notes (e.g., 'top set', 'back-off')", text: $notes)
            }
        }
        .navigationTitle("Add Set Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let setGroup = SetGroup(
                        sets: sets,
                        targetReps: exerciseType == .strength || exerciseType == .mobility || exerciseType == .explosive ? targetReps : nil,
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
    }
}

#Preview {
    NavigationStack {
        ExerciseFormView(exercise: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
