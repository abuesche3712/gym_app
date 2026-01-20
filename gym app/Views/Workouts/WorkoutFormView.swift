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
    @State private var standaloneExercises: [ExerciseInstance] = []

    @State private var showingModulePicker = false
    @State private var showingExercisePicker = false

    private var isEditing: Bool { workout != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Workout Info Section
                FormSection(title: "Workout Info", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accentBlue) {
                    FormTextField(label: "Name", text: $name, icon: "textformat", placeholder: "e.g., Monday - Lower A")
                    FormDivider()
                    FormTextField(label: "Duration", text: $estimatedDuration, icon: "clock", placeholder: "minutes", keyboardType: .numberPad)
                }

                // Modules Section
                FormSection(title: "Modules", icon: "square.stack.3d.up", iconColor: AppColors.accentTeal) {
                    if selectedModuleIds.isEmpty {
                        HStack {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)
                            Text("No modules added")
                                .foregroundColor(AppColors.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.cardBackground)
                    } else {
                        ForEach(Array(selectedModuleIds.enumerated()), id: \.element) { index, moduleId in
                            if let module = moduleViewModel.getModule(id: moduleId) {
                                VStack(spacing: 0) {
                                    if index > 0 {
                                        FormDivider()
                                    }
                                    moduleRow(module: module, index: index)
                                }
                            }
                        }
                    }

                    FormDivider()

                    // Add Module Button
                    Button {
                        showingModulePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accentTeal)
                                .frame(width: 24)
                            Text("Add Module")
                                .foregroundColor(AppColors.accentTeal)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Standalone Exercises Section
                FormSection(title: "Standalone Exercises", icon: "dumbbell", iconColor: AppColors.accentBlue) {
                    if standaloneExercises.isEmpty {
                        HStack {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)
                            Text("No exercises added")
                                .foregroundColor(AppColors.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.cardBackground)
                    } else {
                        ForEach(Array(standaloneExercises.enumerated()), id: \.element.id) { index, instance in
                            let resolved = ExerciseResolver.shared.resolve(instance)
                            VStack(spacing: 0) {
                                if index > 0 {
                                    FormDivider()
                                }
                                exerciseRow(resolved: resolved)
                            }
                        }
                    }

                    FormDivider()

                    // Add Exercise Button
                    Button {
                        showingExercisePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 24)
                            Text("Add Exercise")
                                .foregroundColor(AppColors.accentBlue)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Footer
                    Text("Add exercises directly without creating a module")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                }

                // Notes Section
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Workout" : "New Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.accentBlue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingModulePicker) {
            ModulePickerView(selectedModuleIds: $selectedModuleIds)
        }
        .sheet(isPresented: $showingExercisePicker) {
            QuickExerciseFormView { instance in
                standaloneExercises.append(instance)
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
                    .map(\.exercise)
            }
        }
    }

    // MARK: - Row Views

    private func moduleRow(module: Module, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: module.type.icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.moduleColor(module.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(module.exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button {
                selectedModuleIds.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private func exerciseRow(resolved: ResolvedExercise) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: resolved.exerciseType.icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(resolved.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(resolved.formattedSetScheme.isEmpty ? "No sets" : resolved.formattedSetScheme)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
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

        let workoutExercises = standaloneExercises.enumerated().map { index, instance in
            WorkoutExercise(exercise: instance, order: index)
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

    let onSave: (ExerciseInstance) -> Void

    @State private var name: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength

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
                        }
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

        // Create self-contained instance with all data
        let instance = ExerciseInstance(
            templateId: selectedTemplate?.id,
            name: trimmedName,
            exerciseType: exerciseType,
            cardioMetric: cardioMetric,
            distanceUnit: distanceUnit,
            mobilityTracking: .repsOnly,
            isBodyweight: selectedTemplate?.isBodyweight ?? false,
            recoveryActivityType: selectedTemplate?.recoveryActivityType,
            primaryMuscles: selectedTemplate?.primaryMuscles ?? [],
            secondaryMuscles: selectedTemplate?.secondaryMuscles ?? [],
            implementIds: selectedTemplate?.implementIds ?? [],
            setGroups: [setGroup]
        )

        onSave(instance)
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
