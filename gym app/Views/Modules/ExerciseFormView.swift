//
//  ExerciseFormView.swift
//  gym app
//
//  Form for creating/editing an exercise
//

import SwiftUI

// Helper for sheet(item:) with Int index
struct EditingIndex: Identifiable {
    let id: Int
    var index: Int { id }
}

struct ExerciseFormView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var libraryService = LibraryService.shared
    @ObservedObject private var customLibrary = CustomExerciseLibrary.shared

    let instance: ExerciseInstance?
    let moduleId: UUID

    @State private var name: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength
    @State private var trackTime: Bool = true
    @State private var trackDistance: Bool = false
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var trackReps: Bool = true
    @State private var trackDuration: Bool = false
    @State private var notes: String = ""
    @State private var setGroups: [SetGroup] = []
    @State private var isUnilateral: Bool = false

    // Muscle groups from template
    @State private var primaryMuscles: [MuscleGroup] = []
    @State private var secondaryMuscles: [MuscleGroup] = []

    // Equipment
    @State private var selectedImplementIds: Set<UUID> = []
    @State private var showingEquipmentPicker = false
    @State private var showingMusclePicker = false

    @State private var showingAddSetGroup = false
    @State private var editingSetGroup: EditingIndex?
    @State private var showingExercisePicker = false

    private var isEditing: Bool { instance != nil }

    /// Check if exercise is bodyweight-based
    private var isBodyweight: Bool {
        selectedTemplate?.isBodyweight ?? false
    }

    /// Computed CardioTracking from toggle states
    private var cardioMetric: CardioTracking {
        if trackTime && trackDistance {
            return .both
        } else if trackDistance {
            return .distanceOnly
        } else {
            return .timeOnly
        }
    }

    /// Computed MobilityTracking from toggle states
    private var mobilityTracking: MobilityTracking {
        if trackReps && trackDuration {
            return .both
        } else if trackDuration {
            return .durationOnly
        } else {
            return .repsOnly
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                exerciseSection
                musclesAndEquipmentSection
                setsSection
                notesSection
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveExercise()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.dominant)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingAddSetGroup) {
            NavigationStack {
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit,
                    implementIds: selectedImplementIds,
                    isBodyweight: selectedTemplate?.isBodyweight ?? false,
                    existingSetGroup: nil
                ) { newSetGroup in
                    setGroups.append(newSetGroup)
                }
            }
        }
        .sheet(item: $editingSetGroup) { editing in
            NavigationStack {
                SetGroupFormView(
                    exerciseType: exerciseType,
                    cardioMetric: cardioMetric,
                    mobilityTracking: mobilityTracking,
                    distanceUnit: distanceUnit,
                    implementIds: selectedImplementIds,
                    isBodyweight: selectedTemplate?.isBodyweight ?? false,
                    existingSetGroup: setGroups[editing.index]
                ) { updatedSetGroup in
                    setGroups[editing.index] = updatedSetGroup
                }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                selectedTemplate: $selectedTemplate,
                customName: $name,
                onSelect: { template in
                    if let template = template {
                        name = template.name
                        exerciseType = template.exerciseType
                        selectedTemplate = template
                        // Copy muscle groups, equipment, and unilateral from template
                        primaryMuscles = template.primaryMuscles
                        secondaryMuscles = template.secondaryMuscles
                        selectedImplementIds = template.implementIds
                        isUnilateral = template.isUnilateral
                    }
                }
            )
        }
        .onAppear {
            loadExistingExercise()
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        FormSection(title: "Exercise", icon: "dumbbell", iconColor: AppColors.dominant) {
            // Exercise selection button
            FormButtonRow(
                label: "Exercise",
                icon: "magnifyingglass",
                value: name.isEmpty ? "Select or type..." : name,
                valueColor: name.isEmpty ? AppColors.textTertiary : AppColors.textPrimary
            ) {
                showingExercisePicker = true
            }

            FormDivider()

            // Type picker row
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "tag")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Type")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Picker("", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .tint(AppColors.dominant)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfacePrimary)

            // Cardio-specific options
            if exerciseType == .cardio {
                FormDivider()
                cardioOptionsSection
            }

            // Mobility-specific options
            if exerciseType == .mobility {
                FormDivider()
                mobilityOptionsSection
            }

            // Unilateral toggle (for all exercises except cardio)
            if exerciseType != .cardio {
                FormDivider()
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)

                    Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                        .tint(AppColors.accent3)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
            }
        }
    }

    @ViewBuilder
    private var cardioOptionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Track During Workout")
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
                Toggle("Time", isOn: $trackTime)
                    .tint(AppColors.dominant)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.xs)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
                Toggle("Distance", isOn: $trackDistance)
                    .tint(AppColors.dominant)
                    .onChange(of: trackDistance) { _, newValue in
                        if !newValue && !trackTime {
                            trackTime = true
                        }
                    }
                    .onChange(of: trackTime) { _, newValue in
                        if !newValue && !trackDistance {
                            trackDistance = true
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.xs)

            if trackDistance {
                FormDivider()
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "ruler")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)
                    Text("Distance Unit")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Picker("", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .tint(AppColors.dominant)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .background(AppColors.surfacePrimary)
    }

    @ViewBuilder
    private var mobilityOptionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Track During Workout")
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
                Toggle("Reps", isOn: $trackReps)
                    .tint(AppColors.accent1)
                    .onChange(of: trackReps) { _, newValue in
                        if !newValue && !trackDuration {
                            trackDuration = true
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.xs)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
                Toggle("Duration", isOn: $trackDuration)
                    .tint(AppColors.accent1)
                    .onChange(of: trackDuration) { _, newValue in
                        if !newValue && !trackReps {
                            trackReps = true
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Muscles & Equipment Section

    private func equipmentNames(for ids: Set<UUID>) -> [String] {
        ids.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }

    private var muscleValueText: some View {
        Group {
            if primaryMuscles.isEmpty && secondaryMuscles.isEmpty {
                Text("None")
                    .foregroundColor(AppColors.textTertiary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    if !primaryMuscles.isEmpty {
                        Text(primaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(AppColors.dominant)
                            .lineLimit(1)
                    }
                    if !secondaryMuscles.isEmpty {
                        Text(secondaryMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var musclesAndEquipmentSection: some View {
        FormSection(title: "Muscles & Equipment", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accent1) {
            // Muscles row
            Button {
                showingMusclePicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.arms.open")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Muscles")
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    muscleValueText

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
            }
            .buttonStyle(.plain)
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

            FormDivider()

            // Equipment row
            Button {
                showingEquipmentPicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Equipment")
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if selectedImplementIds.isEmpty {
                        Text("None")
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        Text(equipmentNames(for: selectedImplementIds).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent1)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surfacePrimary)
            }
            .buttonStyle(.plain)
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

    // MARK: - Sets Section

    private var setsSection: some View {
        FormSection(title: "Sets", icon: "list.number", iconColor: AppColors.dominant) {
            VStack(spacing: 0) {
                if setGroups.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No sets defined yet")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfacePrimary)
                } else {
                    ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, setGroup in
                        Button {
                            editingSetGroup = EditingIndex(id: index)
                        } label: {
                            SetGroupEditRow(setGroup: binding(for: index), index: index + 1)
                        }
                        .buttonStyle(.plain)

                        if index < setGroups.count - 1 {
                            FormDivider()
                        }
                    }
                }

                FormDivider()

                // Add set group button
                Button {
                    showingAddSetGroup = true
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.dominant)
                            .frame(width: 24)

                        Text("Add Set Group")
                            .foregroundColor(AppColors.dominant)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfacePrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Helpers

    private func binding(for index: Int) -> Binding<SetGroup> {
        Binding(
            get: { setGroups[index] },
            set: { setGroups[index] = $0 }
        )
    }

    private func deleteSetGroup(at offsets: IndexSet) {
        setGroups.remove(atOffsets: offsets)
    }

    private func moveSetGroup(from source: IndexSet, to destination: Int) {
        setGroups.move(fromOffsets: source, toOffset: destination)
    }

    private func loadExistingExercise() {
        if let instance = instance {
            // Load basic data from instance
            name = instance.name
            exerciseType = instance.exerciseType
            trackTime = instance.cardioMetric.tracksTime
            trackDistance = instance.cardioMetric.tracksDistance
            trackReps = instance.mobilityTracking.tracksReps
            trackDuration = instance.mobilityTracking.tracksDuration
            distanceUnit = instance.distanceUnit
            notes = instance.notes ?? ""
            setGroups = instance.setGroups

            // Try to load template if linked
            if let templateId = instance.templateId {
                // Check both built-in and custom libraries
                if let builtInTemplate = ExerciseLibrary.shared.template(id: templateId) {
                    selectedTemplate = builtInTemplate
                    // Load muscles/equipment/unilateral from built-in template (source of truth)
                    primaryMuscles = builtInTemplate.primaryMuscles
                    secondaryMuscles = builtInTemplate.secondaryMuscles
                    selectedImplementIds = builtInTemplate.implementIds
                    isUnilateral = builtInTemplate.isUnilateral
                } else if let customTemplate = customLibrary.exercises.first(where: { $0.id == templateId }) {
                    selectedTemplate = customTemplate
                    // Load muscles/equipment/unilateral from custom template (source of truth)
                    primaryMuscles = customTemplate.primaryMuscles
                    secondaryMuscles = customTemplate.secondaryMuscles
                    selectedImplementIds = customTemplate.implementIds
                    isUnilateral = customTemplate.isUnilateral
                } else {
                    // Template not found - fall back to instance data
                    primaryMuscles = instance.primaryMuscles
                    secondaryMuscles = instance.secondaryMuscles
                    selectedImplementIds = instance.implementIds
                    isUnilateral = instance.isUnilateral
                }
            } else {
                // No template - use instance data
                primaryMuscles = instance.primaryMuscles
                secondaryMuscles = instance.secondaryMuscles
                selectedImplementIds = instance.implementIds
                isUnilateral = instance.isUnilateral
            }
        }
    }

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        guard var module = moduleViewModel.getModule(id: moduleId) else { return }

        if var existingInstance = instance {
            // Update existing instance - all data stored directly
            existingInstance.name = trimmedName
            existingInstance.exerciseType = exerciseType
            existingInstance.cardioMetric = cardioMetric
            existingInstance.distanceUnit = distanceUnit
            existingInstance.mobilityTracking = mobilityTracking
            existingInstance.isUnilateral = isUnilateral
            existingInstance.primaryMuscles = primaryMuscles
            existingInstance.secondaryMuscles = secondaryMuscles
            existingInstance.implementIds = selectedImplementIds
            existingInstance.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingInstance.setGroups = setGroups
            existingInstance.updatedAt = Date()

            // If this instance is linked to a custom template, update the template in the library
            if let templateId = existingInstance.templateId,
               let customTemplate = customLibrary.exercises.first(where: { $0.id == templateId }) {
                var updatedTemplate = customTemplate
                updatedTemplate.name = trimmedName
                updatedTemplate.exerciseType = exerciseType
                updatedTemplate.primaryMuscles = primaryMuscles
                updatedTemplate.secondaryMuscles = secondaryMuscles
                updatedTemplate.isUnilateral = isUnilateral
                updatedTemplate.implementIds = selectedImplementIds
                customLibrary.updateExercise(updatedTemplate)
            }

            module.updateExercise(existingInstance)
        } else {
            // Create new instance - use selected equipment (or from template)
            let equipmentIds = selectedImplementIds.isEmpty ? (selectedTemplate?.implementIds ?? []) : selectedImplementIds
            let newInstance = ExerciseInstance(
                templateId: selectedTemplate?.id,
                name: trimmedName,
                exerciseType: exerciseType,
                cardioMetric: cardioMetric,
                distanceUnit: distanceUnit,
                mobilityTracking: mobilityTracking,
                isBodyweight: selectedTemplate?.isBodyweight ?? false,
                isUnilateral: isUnilateral,
                recoveryActivityType: selectedTemplate?.recoveryActivityType,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                implementIds: equipmentIds,
                setGroups: setGroups,
                order: module.exercises.count,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            module.addExercise(newInstance)
        }

        moduleViewModel.saveModule(module)
        dismiss()
    }
}

// MARK: - Set Group Edit Row

struct SetGroupEditRow: View {
    @Binding var setGroup: SetGroup
    let index: Int

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Group number indicator
            ZStack {
                Circle()
                    .fill(AppColors.dominant.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.dominant)
            }

            // Set info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(setGroup.formattedTarget)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    if let rest = setGroup.formattedRest {
                        Label(rest, systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if let notes = setGroup.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }
}

// MARK: - Muscle Group Enum Picker

struct MuscleGroupEnumPickerView: View {
    @Binding var primaryMuscles: [MuscleGroup]
    @Binding var secondaryMuscles: [MuscleGroup]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Primary muscles section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Primary Muscles")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Main muscles worked by this exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                        ForEach(MuscleGroup.allCases) { muscle in
                            MuscleEnumChip(
                                muscle: muscle,
                                isSelected: primaryMuscles.contains(muscle),
                                isPrimary: true
                            ) {
                                togglePrimary(muscle)
                            }
                        }
                    }
                }

                Divider()

                // Secondary muscles section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Secondary Muscles")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Supporting muscles engaged during the movement")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                        ForEach(MuscleGroup.allCases) { muscle in
                            MuscleEnumChip(
                                muscle: muscle,
                                isSelected: secondaryMuscles.contains(muscle),
                                isPrimary: false
                            ) {
                                toggleSecondary(muscle)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func togglePrimary(_ muscle: MuscleGroup) {
        if primaryMuscles.contains(muscle) {
            primaryMuscles.removeAll { $0 == muscle }
        } else {
            primaryMuscles.append(muscle)
            // Remove from secondary if adding to primary
            secondaryMuscles.removeAll { $0 == muscle }
        }
    }

    private func toggleSecondary(_ muscle: MuscleGroup) {
        if secondaryMuscles.contains(muscle) {
            secondaryMuscles.removeAll { $0 == muscle }
        } else {
            secondaryMuscles.append(muscle)
            // Remove from primary if adding to secondary
            primaryMuscles.removeAll { $0 == muscle }
        }
    }
}

struct MuscleEnumChip: View {
    let muscle: MuscleGroup
    let isSelected: Bool
    let isPrimary: Bool
    let action: () -> Void

    private var selectedColor: Color {
        isPrimary ? AppColors.dominant : AppColors.accent1
    }

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
                    .fill(isSelected ? selectedColor : AppColors.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? selectedColor : AppColors.surfaceTertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ExerciseFormView(instance: nil, moduleId: UUID())
            .environmentObject(ModuleViewModel())
    }
}
