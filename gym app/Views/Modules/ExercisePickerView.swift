//
//  ExercisePickerView.swift
//  gym app
//
//  Picker for selecting an exercise from the library or creating a custom one
//

import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared
    @Binding var selectedTemplate: ExerciseTemplate?
    @Binding var customName: String
    let onSelect: (ExerciseTemplate?) -> Void
    var onSelectWithDetails: ((ExerciseTemplate?, Set<UUID>, Set<UUID>) -> Void)?

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedExerciseType: ExerciseType = .strength
    @State private var saveToLibrary = true

    // New library system fields
    @State private var selectedMuscleGroups: Set<UUID> = []
    @State private var selectedImplements: Set<UUID> = []
    @State private var showingAdvancedOptions = false

    // Edit exercise state
    @State private var editingTemplate: ExerciseTemplate?
    @State private var editingIsCustom: Bool = false

    private var filteredLibraryExercises: [ExerciseTemplate] {
        var exercises = ExerciseLibrary.shared.exercises

        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises
    }

    private var filteredCustomExercises: [ExerciseTemplate] {
        var exercises = customLibrary.exercises

        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises
    }

    private var isNameInLibrary: Bool {
        let name = customName.trimmingCharacters(in: .whitespaces).lowercased()
        return ExerciseLibrary.shared.exercises.contains { $0.name.lowercased() == name } ||
               customLibrary.exercises.contains { $0.name.lowercased() == name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilterBar
                exerciseList
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
            .sheet(item: $editingTemplate) { template in
                LibraryExerciseEditView(
                    template: template,
                    isCustomExercise: editingIsCustom
                )
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilterBar: some View {
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
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            customExerciseSection

            if !filteredCustomExercises.isEmpty {
                myExercisesSection
            }

            libraryExercisesSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Custom Exercise Section

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
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.title2)
                }
            }

            // Show advanced options when name is entered
            if !customName.isEmpty && !isNameInLibrary {
                // Toggle for advanced options
                Button {
                    withAnimation {
                        showingAdvancedOptions.toggle()
                    }
                } label: {
                    HStack {
                        Text("Muscle Groups & Equipment")
                            .foregroundColor(.primary)
                        Spacer()
                        if !selectedMuscleGroups.isEmpty || !selectedImplements.isEmpty {
                            Text("\(selectedMuscleGroups.count + selectedImplements.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if showingAdvancedOptions {
                    // Exercise Type Selection
                    Picker("Exercise Type", selection: $selectedExerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    // Muscle Group Selection
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Muscles Worked")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)

                        MuscleGroupGridCompact(selectedIds: $selectedMuscleGroups)
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // Implement Selection
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Equipment")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)

                        ImplementGridCompact(selectedIds: $selectedImplements)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }

                Toggle("Save to My Exercises", isOn: $saveToLibrary)
                    .font(.subheadline)
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
                        .foregroundColor(.blue)
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
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(template: ExerciseTemplate, isCustom: Bool) -> some View {
        Button {
            selectExercise(template)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(template.name)
                            .foregroundColor(.primary)

                        // Show indicators if exercise has muscles/equipment set
                        if !template.muscleGroupIds.isEmpty || !template.implementIds.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(template.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Show muscle/equipment count if set
                        if !template.muscleGroupIds.isEmpty {
                            Text("\(template.muscleGroupIds.count) muscles")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        if !template.implementIds.isEmpty {
                            Text("\(template.implementIds.count) equip")
                                .font(.caption2)
                                .foregroundColor(.teal)
                        }
                    }
                }

                Spacer()

                if selectedTemplate?.id == template.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
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
            .tint(.orange)
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

    // MARK: - Actions

    private func addCustomExercise() {
        if saveToLibrary && !isNameInLibrary {
            customLibrary.addExercise(
                name: customName.trimmingCharacters(in: .whitespaces),
                category: selectedCategory ?? .fullBody,
                exerciseType: selectedExerciseType,
                muscleGroupIds: selectedMuscleGroups,
                implementIds: selectedImplements
            )
        }
        selectedTemplate = nil

        // Use the detailed callback if provided, otherwise use the simple one
        if let detailedCallback = onSelectWithDetails {
            detailedCallback(nil, selectedMuscleGroups, selectedImplements)
        } else {
            onSelect(nil)
        }
        dismiss()
    }

    private func selectExercise(_ template: ExerciseTemplate) {
        customName = template.name
        onSelect(template)
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
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Compact Selection Grids

struct MuscleGroupGridCompact: View {
    @StateObject private var libraryService = LibraryService.shared
    @Binding var selectedIds: Set<UUID>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(libraryService.muscleGroups, id: \.id) { muscleGroup in
                SelectableChip(
                    text: muscleGroup.name,
                    isSelected: selectedIds.contains(muscleGroup.id),
                    color: .blue
                ) {
                    toggleSelection(muscleGroup.id)
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

struct ImplementGridCompact: View {
    @StateObject private var libraryService = LibraryService.shared
    @Binding var selectedIds: Set<UUID>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(libraryService.implements, id: \.id) { implement in
                SelectableChip(
                    text: implement.name,
                    isSelected: selectedIds.contains(implement.id),
                    color: .teal
                ) {
                    toggleSelection(implement.id)
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

struct SelectableChip: View {
    let text: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? color : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
