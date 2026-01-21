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
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.accentBlue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerSheet(onSelect: { template in
                    addExerciseFromTemplate(template)
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
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            Text("Type")
                .foregroundColor(AppColors.textPrimary)

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
        .background(AppColors.cardBackground)
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
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
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
                        .font(.system(size: 20))
                        .foregroundColor(moduleColor)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
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
                            .font(.system(size: 14))
                            .foregroundColor(template.exerciseType.color)
                            .frame(width: 24)

                        Text(template.name)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(template.exerciseType.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(moduleColor)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surfaceLight)
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
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary.opacity(0.5))

            Text("No exercises yet")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)

            Text("Search above or browse the library")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.cardBackground)
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
                    .font(.caption.weight(.semibold))
                    .foregroundColor(moduleColor)
            }

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    Text(exercise.exerciseType.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    if !exercise.setGroups.isEmpty {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text(exercise.formattedSetScheme)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Edit button
            Button {
                editingExercise = exercise
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
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
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private var browseLibraryButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 16))
                    .foregroundColor(moduleColor)
                    .frame(width: 24)

                Text("Browse Exercise Library")
                    .foregroundColor(moduleColor)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
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
            // Create custom exercise
            let instance = ExerciseInstance(
                templateId: nil,
                name: trimmedName,
                exerciseType: type == .cardio ? .cardio : .strength,
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

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Exercise info
                FormSection(title: "Exercise", icon: "dumbbell", iconColor: AppColors.accentBlue) {
                    // Name (read-only for now)
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "textformat")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 24)

                        Text(name)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(exerciseType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.surfaceLight)
                            .foregroundColor(AppColors.textSecondary)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.cardBackground)
                }

                // Sets section
                FormSection(title: "Sets", icon: "list.number", iconColor: AppColors.accentCyan) {
                    VStack(spacing: 0) {
                        if setGroups.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textTertiary)
                                Text("No sets defined")
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.cardBackground)
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
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.accentCyan)
                                    .frame(width: 24)

                                Text("Add Set Group")
                                    .foregroundColor(AppColors.accentCyan)
                                    .fontWeight(.medium)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.cardPadding)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.cardBackground)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Notes
                FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
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
                .foregroundColor(AppColors.accentBlue)
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
        .onAppear {
            loadExercise()
        }
    }

    private func setGroupRow(setGroup: SetGroup, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accentCyan.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentCyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(setGroup.formattedTarget)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                if let rest = setGroup.formattedRest {
                    Text("Rest: \(rest)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                setGroups.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
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

    let onSelect: (ExerciseTemplate) -> Void

    @State private var searchText = ""
    @State private var selectedType: ExerciseType?

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
            .background(AppColors.surfaceLight)

            // Exercise list
            List {
                ForEach(filteredExercises) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .foregroundColor(AppColors.textPrimary)

                                Text(template.exerciseType.displayName)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundColor(AppColors.accentBlue)
                        }
                    }
                }
            }
            .listStyle(.plain)
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accentBlue : AppColors.cardBackground)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
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
