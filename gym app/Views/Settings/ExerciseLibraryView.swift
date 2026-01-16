//
//  ExerciseLibraryView.swift
//  gym app
//
//  Browse and manage all exercises (provided + custom)
//

import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared
    @State private var searchText = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: ExerciseTemplate? = nil

    private var allExercises: [ExerciseTemplate] {
        let provided = ExerciseLibrary.shared.exercises
        let custom = customLibrary.exercises
        return provided + custom
    }

    private var filteredExercises: [ExerciseTemplate] {
        var exercises = allExercises

        // Filter by type
        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
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

                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        TypeChip(
                            title: "All",
                            isSelected: selectedType == nil,
                            action: { selectedType = nil }
                        )

                        ForEach(ExerciseType.allCases) { type in
                            TypeChip(
                                title: type.displayName,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
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

// MARK: - Type Chip

private struct TypeChip: View {
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

    @StateObject private var libraryService = LibraryService.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Type color indicator
                Circle()
                    .fill(typeColor)
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
                        Text(exercise.exerciseType.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        if !exercise.muscleGroupIds.isEmpty {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text(muscleNames)
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

    private var muscleNames: String {
        let names = exercise.muscleGroupIds.compactMap { id in
            libraryService.getMuscleGroup(id: id)?.name
        }
        return names.joined(separator: ", ")
    }

    private var typeColor: Color {
        switch exercise.exerciseType {
        case .strength: return .blue
        case .cardio: return .red
        case .isometric: return .orange
        case .explosive: return .purple
        case .mobility: return .green
        case .recovery: return .cyan
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
    @State private var exerciseType: ExerciseType = .strength
    @State private var selectedMuscleGroups: Set<UUID> = []
    @State private var selectedImplements: Set<UUID> = []

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Muscles Worked") {
                    MuscleGroupGridCompact(selectedIds: $selectedMuscleGroups)
                        .padding(.vertical, 4)
                }

                Section("Equipment") {
                    ImplementGridCompact(selectedIds: $selectedImplements)
                        .padding(.vertical, 4)
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
                            exerciseType: exerciseType,
                            muscleGroupIds: selectedMuscleGroups,
                            implementIds: selectedImplements
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
    @State private var exerciseType: ExerciseType
    @State private var selectedMuscleGroups: Set<UUID>
    @State private var selectedImplements: Set<UUID>

    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _exerciseType = State(initialValue: exercise.exerciseType)
        _selectedMuscleGroups = State(initialValue: exercise.muscleGroupIds)
        _selectedImplements = State(initialValue: exercise.implementIds)
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

                Section("Type") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Muscles Worked") {
                    MuscleGroupGridCompact(selectedIds: $selectedMuscleGroups)
                        .padding(.vertical, 4)
                }

                Section("Equipment") {
                    ImplementGridCompact(selectedIds: $selectedImplements)
                        .padding(.vertical, 4)
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
                        let updated = ExerciseTemplate(
                            id: exercise.id,
                            name: name.trimmingCharacters(in: .whitespaces),
                            category: .fullBody,
                            exerciseType: exerciseType,
                            muscleGroupIds: selectedMuscleGroups,
                            implementIds: selectedImplements
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
