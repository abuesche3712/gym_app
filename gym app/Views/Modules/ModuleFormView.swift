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
    @State private var showingCreateExercise = false
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
            ExercisePickerView(onSelectMultiple: { templates in
                for template in templates {
                    addExerciseFromTemplate(template)
                }
            })
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
        .sheet(isPresented: $showingCreateExercise) {
            AddExerciseSheet(onExerciseCreated: { newTemplate in
                addExerciseFromTemplate(newTemplate)
            })
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
        BuilderQuickAddBar(
            placeholder: "Quick add exercise...",
            text: $searchText,
            accentColor: moduleColor,
            showAddButton: true,
            onAdd: {
                addCustomExercise(name: searchText)
                searchText = ""
            }
        )
    }

    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(quickSearchResults) { template in
                BuilderSearchResultRow(
                    icon: template.exerciseType.icon,
                    iconColor: AppColors.dominant,
                    title: template.name,
                    subtitle: template.exerciseType.displayName,
                    accentColor: moduleColor,
                    onSelect: {
                        addExerciseFromTemplate(template)
                        searchText = ""
                    }
                )

                if template.id != quickSearchResults.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }

    private var emptyExercisesView: some View {
        BuilderEmptyState(
            icon: "dumbbell",
            title: "No exercises yet",
            subtitle: "Search above or browse the library"
        )
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
        let subtitle = exercise.setGroups.isEmpty
            ? exercise.exerciseType.displayName
            : "\(exercise.exerciseType.displayName) • \(formatSetScheme(exercise.setGroups))"

        return BuilderItemRow(
            index: index,
            title: exercise.name,
            subtitle: subtitle,
            accentColor: moduleColor,
            showEditButton: true,
            onEdit: {
                editingExercise = exercise
            },
            onDelete: {
                withAnimation {
                    exercises.remove(at: index)
                    reorderExercises()
                }
            }
        )
    }

    private var browseLibraryButton: some View {
        VStack(spacing: 0) {
            BuilderActionButton(
                icon: "books.vertical",
                title: "Browse Exercise Library",
                color: moduleColor,
                action: { showingExercisePicker = true }
            )

            FormDivider()

            BuilderActionButton(
                icon: "plus.circle",
                title: "Create New Exercise",
                color: AppColors.accent1,
                action: { showingCreateExercise = true }
            )
        }
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

#Preview {
    NavigationStack {
        ModuleFormView(module: nil)
            .environmentObject(ModuleViewModel())
    }
}
