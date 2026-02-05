//
//  LibraryExerciseEditView.swift
//  gym app
//
//  Edit view for library exercises (name, category, type, muscles, equipment)
//

import SwiftUI

struct LibraryExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared

    let template: ExerciseTemplate
    let isCustomExercise: Bool
    let onSave: ((ExerciseTemplate) -> Void)?

    // Basic info
    @State private var name: String = ""
    @State private var category: ExerciseCategory = .fullBody
    @State private var exerciseType: ExerciseType = .strength

    // Muscles
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []
    @State private var showingMusclePicker = false

    // Equipment
    @State private var selectedImplementIds: Set<UUID> = []
    @State private var showingEquipmentPicker = false

    // Attributes
    @State private var isUnilateral: Bool = false
    @State private var isBodyweight: Bool = false

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

                // Muscles section
                Section("Muscles") {
                    if isCustomExercise {
                        Button {
                            showingMusclePicker = true
                        } label: {
                            HStack {
                                Text("Muscles")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                muscleValueText
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Read-only display for built-in exercises
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

                // Equipment section
                Section("Equipment") {
                    if isCustomExercise {
                        Button {
                            showingEquipmentPicker = true
                        } label: {
                            HStack {
                                Text("Equipment")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                equipmentValueText
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Read-only display for built-in exercises
                        if template.implementIds.isEmpty {
                            Text("No equipment specified")
                                .subheadline(color: AppColors.textSecondary)
                        } else {
                            Text(equipmentNames(for: template.implementIds).joined(separator: ", "))
                                .subheadline(color: AppColors.textPrimary)
                        }
                    }
                }

                // Attributes section (only for custom exercises and non-cardio types)
                if isCustomExercise && exerciseType != .cardio {
                    Section("Attributes") {
                        Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                            .tint(AppColors.accent3)

                        Toggle("Bodyweight Exercise", isOn: $isBodyweight)
                            .tint(AppColors.accent3)
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
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                loadTemplate()
            }
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

    // MARK: - Helper Views

    private var muscleValueText: some View {
        Group {
            if primaryMuscles.isEmpty && secondaryMuscles.isEmpty {
                Text("None")
                    .foregroundColor(AppColors.textTertiary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    if !primaryMuscles.isEmpty {
                        Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .subheadline(color: AppColors.dominant)
                            .lineLimit(1)
                    }
                    if !secondaryMuscles.isEmpty {
                        Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .caption(color: AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var equipmentValueText: some View {
        Group {
            if selectedImplementIds.isEmpty {
                Text("None")
                    .foregroundColor(AppColors.textTertiary)
            } else {
                Text(equipmentNames(for: selectedImplementIds).joined(separator: ", "))
                    .subheadline(color: AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func equipmentNames(for ids: Set<UUID>) -> [String] {
        ids.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }

    // MARK: - Data Operations

    private func loadTemplate() {
        name = template.name
        category = template.category
        exerciseType = template.exerciseType
        primaryMuscles = template.primaryMuscles
        secondaryMuscles = template.secondaryMuscles
        selectedImplementIds = template.implementIds
        isUnilateral = template.isUnilateral
        isBodyweight = template.isBodyweight
    }

    private func saveExercise() {
        guard isCustomExercise else { return }

        var updatedTemplate = template
        updatedTemplate.name = name.trimmingCharacters(in: .whitespaces)
        updatedTemplate.category = category
        updatedTemplate.exerciseType = exerciseType
        updatedTemplate.primaryMuscles = primaryMuscles
        updatedTemplate.secondaryMuscles = secondaryMuscles
        updatedTemplate.implementIds = selectedImplementIds
        updatedTemplate.isUnilateral = isUnilateral
        updatedTemplate.isBodyweight = isBodyweight
        updatedTemplate.updatedAt = Date()

        customLibrary.updateExercise(updatedTemplate)
        onSave?(updatedTemplate)
        dismiss()
    }
}

#Preview {
    LibraryExerciseEditView(
        template: ExerciseTemplate(name: "Bench Press", category: .chest),
        isCustomExercise: true
    )
}
