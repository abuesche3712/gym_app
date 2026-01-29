//
//  ModuleFormView.swift
//  gym app
//
//  Form for creating/editing a module - all in one view
//

import SwiftUI

struct ModuleFormView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resolver = ExerciseResolver.shared

    let module: Module?
    var onCreated: ((Module) -> Void)?

    // Module info
    @State private var name: String = ""
    @State private var type: ModuleType = .strength
    @State private var notes: String = ""
    @State private var estimatedDuration: String = ""

    // Exercises
    @State private var exercises: [ExerciseInstance] = []
    @State private var showingExercisePicker = false
    @State private var editingExercise: ExerciseInstance?
    @State private var searchText = ""
    @State private var isSearchFocused = false

    private var isEditing: Bool { module != nil }

    private var moduleColor: Color {
        AppColors.moduleColor(type)
    }

    // Quick search results
    private var quickSearchResults: [ExerciseTemplate] {
        guard !searchText.isEmpty else { return [] }
        let allExercises = resolver.builtInExercises + resolver.customExercises
        return allExercises
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Module Info Section
                moduleInfoSection

                // Exercises Section
                exercisesSection

                // Notes Section
                notesSection
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Module" : "New Module")
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
                    saveModule()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.dominant)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerSheet(onSelect: { templates in
                    for template in templates {
                        addExerciseFromTemplate(template)
                    }
                })
            }
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                InlineExerciseEditor(
                    exercise: exercise,
                    onSave: { updatedExercise in
                        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
                            exercises[index] = updatedExercise
                        }
                        editingExercise = nil
                    },
                    onCancel: {
                        editingExercise = nil
                    }
                )
            }
        }
        .onAppear {
            loadModule()
        }
    }

    // MARK: - Module Info Section

    private var moduleInfoSection: some View {
        FormSection(title: "Module Info", icon: "square.stack.3d.up", iconColor: moduleColor) {
            FormTextField(label: "Name", text: $name, icon: "textformat", placeholder: "e.g., Upper Body Push")
            FormDivider()
            typePickerRow
            FormDivider()
            FormTextField(label: "Duration", text: $estimatedDuration, icon: "clock", placeholder: "minutes", keyboardType: .numberPad)
        }
    }

    private var typePickerRow: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "tag")
                .body(color: AppColors.textTertiary)
                .frame(width: 24)

            Text("Type")
                .body(color: AppColors.textPrimary)

            Spacer()

            Picker("", selection: $type) {
                ForEach(ModuleType.allCases) { moduleType in
                    Label(moduleType.displayName, systemImage: moduleType.icon)
                        .tag(moduleType)
                }
            }
            .tint(moduleColor)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        FormSection(title: "Exercises", icon: "dumbbell", iconColor: moduleColor) {
            VStack(spacing: 0) {
                // Quick add search bar
                quickAddBar

                // Search results dropdown
                if !searchText.isEmpty && !quickSearchResults.isEmpty {
                    searchResultsDropdown
                }

                FormDivider()

                // Exercise list
                if exercises.isEmpty {
                    emptyExercisesView
                } else {
                    exercisesList
                }

                FormDivider()

                // Browse library button
                browseLibraryButton
            }
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .body(color: AppColors.textTertiary)
                .frame(width: 24)

            TextField("Quick add exercise...", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit {
                    if !searchText.isEmpty {
                        addCustomExercise(name: searchText)
                        searchText = ""
                    }
                }

            if !searchText.isEmpty {
                Button {
                    addCustomExercise(name: searchText)
                    searchText = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .displaySmall(color: moduleColor)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(quickSearchResults) { template in
                Button {
                    addExerciseFromTemplate(template)
                    searchText = ""
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: template.exerciseType.icon)
                            .subheadline(color: AppColors.dominant)
                            .frame(width: 24)

                        Text(template.name)
                            .subheadline(color: AppColors.textPrimary)

                        Spacer()

                        Text(template.exerciseType.displayName)
                            .caption(color: AppColors.textTertiary)

                        Image(systemName: "plus.circle")
                            .body(color: moduleColor)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surfaceTertiary)
                }
                .buttonStyle(.plain)

                if template.id != quickSearchResults.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }

    private var emptyExercisesView: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "dumbbell")
                .displaySmall(color: AppColors.textTertiary.opacity(0.5))

            Text("No exercises yet")
                .subheadline(color: AppColors.textTertiary)

            Text("Search above or browse the library")
                .caption(color: AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.surfacePrimary)
    }

    private var exercisesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(exercise: exercise, index: index)

                if index < exercises.count - 1 {
                    FormDivider()
                }
            }
        }
    }

    private func exerciseRow(exercise: ExerciseInstance, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Drag handle / order indicator
            ZStack {
                Circle()
                    .fill(moduleColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .caption(color: moduleColor)
                    .fontWeight(.semibold)
            }

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                HStack(spacing: AppSpacing.sm) {
                    Text(exercise.exerciseType.displayName)
                        .caption(color: AppColors.textSecondary)

                    if !exercise.setGroups.isEmpty {
                        Text("•")
                            .caption(color: AppColors.textTertiary)
                        Text(formatSetScheme(exercise.setGroups))
                            .caption(color: AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Edit button
            Button {
                editingExercise = exercise
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .subheadline(color: AppColors.textTertiary)
                    .frame(width: 32, height: 32)
            }

            // Delete button
            Button {
                withAnimation {
                    exercises.remove(at: index)
                    reorderExercises()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .body(color: AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var browseLibraryButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "books.vertical")
                    .body(color: moduleColor)
                    .frame(width: 24)

                Text("Browse Exercise Library")
                    .body(color: moduleColor)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Actions

    private func loadModule() {
        if let module = module {
            name = module.name
            type = module.type
            notes = module.notes ?? ""
            if let duration = module.estimatedDuration {
                estimatedDuration = "\(duration)"
            }
            exercises = module.exercises
        }
    }

    private func addExerciseFromTemplate(_ template: ExerciseTemplate) {
        let instance = ExerciseInstance(
            templateId: template.id,
            name: template.name,
            exerciseType: template.exerciseType,
            primaryMuscles: template.primaryMuscles,
            secondaryMuscles: template.secondaryMuscles,
            implementIds: template.implementIds,
            order: exercises.count
        )
        withAnimation {
            exercises.append(instance)
        }
    }

    private func addCustomExercise(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Check if it matches a template
        if let template = resolver.findTemplate(named: trimmedName) {
            addExerciseFromTemplate(template)
        } else {
            // Create custom exercise - use cardio type if module is cardio-focused
            let exerciseType: ExerciseType = (type == .cardioLong || type == .cardioSpeed) ? .cardio : .strength
            let instance = ExerciseInstance(
                templateId: nil,
                name: trimmedName,
                exerciseType: exerciseType,
                order: exercises.count
            )
            withAnimation {
                exercises.append(instance)
            }
        }
    }

    private func reorderExercises() {
        for i in exercises.indices {
            exercises[i].order = i
        }
    }

    private func formatSetScheme(_ setGroups: [SetGroup]) -> String {
        setGroups.map { group in
            if let reps = group.targetReps {
                return "\(group.sets)×\(reps)"
            } else if let duration = group.targetDuration {
                return "\(group.sets)×\(duration)s"
            }
            return "\(group.sets) sets"
        }.joined(separator: " + ")
    }

    private func saveModule() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let duration = Int(estimatedDuration)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        // Ensure exercises are properly ordered
        reorderExercises()

        if var existingModule = module {
            // Update existing module
            existingModule.name = trimmedName
            existingModule.type = type
            existingModule.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingModule.estimatedDuration = duration
            existingModule.exercises = exercises
            existingModule.updatedAt = Date()
            moduleViewModel.saveModule(existingModule)
            dismiss()
        } else {
            // Create new module with exercises
            let newModule = Module(
                name: trimmedName,
                type: type,
                exercises: exercises,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                estimatedDuration: duration
            )
            moduleViewModel.saveModule(newModule)
            dismiss()

            if let onCreated = onCreated {
                onCreated(newModule)
            }
        }
    }
}

// MARK: - Inline Exercise Editor

struct InlineExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var libraryService = LibraryService.shared

    let exercise: ExerciseInstance
    let onSave: (ExerciseInstance) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var setGroups: [SetGroup] = []
    @State private var notes: String = ""
    @State private var showingAddSetGroup = false
    @State private var editingSetGroupIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Exercise info
                FormSection(title: "Exercise", icon: "dumbbell", iconColor: AppColors.dominant) {
                    // Name (read-only for now)
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "textformat")
                            .body(color: AppColors.textTertiary)
                            .frame(width: 24)

                        Text(name)
                            .body(color: AppColors.textPrimary)

                        Spacer()

                        Text(exerciseType.displayName)
                            .caption(color: AppColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.surfaceTertiary)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfacePrimary)
                }

                // Sets section
                FormSection(title: "Sets", icon: "list.number", iconColor: AppColors.dominant) {
                    VStack(spacing: 0) {
                        if setGroups.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .body(color: AppColors.textTertiary)
                                Text("No sets defined")
                                    .body(color: AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.surfacePrimary)
                        } else {
                            ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, setGroup in
                                setGroupRow(setGroup: setGroup, index: index)

                                if index < setGroups.count - 1 {
                                    FormDivider()
                                }
                            }
                        }

                        FormDivider()

                        // Add set group button
                        Button {
                            showingAddSetGroup = true
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "plus.circle.fill")
                                    .body(color: AppColors.dominant)
                                    .frame(width: 24)

                                Text("Add Set Group")
                                    .body(color: AppColors.dominant)
                                    .fontWeight(.medium)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.surfacePrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Notes
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .padding(AppSpacing.md)
                        .background(AppColors.surfacePrimary)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveExercise()
                }
                .fontWeight(.semibold)
                .foregroundColor(AppColors.dominant)
            }
        }
        .sheet(isPresented: $showingAddSetGroup) {
            NavigationStack {
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: exercise.cardioMetric,
                    mobilityTracking: exercise.mobilityTracking,
                    distanceUnit: exercise.distanceUnit,
                    implementIds: exercise.implementIds,
                    isBodyweight: exercise.isBodyweight,
                    existingSetGroup: nil
                ) { newSetGroup in
                    setGroups.append(newSetGroup)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSetGroupIndex != nil },
            set: { if !$0 { editingSetGroupIndex = nil } }
        )) {
            if let index = editingSetGroupIndex, index < setGroups.count {
                NavigationStack {
                    SetGroupFormView(
                        exerciseType: exerciseType,
                        cardioMetric: exercise.cardioMetric,
                        mobilityTracking: exercise.mobilityTracking,
                        distanceUnit: exercise.distanceUnit,
                        implementIds: exercise.implementIds,
                        isBodyweight: exercise.isBodyweight,
                        existingSetGroup: setGroups[index]
                    ) { updatedSetGroup in
                        setGroups[index] = updatedSetGroup
                    }
                }
            }
        }
        .onAppear {
            loadExercise()
        }
    }

    private func setGroupRow(setGroup: SetGroup, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.dominant.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .caption(color: AppColors.dominant)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(setGroup.formattedTarget)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                if let rest = setGroup.formattedRest {
                    Text("Rest: \(rest)")
                        .caption(color: AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                editingSetGroupIndex = index
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .body(color: AppColors.textTertiary.opacity(0.6))
            }

            Button {
                setGroups.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .body(color: AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private func loadExercise() {
        name = exercise.name
        exerciseType = exercise.exerciseType
        setGroups = exercise.setGroups
        notes = exercise.notes ?? ""
    }

    private func saveExercise() {
        var updated = exercise
        updated.setGroups = setGroups
        updated.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        updated.updatedAt = Date()
        onSave(updated)
    }
}

// MARK: - Exercise Picker Sheet (Simplified)

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resolver = ExerciseResolver.shared

    let onSelect: ([ExerciseTemplate]) -> Void

    @State private var searchText = ""
    @State private var selectedType: ExerciseType?
    @State private var selectedTemplates: [ExerciseTemplate] = []

    private var filteredExercises: [ExerciseTemplate] {
        var exercises = resolver.builtInExercises + resolver.customExercises

        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    private func isSelected(_ template: ExerciseTemplate) -> Bool {
        selectedTemplates.contains { $0.id == template.id }
    }

    private func toggleSelection(_ template: ExerciseTemplate) {
        if let index = selectedTemplates.firstIndex(where: { $0.id == template.id }) {
            selectedTemplates.remove(at: index)
        } else {
            selectedTemplates.append(template)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    FilterChip(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(ExerciseType.allCases) { type in
                        FilterChip(title: type.displayName, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.surfaceTertiary)

            // Exercise list
            List {
                ForEach(filteredExercises) { template in
                    Button {
                        toggleSelection(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .body(color: AppColors.textPrimary)

                                Text(template.exerciseType.displayName)
                                    .caption(color: AppColors.textSecondary)
                            }

                            Spacer()

                            if isSelected(template) {
                                Image(systemName: "checkmark.circle.fill")
                                    .displaySmall(color: AppColors.success)
                            } else {
                                Image(systemName: "circle")
                                    .displaySmall(color: AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            // Add button when exercises are selected
            if !selectedTemplates.isEmpty {
                Button {
                    onSelect(selectedTemplates)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(selectedTemplates.count) Exercise\(selectedTemplates.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.dominant)
                    .foregroundColor(.white)
                    .cornerRadius(AppCorners.medium)
                }
                .padding(AppSpacing.screenPadding)
                .background(AppColors.background)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search exercises...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .subheadline(color: isSelected ? .white : AppColors.textPrimary)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.dominant : AppColors.surfacePrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.surfaceTertiary, lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        ModuleFormView(module: nil)
            .environmentObject(ModuleViewModel())
    }
}
