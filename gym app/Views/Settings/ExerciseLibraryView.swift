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
                            isCustom: exercise.isCustom,
                            onTap: {
                                exerciseToEdit = exercise
                            },
                            onDelete: exercise.isCustom ? {
                                customLibrary.deleteExercise(exercise)
                                resolver.refreshCache()
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
            ExerciseEditSheet(exercise: exercise)
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

                        if !equipmentNames.isEmpty {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text(equipmentNames)
                                .font(.caption)
                                .foregroundColor(AppColors.accentCyan)
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

    private var equipmentNames: String {
        let library = LibraryService.shared
        return exercise.implementIds.compactMap { id in
            library.getImplement(id: id)?.name
        }.joined(separator: ", ")
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

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared

    var onExerciseCreated: ((ExerciseTemplate) -> Void)? = nil

    @State private var name = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var primaryMuscles: Set<MuscleGroup> = []
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var selectedImplementIds: Set<UUID> = []

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Name Section
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        TextField("Exercise name", text: $name)
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .fill(AppColors.cardBackground)
                            )
                    }

                    // Type Section
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Exercise Type")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                            ForEach(ExerciseType.allCases) { type in
                                Button {
                                    exerciseType = type
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 20))

                                        Text(type.displayName)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.sm)
                                    .foregroundColor(exerciseType == type ? .white : AppColors.textPrimary)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCorners.medium)
                                            .fill(exerciseType == type ? AppColors.accentBlue : AppColors.cardBackground)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Primary Muscles
                    muscleSection(
                        title: "Primary Muscles",
                        subtitle: "Main muscles worked",
                        selected: $primaryMuscles,
                        excluded: secondaryMuscles,
                        accentColor: AppColors.accentBlue
                    )

                    // Secondary Muscles
                    muscleSection(
                        title: "Secondary Muscles",
                        subtitle: "Supporting muscles",
                        selected: $secondaryMuscles,
                        excluded: primaryMuscles,
                        accentColor: AppColors.accentTeal
                    )

                    // Equipment
                    equipmentSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        customLibrary.addExercise(
                            name: trimmedName,
                            exerciseType: exerciseType,
                            primary: Array(primaryMuscles),
                            secondary: Array(secondaryMuscles),
                            implementIds: selectedImplementIds
                        )
                        ExerciseResolver.shared.refreshCache()
                        // Find the newly created template to pass to callback
                        if let createdTemplate = customLibrary.exercises.first(where: { $0.name == trimmedName }) {
                            onExerciseCreated?(createdTemplate)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func muscleSection(
        title: String,
        subtitle: String,
        selected: Binding<Set<MuscleGroup>>,
        excluded: Set<MuscleGroup>,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if !selected.wrappedValue.isEmpty {
                        Text("\(selected.wrappedValue.count) selected")
                            .font(.caption)
                            .foregroundColor(accentColor)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    if !excluded.contains(muscle) {
                        MuscleChip(
                            muscle: muscle,
                            isSelected: selected.wrappedValue.contains(muscle),
                            accentColor: accentColor
                        ) {
                            if selected.wrappedValue.contains(muscle) {
                                selected.wrappedValue.remove(muscle)
                            } else {
                                selected.wrappedValue.insert(muscle)
                            }
                        }
                    }
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Equipment")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if !selectedImplementIds.isEmpty {
                        Text("\(selectedImplementIds.count) selected")
                            .font(.caption)
                            .foregroundColor(AppColors.accentCyan)
                    }
                }

                Text("What equipment does this exercise use?")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(libraryService.implements, id: \.id) { implement in
                    EquipmentChip(
                        name: implement.name,
                        isSelected: selectedImplementIds.contains(implement.id)
                    ) {
                        if selectedImplementIds.contains(implement.id) {
                            selectedImplementIds.remove(implement.id)
                        } else {
                            selectedImplementIds.insert(implement.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Exercise Edit Sheet (Unified for all exercises)

private struct ExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared
    @StateObject private var libraryService = LibraryService.shared

    let exercise: ExerciseTemplate

    @State private var name: String
    @State private var exerciseType: ExerciseType
    @State private var isUnilateral: Bool
    @State private var primaryMuscles: Set<MuscleGroup>
    @State private var secondaryMuscles: Set<MuscleGroup>
    @State private var selectedImplementIds: Set<UUID>

    // Grid layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(exercise: ExerciseTemplate) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _exerciseType = State(initialValue: exercise.exerciseType)
        _isUnilateral = State(initialValue: exercise.isUnilateral)
        _primaryMuscles = State(initialValue: Set(exercise.primaryMuscles))
        _secondaryMuscles = State(initialValue: Set(exercise.secondaryMuscles))
        _selectedImplementIds = State(initialValue: exercise.implementIds)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != exercise.name ||
        exerciseType != exercise.exerciseType ||
        isUnilateral != exercise.isUnilateral ||
        Set(exercise.primaryMuscles) != primaryMuscles ||
        Set(exercise.secondaryMuscles) != secondaryMuscles ||
        exercise.implementIds != selectedImplementIds
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header Card
                    headerCard

                    // Type Selection
                    typeSection

                    // Unilateral Toggle (for all exercises except cardio)
                    if exerciseType != .cardio {
                        unilateralSection
                    }

                    // Primary Muscles Grid
                    muscleSection(
                        title: "Primary Muscles",
                        subtitle: "Main muscles worked",
                        selected: $primaryMuscles,
                        excluded: secondaryMuscles,
                        accentColor: AppColors.accentBlue
                    )

                    // Secondary Muscles Grid
                    muscleSection(
                        title: "Secondary Muscles",
                        subtitle: "Supporting muscles",
                        selected: $secondaryMuscles,
                        excluded: primaryMuscles,
                        accentColor: AppColors.accentTeal
                    )

                    // Equipment Grid
                    equipmentSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(exercise.isCustom ? "Edit Exercise" : "Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!canSave || !hasChanges)
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                // Type indicator
                ZStack {
                    Circle()
                        .fill(exerciseTypeColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: exerciseTypeIcon)
                        .font(.title2)
                        .foregroundColor(exerciseTypeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if exercise.isCustom {
                        TextField("Exercise name", text: $name)
                            .font(.title3.bold())
                            .foregroundColor(AppColors.textPrimary)
                    } else {
                        Text(exercise.name)
                            .font(.title3.bold())
                            .foregroundColor(AppColors.textPrimary)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Text(exerciseType.displayName)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        if exercise.isCustom {
                            Text("Custom")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppColors.accentTeal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.accentTeal.opacity(0.15)))
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Exercise Type")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                ForEach(ExerciseType.allCases) { type in
                    Button {
                        exerciseType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))

                            Text(type.displayName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .foregroundColor(exerciseType == type ? .white : AppColors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(exerciseType == type ? exerciseTypeColor(for: type) : AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .stroke(exerciseType == type ? exerciseTypeColor(for: type) : AppColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Unilateral Section

    private var unilateralSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accentPurple)

                Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                    .tint(AppColors.accentPurple)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )

            if isUnilateral {
                Text("Single-leg/arm work - sets are logged separately for left and right sides")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPurple)
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Muscle Section

    private func muscleSection(
        title: String,
        subtitle: String,
        selected: Binding<Set<MuscleGroup>>,
        excluded: Set<MuscleGroup>,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if !selected.wrappedValue.isEmpty {
                        Text("\(selected.wrappedValue.count) selected")
                            .font(.caption)
                            .foregroundColor(accentColor)
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    if !excluded.contains(muscle) {
                        MuscleChip(
                            muscle: muscle,
                            isSelected: selected.wrappedValue.contains(muscle),
                            accentColor: accentColor
                        ) {
                            if selected.wrappedValue.contains(muscle) {
                                selected.wrappedValue.remove(muscle)
                            } else {
                                selected.wrappedValue.insert(muscle)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Equipment Section

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Equipment")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if !selectedImplementIds.isEmpty {
                        Text("\(selectedImplementIds.count) selected")
                            .font(.caption)
                            .foregroundColor(AppColors.accentCyan)
                    }
                }

                Text("What equipment does this exercise use?")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(libraryService.implements, id: \.id) { implement in
                    EquipmentChip(
                        name: implement.name,
                        isSelected: selectedImplementIds.contains(implement.id)
                    ) {
                        if selectedImplementIds.contains(implement.id) {
                            selectedImplementIds.remove(implement.id)
                        } else {
                            selectedImplementIds.insert(implement.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        var updated = exercise
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.exerciseType = exerciseType
        updated.isUnilateral = isUnilateral
        updated.primaryMuscles = Array(primaryMuscles)
        updated.secondaryMuscles = Array(secondaryMuscles)
        updated.implementIds = selectedImplementIds

        if exercise.isCustom {
            customLibrary.updateExercise(updated)
        } else {
            customLibrary.addExercise(updated)
        }
        ExerciseResolver.shared.refreshCache()
        dismiss()
    }

    // MARK: - Helpers

    private var exerciseTypeColor: Color {
        exerciseTypeColor(for: exerciseType)
    }

    private func exerciseTypeColor(for type: ExerciseType) -> Color {
        switch type {
        case .strength: return AppColors.accentBlue
        case .cardio: return AppColors.warning
        case .mobility: return AppColors.accentTeal
        case .isometric: return AppColors.accentCyan
        case .explosive: return Color(hex: "FF8C42")
        case .recovery: return AppColors.accentMint
        }
    }

    private var exerciseTypeIcon: String {
        exerciseType.icon
    }
}

// MARK: - Muscle Chip

private struct MuscleChip: View {
    let muscle: MuscleGroup
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: muscle.icon)
                    .font(.system(size: 14))

                Text(muscle.rawValue)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? accentColor : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? accentColor : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Equipment Chip

private struct EquipmentChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch name.lowercased() {
        case "barbell": return "figure.strengthtraining.traditional"
        case "dumbbell", "dumbbells": return "dumbbell.fill"
        case "cable", "cables": return "cable.connector"
        case "machine": return "gearshape.fill"
        case "kettlebell": return "figure.strengthtraining.functional"
        case "box": return "square.stack.3d.up.fill"
        case "band", "bands", "resistance band": return "circle.hexagonpath.fill"
        case "bodyweight": return "figure.stand"
        case "pull-up bar", "pullup bar": return "figure.climbing"
        case "bench": return "bed.double.fill"
        case "ez bar", "ez-bar": return "line.diagonal"
        case "trap bar": return "hexagon"
        case "smith machine": return "square.stack.3d.down.right"
        case "rings": return "circle.circle"
        case "medicine ball", "med ball": return "basketball.fill"
        case "foam roller": return "capsule.fill"
        default: return "wrench.and.screwdriver.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.accentCyan : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? AppColors.accentCyan : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
}
