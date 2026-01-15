//
//  LibraryExerciseEditView.swift
//  gym app
//
//  Edit view for library exercises (muscle groups and equipment)
//

import SwiftUI

struct LibraryExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customLibrary = CustomExerciseLibrary.shared

    let template: ExerciseTemplate
    let isCustomExercise: Bool
    let onSave: ((ExerciseTemplate) -> Void)?

    @State private var name: String = ""
    @State private var category: ExerciseCategory = .fullBody
    @State private var exerciseType: ExerciseType = .strength
    @State private var muscleGroupIds: Set<UUID> = []
    @State private var implementIds: Set<UUID> = []

    init(template: ExerciseTemplate, isCustomExercise: Bool, onSave: ((ExerciseTemplate) -> Void)? = nil) {
        self.template = template
        self.isCustomExercise = isCustomExercise
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Exercise Info (read-only for built-in, editable for custom)
                Section("Exercise Info") {
                    if isCustomExercise {
                        TextField("Name", text: $name)

                        Picker("Category", selection: $category) {
                            ForEach(ExerciseCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }

                        Picker("Type", selection: $exerciseType) {
                            ForEach(ExerciseType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                    } else {
                        LabeledContent("Name", value: template.name)
                        LabeledContent("Category", value: template.category.rawValue)
                        LabeledContent("Type", value: template.exerciseType.displayName)
                    }
                }

                // Muscles & Equipment (always editable)
                Section("Muscles & Equipment") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("Muscles Worked")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if !muscleGroupIds.isEmpty {
                                Text("\(muscleGroupIds.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        MuscleGroupGridCompact(selectedIds: $muscleGroupIds)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("Equipment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if !implementIds.isEmpty {
                                Text("\(implementIds.count) selected")
                                    .font(.caption)
                                    .foregroundColor(.teal)
                            }
                        }
                        ImplementGridCompact(selectedIds: $implementIds)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Exercise")
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
                }
            }
            .onAppear {
                loadTemplate()
            }
        }
    }

    private func loadTemplate() {
        name = template.name
        category = template.category
        exerciseType = template.exerciseType
        muscleGroupIds = template.muscleGroupIds
        implementIds = template.implementIds
    }

    private func saveExercise() {
        if isCustomExercise {
            // Update existing custom exercise
            var updatedTemplate = template
            updatedTemplate.muscleGroupIds = muscleGroupIds
            updatedTemplate.implementIds = implementIds
            customLibrary.updateExercise(updatedTemplate)
            onSave?(updatedTemplate)
        } else {
            // For built-in exercises, create a custom copy with the modifications
            let customTemplate = ExerciseTemplate(
                id: template.id, // Keep same ID for tracking
                name: template.name,
                category: template.category,
                exerciseType: template.exerciseType,
                primary: template.primaryMuscles,
                secondary: template.secondaryMuscles,
                muscleGroupIds: muscleGroupIds,
                implementIds: implementIds
            )
            // Check if already exists in custom library
            if customLibrary.exercises.contains(where: { $0.id == template.id }) {
                customLibrary.updateExercise(customTemplate)
            } else {
                customLibrary.addExercise(customTemplate)
            }
            onSave?(customTemplate)
        }
        dismiss()
    }
}

#Preview {
    LibraryExerciseEditView(
        template: ExerciseTemplate(name: "Bench Press", category: .chest),
        isCustomExercise: false
    )
}
