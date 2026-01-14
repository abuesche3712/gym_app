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
    @State private var cardioMetric: CardioMetric = .time
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var progressionType: ProgressionType = .none
    @State private var notes: String = ""
    @State private var setGroups: [SetGroup] = []

    @State private var showingAddSetGroup = false
    @State private var editingSetGroup: EditingIndex?
    @State private var showingExercisePicker = false
    @State private var searchText = ""

    private var isEditing: Bool { exercise != nil }

    var body: some View {
        Form {
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
                    Picker("Tracking", selection: $cardioMetric) {
                        ForEach(CardioMetric.allCases) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }

                    if cardioMetric == .distance {
                        Picker("Distance Unit", selection: $distanceUnit) {
                            ForEach(DistanceUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
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
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
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
                    }
                }
            )
        }
        .onAppear {
            if let exercise = exercise {
                name = exercise.name
                exerciseType = exercise.exerciseType
                cardioMetric = exercise.cardioMetric
                distanceUnit = exercise.distanceUnit
                progressionType = exercise.progressionType
                notes = exercise.notes ?? ""
                setGroups = exercise.setGroups
                // Load template if exists
                if let templateId = exercise.templateId {
                    selectedTemplate = ExerciseLibrary.shared.template(id: templateId)
                }
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
            existingExercise.templateId = selectedTemplate?.id
            existingExercise.exerciseType = exerciseType
            existingExercise.cardioMetric = cardioMetric
            existingExercise.distanceUnit = distanceUnit
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
                templateId: selectedTemplate?.id,
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                distanceUnit: distanceUnit,
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

// MARK: - Exercise Picker View

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTemplate: ExerciseTemplate?
    @Binding var customName: String
    let onSelect: (ExerciseTemplate?) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?

    private var filteredExercises: [ExerciseTemplate] {
        var exercises = ExerciseLibrary.shared.exercises

        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryPill(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(ExerciseCategory.allCases) { category in
                            CategoryPill(title: category.rawValue, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))

                List {
                    // Custom exercise option
                    Section {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            TextField("Type custom exercise name...", text: $customName)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Allow typing
                        }

                        if !customName.isEmpty {
                            Button {
                                selectedTemplate = nil
                                onSelect(nil)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("Use \"\(customName)\"")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("Custom")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Custom Exercise")
                    }

                    // Library exercises
                    Section {
                        ForEach(filteredExercises) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .foregroundColor(.primary)
                                        Text(template.category.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedTemplate?.id == template.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Exercise Library (\(filteredExercises.count))")
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
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
    let cardioMetric: CardioMetric
    let distanceUnit: DistanceUnit
    let existingSetGroup: SetGroup?
    let onSave: (SetGroup) -> Void

    @State private var sets: Int = 1
    @State private var targetReps: Int = 0
    @State private var targetWeight: String = ""
    @State private var targetRPE: Int = 0
    @State private var targetDuration: Int = 0
    @State private var targetDistance: String = ""
    @State private var targetHoldTime: Int = 0
    @State private var restPeriod: Int = 90
    @State private var notes: String = ""

    private var isEditing: Bool { existingSetGroup != nil }
    private var isDistanceBased: Bool { exerciseType == .cardio && cardioMetric == .distance }

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
                    if isDistanceBased {
                        // Distance-based cardio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distance (\(distanceUnit.abbreviation))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Enter distance", text: $targetDistance)
                                .keyboardType(.decimalPad)
                                .font(.title2)

                            // Quick presets
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(distanceUnit.presets, id: \.self) { preset in
                                        Button {
                                            targetDistance = formatPreset(preset)
                                        } label: {
                                            Text("\(formatPreset(preset))\(distanceUnit.abbreviation)")
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color(.systemGray5))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    } else {
                        // Time-based cardio
                        TimePickerView(totalSeconds: $targetDuration, maxMinutes: 60, label: "Duration")
                    }

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
                        targetDuration: !isDistanceBased && targetDuration > 0 ? targetDuration : nil,
                        targetDistance: isDistanceBased ? Double(targetDistance) : nil,
                        targetDistanceUnit: isDistanceBased ? distanceUnit : nil,
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
                targetWeight = existing.targetWeight.map { formatWeight($0) } ?? ""
                targetRPE = existing.targetRPE ?? 0
                targetDuration = existing.targetDuration ?? 0
                targetDistance = existing.targetDistance.map { formatPreset($0) } ?? ""
                targetHoldTime = existing.targetHoldTime ?? 0
                restPeriod = existing.restPeriod ?? 90
                notes = existing.notes ?? ""
            }
        }
    }

    private func formatPreset(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

#Preview {
    NavigationStack {
        ExerciseFormView(exercise: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
