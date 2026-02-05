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

    // Exercises
    @State private var exercises: [ExerciseInstance] = []
    @State private var showingExercisePicker = false
    @State private var showingCreateExercise = false
    @State private var editingExercise: ExerciseInstance?
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @FocusState private var focusedField: Bool

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
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Module" : "New Module")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = false
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = false
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
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        // Ensure exercises are properly ordered
        reorderExercises()

        if var existingModule = module {
            // Update existing module
            existingModule.name = trimmedName
            existingModule.type = type
            existingModule.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
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
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
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
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared

    let exercise: ExerciseInstance
    let onSave: (ExerciseInstance) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var setGroups: [SetGroup] = []
    @State private var notes: String = ""
    @State private var showingAddSetGroup = false
    @State private var editingSetGroupIndex: Int? = nil
    @FocusState private var focusedField: Bool

    // Additional exercise properties
    @State private var isUnilateral: Bool = false
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []
    @State private var selectedImplementIds: Set<UUID> = []
    @State private var showingMusclePicker = false
    @State private var showingEquipmentPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Exercise info
                FormSection(title: "Exercise", icon: "dumbbell", iconColor: AppColors.dominant) {
                    // Name display
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "textformat")
                            .body(color: AppColors.textTertiary)
                            .frame(width: 24)

                        Text(name)
                            .body(color: AppColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfacePrimary)

                    FormDivider()

                    // Type picker
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "tag")
                            .body(color: AppColors.textTertiary)
                            .frame(width: 24)

                        Text("Type")
                            .body(color: AppColors.textPrimary)

                        Spacer()

                        Picker("", selection: $exerciseType) {
                            ForEach(ExerciseType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .tint(AppColors.dominant)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surfacePrimary)

                    // Unilateral toggle (except for cardio)
                    if exerciseType != .cardio {
                        FormDivider()
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "figure.walk")
                                .body(color: AppColors.textTertiary)
                                .frame(width: 24)

                            Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                                .tint(AppColors.accent3)
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surfacePrimary)
                    }
                }

                // Muscles & Equipment section
                musclesAndEquipmentSection

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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                _ = setGroups.remove(at: index)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }

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
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = false
                    onCancel()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    focusedField = false
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
        Button {
            editingSetGroupIndex = index
        } label: {
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

    private func loadExercise() {
        name = exercise.name
        exerciseType = exercise.exerciseType
        setGroups = exercise.setGroups
        notes = exercise.notes ?? ""
        isUnilateral = exercise.isUnilateral
        primaryMuscles = exercise.primaryMuscles
        secondaryMuscles = exercise.secondaryMuscles
        selectedImplementIds = exercise.implementIds
    }

    private func saveExercise() {
        var updated = exercise
        updated.exerciseType = exerciseType
        updated.isUnilateral = isUnilateral
        updated.primaryMuscles = primaryMuscles
        updated.secondaryMuscles = secondaryMuscles
        updated.implementIds = selectedImplementIds
        updated.setGroups = setGroups
        updated.notes = notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        updated.updatedAt = Date()

        // If this instance is linked to a custom template, update the template in the library
        if let templateId = updated.templateId,
           let customTemplate = customLibrary.exercises.first(where: { $0.id == templateId }) {
            var updatedTemplate = customTemplate
            updatedTemplate.name = name
            updatedTemplate.exerciseType = exerciseType
            updatedTemplate.primaryMuscles = primaryMuscles
            updatedTemplate.secondaryMuscles = secondaryMuscles
            updatedTemplate.isUnilateral = isUnilateral
            updatedTemplate.implementIds = selectedImplementIds
            customLibrary.updateExercise(updatedTemplate)
        }

        onSave(updated)
    }

    // MARK: - Muscles & Equipment Section

    private var musclesAndEquipmentSection: some View {
        FormSection(title: "Muscles & Equipment", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accent1) {
            // Muscles row
            Button {
                showingMusclePicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.arms.open")
                        .body(color: AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Muscles")
                        .body(color: AppColors.textPrimary)

                    Spacer()

                    if primaryMuscles.isEmpty && secondaryMuscles.isEmpty {
                        Text("None")
                            .body(color: AppColors.textTertiary)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            if !primaryMuscles.isEmpty {
                                Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                    .caption(color: AppColors.dominant)
                                    .lineLimit(1)
                            }
                            if !secondaryMuscles.isEmpty {
                                Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                    .caption(color: AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingMusclePicker) {
                NavigationStack {
                    MuscleGroupEnumPickerView(
                        primaryMuscles: $primaryMuscles,
                        secondaryMuscles: $secondaryMuscles
                    )
                    .navigationTitle("Muscles")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingMusclePicker = false
                            }
                            .foregroundColor(AppColors.dominant)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }

            FormDivider()

            // Equipment row
            Button {
                showingEquipmentPicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "dumbbell")
                        .body(color: AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Equipment")
                        .body(color: AppColors.textPrimary)

                    Spacer()

                    if selectedImplementIds.isEmpty {
                        Text("None")
                            .body(color: AppColors.textTertiary)
                    } else {
                        Text(equipmentNames.joined(separator: ", "))
                            .caption(color: AppColors.accent1)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingEquipmentPicker) {
                NavigationStack {
                    ScrollView {
                        ImplementPickerView(selectedIds: $selectedImplementIds)
                            .padding()
                    }
                    .background(AppColors.background.ignoresSafeArea())
                    .navigationTitle("Equipment")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingEquipmentPicker = false
                            }
                            .foregroundColor(AppColors.dominant)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var equipmentNames: [String] {
        selectedImplementIds.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }
}

#Preview {
    NavigationStack {
        ModuleFormView(module: nil)
            .environmentObject(ModuleViewModel())
    }
}
