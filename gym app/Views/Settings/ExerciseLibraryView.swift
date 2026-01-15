//
//  ExerciseLibraryView.swift
//  gym app
//
//  Browse and manage all exercises (provided + custom)
//

import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory? = nil
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: ExerciseTemplate? = nil

    private var allExercises: [ExerciseTemplate] {
        let provided = ExerciseLibrary.shared.exercises
        let custom = customLibrary.exercises
        return provided + custom
    }

    private var filteredExercises: [ExerciseTemplate] {
        var exercises = allExercises

        // Filter by category
        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort alphabetically
        return exercises.sorted { $0.name < $1.name }
    }

    private var customExerciseIds: Set<UUID> {
        Set(customLibrary.exercises.map { $0.id })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textTertiary)
                    TextField("Search exercises", text: $searchText)
                        .font(.body)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.cardBackground)
                )

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        CategoryChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(ExerciseCategory.allCases) { category in
                            CategoryChip(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                }

                // Stats
                HStack(spacing: AppSpacing.lg) {
                    StatPill(
                        value: "\(ExerciseLibrary.shared.exercises.count)",
                        label: "Provided"
                    )
                    StatPill(
                        value: "\(customLibrary.exercises.count)",
                        label: "Custom"
                    )
                    StatPill(
                        value: "\(filteredExercises.count)",
                        label: "Showing"
                    )
                }

                // Exercise list
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(filteredExercises) { exercise in
                        ExerciseLibraryRow(
                            exercise: exercise,
                            isCustom: customExerciseIds.contains(exercise.id),
                            onTap: {
                                if customExerciseIds.contains(exercise.id) {
                                    exerciseToEdit = exercise
                                }
                            },
                            onDelete: customExerciseIds.contains(exercise.id) ? {
                                customLibrary.deleteExercise(exercise)
                            } : nil
                        )
                    }
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Exercise Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet()
        }
        .sheet(item: $exerciseToEdit) { exercise in
            EditCustomExerciseSheet(exercise: exercise)
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accentBlue : AppColors.cardBackground)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.cardBackground)
        )
    }
}

// MARK: - Exercise Row

private struct ExerciseLibraryRow: View {
    let exercise: ExerciseTemplate
    let isCustom: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Category color indicator
                Circle()
                    .fill(categoryColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(exercise.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        if isCustom {
                            Text("Custom")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppColors.accentTeal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.accentTeal.opacity(0.15))
                                )
                        }
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Text(exercise.category.rawValue)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        if !exercise.primaryMuscles.isEmpty {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text(exercise.primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Exercise type icon
                Image(systemName: exerciseTypeIcon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)

                if isCustom {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var categoryColor: Color {
        switch exercise.category {
        case .chest: return .red
        case .back: return .blue
        case .shoulders: return .orange
        case .biceps: return .purple
        case .triceps: return .pink
        case .legs: return .green
        case .core: return .yellow
        case .cardio: return .cyan
        case .fullBody: return .indigo
        }
    }

    private var exerciseTypeIcon: String {
        switch exercise.exerciseType {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .isometric: return "timer"
        case .explosive: return "bolt.fill"
        case .mobility: return "figure.flexibility"
        case .recovery: return "leaf.fill"
        }
    }
}

// MARK: - Add Exercise Sheet

private struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared

    @State private var name = ""
    @State private var category: ExerciseCategory = .chest
    @State private var exerciseType: ExerciseType = .strength
    @State private var primaryMuscles: Set<MuscleGroup> = []
    @State private var secondaryMuscles: Set<MuscleGroup> = []

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Type") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Primary Muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.rawValue, isOn: Binding(
                            get: { primaryMuscles.contains(muscle) },
                            set: { isOn in
                                if isOn {
                                    primaryMuscles.insert(muscle)
                                } else {
                                    primaryMuscles.remove(muscle)
                                }
                            }
                        ))
                    }
                }

                Section("Secondary Muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.rawValue, isOn: Binding(
                            get: { secondaryMuscles.contains(muscle) },
                            set: { isOn in
                                if isOn {
                                    secondaryMuscles.insert(muscle)
                                } else {
                                    secondaryMuscles.remove(muscle)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        customLibrary.addExercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            category: category,
                            exerciseType: exerciseType,
                            primaryMuscles: Array(primaryMuscles),
                            secondaryMuscles: Array(secondaryMuscles)
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Edit Exercise Sheet

private struct EditCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared

    let exercise: ExerciseTemplate

    @State private var name: String
    @State private var category: ExerciseCategory
    @State private var exerciseType: ExerciseType
    @State private var primaryMuscles: Set<MuscleGroup>
    @State private var secondaryMuscles: Set<MuscleGroup>

    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _category = State(initialValue: exercise.category)
        _exerciseType = State(initialValue: exercise.exerciseType)
        _primaryMuscles = State(initialValue: Set(exercise.primaryMuscles))
        _secondaryMuscles = State(initialValue: Set(exercise.secondaryMuscles))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Type") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Primary Muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.rawValue, isOn: Binding(
                            get: { primaryMuscles.contains(muscle) },
                            set: { isOn in
                                if isOn {
                                    primaryMuscles.insert(muscle)
                                } else {
                                    primaryMuscles.remove(muscle)
                                }
                            }
                        ))
                    }
                }

                Section("Secondary Muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.rawValue, isOn: Binding(
                            get: { secondaryMuscles.contains(muscle) },
                            set: { isOn in
                                if isOn {
                                    secondaryMuscles.insert(muscle)
                                } else {
                                    secondaryMuscles.remove(muscle)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = exercise
                        updated = ExerciseTemplate(
                            id: exercise.id,
                            name: name.trimmingCharacters(in: .whitespaces),
                            category: category,
                            exerciseType: exerciseType,
                            primary: Array(primaryMuscles),
                            secondary: Array(secondaryMuscles),
                            muscleGroupIds: exercise.muscleGroupIds,
                            implementIds: exercise.implementIds
                        )
                        customLibrary.updateExercise(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
}
