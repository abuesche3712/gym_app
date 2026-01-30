//
//  ExercisePickerView.swift
//  gym app
//
//  Unified picker for selecting exercises - supports single and multi-select modes
//

import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resolver = ExerciseResolver.shared
    @StateObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared

    // MARK: - Configuration

    /// When true, allows selecting multiple exercises with an "Add" button
    let allowsMultipleSelection: Bool

    /// Shows the "New Exercise" section for creating custom exercises
    let showCreateNewSection: Bool

    // MARK: - Single-select mode (used when allowsMultipleSelection = false)

    /// Binding to track currently selected template (single-select only)
    @Binding var selectedTemplate: ExerciseTemplate?

    /// Binding for custom exercise name input (single-select only)
    @Binding var customName: String

    /// Callback when an exercise is selected (single-select only)
    let onSelect: ((ExerciseTemplate?) -> Void)?

    // MARK: - Multi-select mode (used when allowsMultipleSelection = true)

    /// Callback when exercises are confirmed (multi-select only)
    let onSelectMultiple: (([ExerciseTemplate]) -> Void)?

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedType: ExerciseType?
    @State private var selectedExerciseType: ExerciseType = .strength
    @State private var saveToLibrary = true

    // Multi-select state
    @State private var selectedTemplates: [ExerciseTemplate] = []

    // Muscle group selection for custom exercises
    @State private var selectedPrimaryMuscles: [MuscleGroup] = []
    @State private var selectedSecondaryMuscles: [MuscleGroup] = []

    // Edit exercise state
    @State private var editingTemplate: ExerciseTemplate?
    @State private var editingIsCustom: Bool = false

    // MARK: - Convenience Initializers

    /// Single-select mode initializer
    init(
        selectedTemplate: Binding<ExerciseTemplate?>,
        customName: Binding<String>,
        onSelect: @escaping (ExerciseTemplate?) -> Void
    ) {
        self.allowsMultipleSelection = false
        self.showCreateNewSection = true
        self._selectedTemplate = selectedTemplate
        self._customName = customName
        self.onSelect = onSelect
        self.onSelectMultiple = nil
    }

    /// Multi-select mode initializer
    init(
        allowsMultipleSelection: Bool = true,
        showCreateNewSection: Bool = false,
        onSelectMultiple: @escaping ([ExerciseTemplate]) -> Void
    ) {
        self.allowsMultipleSelection = allowsMultipleSelection
        self.showCreateNewSection = showCreateNewSection
        self._selectedTemplate = .constant(nil)
        self._customName = .constant("")
        self.onSelect = nil
        self.onSelectMultiple = onSelectMultiple
    }

    // MARK: - Computed Properties

    private var filteredLibraryExercises: [ExerciseTemplate] {
        var exercises = resolver.builtInExercises

        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    private var filteredCustomExercises: [ExerciseTemplate] {
        var exercises = resolver.customExercises

        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    private var isNameInLibrary: Bool {
        let name = customName.trimmingCharacters(in: .whitespaces)
        return resolver.findTemplate(named: name) != nil
    }

    private func isSelected(_ template: ExerciseTemplate) -> Bool {
        if allowsMultipleSelection {
            return selectedTemplates.contains { $0.id == template.id }
        } else {
            return selectedTemplate?.id == template.id
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeFilterBar
                exerciseList

                // Multi-select: Add button at bottom
                if allowsMultipleSelection && !selectedTemplates.isEmpty {
                    addSelectedButton
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(allowsMultipleSelection ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingTemplate) { template in
                LibraryExerciseEditView(
                    template: template,
                    isCustomExercise: editingIsCustom
                )
            }
        }
    }

    // MARK: - Type Filter

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryPill(title: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }

                ForEach(ExerciseType.allCases) { type in
                    CategoryPill(title: type.displayName, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            if showCreateNewSection {
                customExerciseSection
            }

            if !filteredCustomExercises.isEmpty {
                myExercisesSection
            }

            libraryExercisesSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Custom Exercise Section (Single-select only)

    @ViewBuilder
    private var customExerciseSection: some View {
        Section {
            // Exercise name input
            HStack {
                TextField("Type custom exercise name...", text: $customName)

                if !customName.isEmpty {
                    Button {
                        addCustomExercise()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .displaySmall(color: AppColors.dominant)
                    }
                } else {
                    Image(systemName: "plus.circle.fill")
                        .displaySmall(color: .gray.opacity(0.5))
                }
            }

            // Show advanced options when name is entered
            if !customName.isEmpty && !isNameInLibrary {
                // Exercise type selection
                Picker("Exercise Type", selection: $selectedExerciseType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Toggle("Save to My Exercises", isOn: $saveToLibrary)
                    .subheadline(color: AppColors.textPrimary)
            }
        } header: {
            Text("New Exercise")
        } footer: {
            if !customName.isEmpty {
                if isNameInLibrary {
                    Text("Exercise already exists in library")
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap + to add \"\(customName)\"")
                        .foregroundColor(AppColors.dominant)
                }
            }
        }
    }

    // MARK: - My Exercises Section

    private var myExercisesSection: some View {
        Section {
            ForEach(filteredCustomExercises) { template in
                exerciseRow(template: template, isCustom: true)
            }
        } header: {
            HStack {
                Text("My Exercises (\(filteredCustomExercises.count))")
                Spacer()
                Image(systemName: "person.fill")
                    .caption(color: AppColors.textSecondary)
            }
        }
    }

    // MARK: - Library Section

    private var libraryExercisesSection: some View {
        Section {
            ForEach(filteredLibraryExercises) { template in
                exerciseRow(template: template, isCustom: false)
            }
        } header: {
            HStack {
                Text("Exercise Library (\(filteredLibraryExercises.count))")
                Spacer()
                Image(systemName: "building.columns.fill")
                    .caption(color: AppColors.textSecondary)
            }
        }
    }

    // MARK: - Exercise Row

    private func equipmentNames(for template: ExerciseTemplate) -> [String] {
        template.implementIds.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }

    private func exerciseRow(template: ExerciseTemplate, isCustom: Bool) -> some View {
        Button {
            handleExerciseSelection(template)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(template.name)
                            .body(color: AppColors.textPrimary)

                        // Show indicator if exercise has muscles or equipment set
                        if !template.primaryMuscles.isEmpty || !template.implementIds.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .caption2(color: AppColors.success)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(template.exerciseType.displayName)
                            .caption(color: AppColors.textSecondary)

                        // Show muscle count if set
                        if !template.primaryMuscles.isEmpty {
                            Text("\(template.primaryMuscles.count) muscles")
                                .caption2(color: AppColors.dominant)
                        }

                        // Show equipment if set
                        let equipment = equipmentNames(for: template)
                        if !equipment.isEmpty {
                            Text(equipment.joined(separator: ", "))
                                .caption2(color: AppColors.accent1)
                        }
                    }
                }

                Spacer()

                // Selection indicator
                if allowsMultipleSelection {
                    Image(systemName: isSelected(template) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected(template) ? AppColors.success : AppColors.textTertiary)
                } else if isSelected(template) {
                    Image(systemName: "checkmark")
                        .body(color: AppColors.dominant)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                editingIsCustom = isCustom
                editingTemplate = template
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppColors.warning)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isCustom {
                Button(role: .destructive) {
                    customLibrary.deleteExercise(template)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Add Selected Button (Multi-select)

    private var addSelectedButton: some View {
        Button {
            onSelectMultiple?(selectedTemplates)
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

    // MARK: - Actions

    private func handleExerciseSelection(_ template: ExerciseTemplate) {
        if allowsMultipleSelection {
            // Toggle selection for multi-select
            if let index = selectedTemplates.firstIndex(where: { $0.id == template.id }) {
                selectedTemplates.remove(at: index)
            } else {
                selectedTemplates.append(template)
            }
        } else {
            // Immediate selection for single-select
            selectExercise(template)
        }
    }

    private func addCustomExercise() {
        let trimmedName = customName.trimmingCharacters(in: .whitespaces)

        if saveToLibrary && !isNameInLibrary {
            customLibrary.addExercise(
                name: trimmedName,
                exerciseType: selectedExerciseType,
                primary: selectedPrimaryMuscles,
                secondary: selectedSecondaryMuscles
            )
        }

        // Create template to return - either from library or as temporary
        let template = customLibrary.template(named: trimmedName)
            ?? ExerciseTemplate(
                id: UUID(),
                name: trimmedName,
                category: .fullBody,
                exerciseType: selectedExerciseType,
                primary: selectedPrimaryMuscles,
                secondary: selectedSecondaryMuscles
            )

        selectedTemplate = template
        onSelect?(template)
        dismiss()
    }

    private func selectExercise(_ template: ExerciseTemplate) {
        customName = template.name
        onSelect?(template)
        dismiss()
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .subheadline(color: isSelected ? .white : AppColors.textPrimary)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.dominant : AppColors.surfaceTertiary)
                .clipShape(Capsule())
        }
    }
}

struct SelectableChip: View {
    let text: String
    let isSelected: Bool
    var color: Color = AppColors.dominant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .caption(color: isSelected ? .white : AppColors.textPrimary)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? color : AppColors.surfaceTertiary)
                )
        }
        .buttonStyle(.plain)
    }
}
