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
    @Binding var selectedTemplate: ExerciseTemplate?
    @Binding var customName: String
    let onSelect: (ExerciseTemplate?) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var saveToLibrary = true

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

            if !customName.isEmpty && !isNameInLibrary {
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
                exerciseType: .strength
            )
        }
        selectedTemplate = nil
        onSelect(nil)
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
