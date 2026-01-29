//
//  LibraryExerciseEditView.swift
//  gym app
//
//  Edit view for library exercises (name, category, type)
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

                // Muscles (display only)
                Section("Muscles") {
                    if !template.primaryMuscles.isEmpty || !template.secondaryMuscles.isEmpty {
                        if !template.primaryMuscles.isEmpty {
                            HStack {
                                Text("Primary")
                                    .subheadline(color: AppColors.textSecondary)
                                Spacer()
                                Text(template.primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                    .subheadline(color: AppColors.textPrimary)
                            }
                        }
                        if !template.secondaryMuscles.isEmpty {
                            HStack {
                                Text("Secondary")
                                    .subheadline(color: AppColors.textSecondary)
                                Spacer()
                                Text(template.secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                    .subheadline(color: AppColors.textSecondary)
                            }
                        }
                    } else {
                        Text("No muscles specified")
                            .subheadline(color: AppColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if isCustomExercise {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveExercise()
                        }
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
    }

    private func saveExercise() {
        guard isCustomExercise else { return }

        var updatedTemplate = template
        updatedTemplate.name = name.trimmingCharacters(in: .whitespaces)
        updatedTemplate.category = category
        updatedTemplate.exerciseType = exerciseType
        customLibrary.updateExercise(updatedTemplate)
        onSave?(updatedTemplate)
        dismiss()
    }
}

#Preview {
    LibraryExerciseEditView(
        template: ExerciseTemplate(name: "Bench Press", category: .chest),
        isCustomExercise: false
    )
}
