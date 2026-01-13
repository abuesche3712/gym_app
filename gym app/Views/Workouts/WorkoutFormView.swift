//
//  WorkoutFormView.swift
//  gym app
//
//  Form for creating/editing a workout
//

import SwiftUI

struct WorkoutFormView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let workout: Workout?

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var estimatedDuration: String = ""
    @State private var selectedModuleIds: [UUID] = []

    @State private var showingModulePicker = false

    private var isEditing: Bool { workout != nil }

    var body: some View {
        Form {
            Section("Workout Info") {
                TextField("Name (e.g., Monday - Lower A)", text: $name)

                TextField("Estimated Duration (minutes)", text: $estimatedDuration)
                    .keyboardType(.numberPad)
            }

            Section {
                if selectedModuleIds.isEmpty {
                    Text("No modules added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(selectedModuleIds.enumerated()), id: \.element) { index, moduleId in
                        if let module = moduleViewModel.getModule(id: moduleId) {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 24, height: 24)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())

                                Image(systemName: module.type.icon)
                                    .foregroundStyle(Color(module.type.color))

                                VStack(alignment: .leading) {
                                    Text(module.name)
                                        .font(.subheadline)
                                    Text(module.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: removeModule)
                    .onMove(perform: moveModule)
                }

                Button {
                    showingModulePicker = true
                } label: {
                    Label("Add Module", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Modules")
                    Spacer()
                    EditButton()
                        .font(.caption)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
            }
        }
        .navigationTitle(isEditing ? "Edit Workout" : "New Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingModulePicker) {
            ModulePickerView(selectedModuleIds: $selectedModuleIds)
        }
        .onAppear {
            if let workout = workout {
                name = workout.name
                notes = workout.notes ?? ""
                if let duration = workout.estimatedDuration {
                    estimatedDuration = "\(duration)"
                }
                selectedModuleIds = workout.moduleReferences
                    .sorted { $0.order < $1.order }
                    .map { $0.moduleId }
            }
        }
    }

    private func removeModule(at offsets: IndexSet) {
        selectedModuleIds.remove(atOffsets: offsets)
    }

    private func moveModule(from source: IndexSet, to destination: Int) {
        selectedModuleIds.move(fromOffsets: source, toOffset: destination)
    }

    private func saveWorkout() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let duration = Int(estimatedDuration)

        let moduleRefs = selectedModuleIds.enumerated().map { index, moduleId in
            ModuleReference(moduleId: moduleId, order: index)
        }

        if var existingWorkout = workout {
            existingWorkout.name = trimmedName
            existingWorkout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingWorkout.estimatedDuration = duration
            existingWorkout.moduleReferences = moduleRefs
            existingWorkout.updatedAt = Date()
            workoutViewModel.saveWorkout(existingWorkout)
        } else {
            let newWorkout = Workout(
                name: trimmedName,
                moduleReferences: moduleRefs,
                estimatedDuration: duration,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            workoutViewModel.saveWorkout(newWorkout)
        }

        dismiss()
    }
}

// MARK: - Module Picker

struct ModulePickerView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModuleIds: [UUID]

    @State private var selectedType: ModuleType?

    var filteredModules: [Module] {
        if let type = selectedType {
            return moduleViewModel.modules.filter { $0.type == type }
        }
        return moduleViewModel.modules
    }

    var body: some View {
        NavigationStack {
            List {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                        }

                        ForEach(ModuleType.allCases) { type in
                            FilterPill(
                                title: type.displayName,
                                isSelected: selectedType == type,
                                color: Color(type.color)
                            ) {
                                selectedType = type
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if filteredModules.isEmpty {
                    ContentUnavailableView(
                        "No Modules",
                        systemImage: "square.stack.3d.up",
                        description: Text("Create modules first to add them to workouts")
                    )
                } else {
                    ForEach(filteredModules) { module in
                        Button {
                            if !selectedModuleIds.contains(module.id) {
                                selectedModuleIds.append(module.id)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: module.type.icon)
                                    .foregroundStyle(Color(module.type.color))

                                VStack(alignment: .leading) {
                                    Text(module.name)
                                        .font(.subheadline)
                                    Text("\(module.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedModuleIds.contains(module.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutFormView(workout: nil)
            .environmentObject(WorkoutViewModel())
            .environmentObject(ModuleViewModel())
    }
}
