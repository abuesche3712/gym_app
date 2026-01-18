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
    @State private var standaloneExercises: [Exercise] = []

    @State private var showingModulePicker = false
    @State private var showingExercisePicker = false

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
                    ForEach(selectedModuleIds, id: \.self) { moduleId in
                        if let module = moduleViewModel.getModule(id: moduleId) {
                            NavigationLink(destination: ModuleDetailView(module: module)) {
                                HStack {
                                    Image(systemName: module.type.icon)
                                        .foregroundStyle(module.type.color)

                                    VStack(alignment: .leading) {
                                        Text(module.name)
                                            .font(.subheadline)
                                        Text("\(module.exercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
                    if !selectedModuleIds.isEmpty {
                        EditButton()
                            .font(.caption)
                    }
                }
            }

            // Standalone Exercises Section
            Section {
                if standaloneExercises.isEmpty {
                    Text("No exercises added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(standaloneExercises.enumerated()), id: \.element.id) { index, exercise in
                        HStack {
                            Image(systemName: exercise.exerciseType.icon)
                                .foregroundStyle(AppColors.accentBlue)

                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                Text(exercise.formattedSetScheme.isEmpty ? "No sets" : exercise.formattedSetScheme)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: removeExercise)
                    .onMove(perform: moveExercise)
                }

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Standalone Exercises")
                    Spacer()
                    if !standaloneExercises.isEmpty {
                        EditButton()
                            .font(.caption)
                    }
                }
            } footer: {
                Text("Add exercises directly without creating a module")
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
        .sheet(isPresented: $showingExercisePicker) {
            QuickExerciseFormView { exercise in
                standaloneExercises.append(exercise)
            }
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
                standaloneExercises = workout.standaloneExercises
                    .sorted { $0.order < $1.order }
                    .map { $0.exercise }
            }
        }
    }

    private func removeModule(at offsets: IndexSet) {
        selectedModuleIds.remove(atOffsets: offsets)
    }

    private func moveModule(from source: IndexSet, to destination: Int) {
        selectedModuleIds.move(fromOffsets: source, toOffset: destination)
    }

    private func removeExercise(at offsets: IndexSet) {
        standaloneExercises.remove(atOffsets: offsets)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        standaloneExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func saveWorkout() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let duration = Int(estimatedDuration)

        let moduleRefs = selectedModuleIds.enumerated().map { index, moduleId in
            ModuleReference(moduleId: moduleId, order: index)
        }

        let workoutExercises = standaloneExercises.enumerated().map { index, exercise in
            WorkoutExercise(exercise: exercise, order: index)
        }

        if var existingWorkout = workout {
            existingWorkout.name = trimmedName
            existingWorkout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingWorkout.estimatedDuration = duration
            existingWorkout.moduleReferences = moduleRefs
            existingWorkout.standaloneExercises = workoutExercises
            existingWorkout.updatedAt = Date()
            workoutViewModel.saveWorkout(existingWorkout)
        } else {
            let newWorkout = Workout(
                name: trimmedName,
                moduleReferences: moduleRefs,
                standaloneExercises: workoutExercises,
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
                                color: type.color
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
                            HStack(spacing: 12) {
                                Image(systemName: module.type.icon)
                                    .foregroundStyle(module.type.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.name)
                                        .font(.subheadline)
                                    Text("\(module.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if selectedModuleIds.contains(module.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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

// MARK: - Quick Exercise Form

struct QuickExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Exercise) -> Void

    @State private var name: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength
    @State private var muscleGroupIds: Set<UUID> = []
    @State private var implementIds: Set<UUID> = []

    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var targetWeight: String = ""
    @State private var targetDuration: Int = 60
    @State private var targetHoldTime: Int = 30
    @State private var targetDistance: String = ""
    @State private var distanceUnit: DistanceUnit = .miles
    @State private var cardioMetric: CardioMetric = .timeOnly
    @State private var restPeriod: Int = 90

    @State private var showingExercisePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        HStack {
                            Text("Exercise")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(name.isEmpty ? "Select exercise..." : name)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !name.isEmpty {
                        Picker("Type", selection: $exerciseType) {
                            ForEach(ExerciseType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                    }
                }

                if !name.isEmpty {
                    Section("Set Configuration") {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...20)

                        switch exerciseType {
                        case .strength:
                            Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                            HStack {
                                Text("Target Weight")
                                Spacer()
                                TextField("0", text: $targetWeight)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text("lbs")
                                    .foregroundStyle(.secondary)
                            }

                        case .cardio:
                            Picker("Track", selection: $cardioMetric) {
                                ForEach(CardioMetric.allCases) { metric in
                                    Text(metric.displayName).tag(metric)
                                }
                            }
                            if cardioMetric.tracksTime {
                                TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, maxHours: 4, label: "Duration")
                            }
                            if cardioMetric.tracksDistance {
                                HStack {
                                    Text("Distance")
                                    Spacer()
                                    TextField("0", text: $targetDistance)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                    Picker("", selection: $distanceUnit) {
                                        ForEach(DistanceUnit.allCases) { unit in
                                            Text(unit.abbreviation).tag(unit)
                                        }
                                    }
                                    .frame(width: 70)
                                }
                            }

                        case .isometric:
                            TimePickerView(totalSeconds: $targetHoldTime, maxMinutes: 5, label: "Hold Time")

                        case .mobility, .explosive:
                            Stepper("Reps: \(reps)", value: $reps, in: 1...100)

                        case .recovery:
                            TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, maxHours: 4, label: "Duration")
                        }

                        Stepper("Rest: \(restPeriod)s", value: $restPeriod, in: 0...300, step: 15)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveExercise()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                            muscleGroupIds = template.muscleGroupIds
                            implementIds = template.implementIds
                        }
                    },
                    onSelectWithDetails: { template, type, muscles, implements in
                        if let template = template {
                            name = template.name
                            exerciseType = template.exerciseType
                            selectedTemplate = template
                            muscleGroupIds = template.muscleGroupIds
                            implementIds = template.implementIds
                        } else {
                            exerciseType = type
                        }
                        muscleGroupIds.formUnion(muscles)
                        implementIds.formUnion(implements)
                    }
                )
            }
        }
    }

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        var setGroup: SetGroup

        switch exerciseType {
        case .strength:
            setGroup = SetGroup(
                sets: sets,
                targetReps: reps,
                targetWeight: Double(targetWeight),
                restPeriod: restPeriod
            )
        case .cardio:
            setGroup = SetGroup(
                sets: sets,
                targetDuration: cardioMetric.tracksTime ? targetDuration : nil,
                targetDistance: cardioMetric.tracksDistance ? Double(targetDistance) : nil,
                restPeriod: restPeriod
            )
        case .isometric:
            setGroup = SetGroup(
                sets: sets,
                targetHoldTime: targetHoldTime,
                restPeriod: restPeriod
            )
        case .mobility, .explosive:
            setGroup = SetGroup(
                sets: sets,
                targetReps: reps,
                restPeriod: restPeriod
            )
        case .recovery:
            setGroup = SetGroup(
                sets: sets,
                targetDuration: targetDuration,
                restPeriod: 0  // No rest for recovery activities
            )
        }

        let exercise = Exercise(
            name: trimmedName,
            templateId: selectedTemplate?.id,
            exerciseType: exerciseType,
            cardioMetric: cardioMetric,
            distanceUnit: distanceUnit,
            setGroups: [setGroup],
            muscleGroupIds: muscleGroupIds,
            implementIds: implementIds
        )

        onSave(exercise)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutFormView(workout: nil)
            .environmentObject(WorkoutViewModel())
            .environmentObject(ModuleViewModel())
    }
}
