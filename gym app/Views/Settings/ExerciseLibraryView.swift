//
//  ExerciseLibraryView.swift
//  gym app
//
//  Browse and manage all exercises (provided + custom)
//

import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var resolver = ExerciseResolver.shared
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared
    @State private var searchText = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var selectedSource: ExerciseSource = .all
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: ExerciseTemplate? = nil
    @State private var providedExerciseToView: ExerciseTemplate? = nil

    enum ExerciseSource {
        case all, provided, custom
    }

    private var filteredExercises: [ExerciseTemplate] {
        var exercises: [ExerciseTemplate]

        // Filter by source
        switch selectedSource {
        case .all:
            exercises = resolver.allExercises
        case .provided:
            exercises = resolver.builtInExercises
        case .custom:
            exercises = resolver.customExercises
        }

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
        Set(resolver.customExercises.map { $0.id })
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

                // Stats - clickable source filters
                HStack(spacing: AppSpacing.sm) {
                    SourceFilterPill(
                        value: "\(resolver.builtInExercises.count)",
                        label: "Provided",
                        isSelected: selectedSource == .provided,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = selectedSource == .provided ? .all : .provided
                            }
                        }
                    )
                    SourceFilterPill(
                        value: "\(resolver.customExercises.count)",
                        label: "Custom",
                        isSelected: selectedSource == .custom,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = selectedSource == .custom ? .all : .custom
                            }
                        }
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
                                } else {
                                    providedExerciseToView = exercise
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
        .sheet(item: $providedExerciseToView) { exercise in
            ProvidedExerciseDetailSheet(exercise: exercise)
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

// MARK: - Source Filter Pill

private struct SourceFilterPill: View {
    let value: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.accentBlue : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? AppColors.accentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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

                        if !exercise.primaryMuscles.isEmpty {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
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
        exercise.primaryMuscles.map { $0.rawValue }.joined(separator: ", ")
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
                            exerciseType: exerciseType
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

    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _exerciseType = State(initialValue: exercise.exerciseType)
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
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        updated.exerciseType = exerciseType
                        customLibrary.updateExercise(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Provided Exercise Detail Sheet (View-Only)

private struct ProvidedExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: ExerciseTemplate

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: AppSpacing.md) {
                        // Type indicator
                        Circle()
                            .fill(exerciseTypeColor)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.title2.bold())

                            Text(exercise.exerciseType.displayName)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: exerciseTypeIcon)
                            .font(.title2)
                            .foregroundColor(exerciseTypeColor)
                    }
                    .listRowBackground(Color.clear)
                }

                // Primary Muscles
                if !exercise.primaryMuscles.isEmpty {
                    Section {
                        ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.accentBlue)
                                    .frame(width: 24)

                                Text(muscle.rawValue)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Primary Muscles")
                            Spacer()
                            Text("\(exercise.primaryMuscles.count)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                // Secondary Muscles
                if !exercise.secondaryMuscles.isEmpty {
                    Section {
                        ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(width: 24)

                                Text(muscle.rawValue)
                                    .font(.body)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Secondary Muscles")
                            Spacer()
                            Text("\(exercise.secondaryMuscles.count)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                // No muscles specified
                if exercise.primaryMuscles.isEmpty && exercise.secondaryMuscles.isEmpty {
                    Section("Muscles") {
                        Text("No muscles specified")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
    }

    private var exerciseTypeColor: Color {
        switch exercise.exerciseType {
        case .strength: return AppColors.accentBlue
        case .cardio: return AppColors.warning
        case .mobility: return AppColors.accentTeal
        case .isometric: return AppColors.accentCyan
        case .explosive: return Color(hex: "FF8C42")
        case .recovery: return AppColors.accentMint
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

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
}
