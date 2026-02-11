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

    // Session mode parameters (optional - when editing an exercise during an active session)
    let sessionExercise: SessionExercise?
    let sessionModuleIndex: Int?
    let sessionExerciseIndex: Int?
    let onSessionSave: ((Int, Int, SessionExercise) -> Void)?

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

    // Session mode: preserve completed set data per set group
    @State private var completedSetsMap: [UUID: [SetData]] = [:]  // setGroupId -> completed sets
    @State private var allSetsMap: [UUID: [SetData]] = [:]  // setGroupId -> all sets (for history editing)

    private var isSessionMode: Bool { sessionExercise != nil }
    private var isEditing: Bool { instance != nil || isSessionMode }

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
                if isSessionMode {
                    sessionInfoBanner
                }
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
                    .body(color: AppColors.textTertiary)
                    .frame(width: 24)

                Text("Type")
                    .body(color: AppColors.textPrimary)

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

            // Unilateral toggle
            FormDivider()
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "figure.walk")
                    .body(color: AppColors.textTertiary)
                    .frame(width: 24)

                Toggle("Unilateral (Left/Right)", isOn: $isUnilateral)
                    .tint(AppColors.accent3)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
        }
    }

    @ViewBuilder
    private var cardioOptionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Track During Workout")
                .caption(color: AppColors.textSecondary)
                .fontWeight(.medium)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "clock")
                    .body(color: AppColors.textTertiary)
                    .frame(width: 24)
                Toggle("Time", isOn: $trackTime)
                    .tint(AppColors.dominant)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.xs)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "arrow.left.and.right")
                    .body(color: AppColors.textTertiary)
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
                        .body(color: AppColors.textTertiary)
                        .frame(width: 24)
                    Text("Distance Unit")
                        .body(color: AppColors.textPrimary)
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
                .caption(color: AppColors.textSecondary)
                .fontWeight(.medium)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "number")
                    .body(color: AppColors.textTertiary)
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
                    .body(color: AppColors.textTertiary)
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
                    .body(color: AppColors.textTertiary)
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

    private var musclesAndEquipmentSection: some View {
        FormSection(title: "Muscles & Equipment", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accent1) {
            // Muscles row
            Button {
                showingMusclePicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "figure.arms.open")
                        .body(color: AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Muscles")
                        .body(color: AppColors.textPrimary)

                    Spacer()

                    muscleValueText

                    Image(systemName: "chevron.right")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
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
                        .body(color: AppColors.textTertiary)
                        .frame(width: 24)

                    Text("Equipment")
                        .body(color: AppColors.textPrimary)

                    Spacer()

                    if selectedImplementIds.isEmpty {
                        Text("None")
                            .body(color: AppColors.textTertiary)
                    } else {
                        Text(equipmentNames(for: selectedImplementIds).joined(separator: ", "))
                            .subheadline(color: AppColors.accent1)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
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
                            .body(color: AppColors.textTertiary)
                        Text("No sets defined yet")
                            .body(color: AppColors.textSecondary)
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
                            .body(color: AppColors.dominant)
                            .frame(width: 24)

                        Text("Add Set Group")
                            .body(color: AppColors.dominant)
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

    // MARK: - Session Info Banner

    private var sessionInfoBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundColor(AppColors.dominant)
            Text("Completed sets are preserved. Changes apply to remaining sets.")
                .caption(color: AppColors.textSecondary)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
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
        if let exercise = sessionExercise {
            // Session mode: load from SessionExercise
            name = exercise.exerciseName
            exerciseType = exercise.exerciseType
            trackTime = exercise.cardioMetric.tracksTime
            trackDistance = exercise.cardioMetric.tracksDistance
            trackReps = exercise.mobilityTracking.tracksReps
            trackDuration = exercise.mobilityTracking.tracksDuration
            distanceUnit = exercise.distanceUnit
            notes = exercise.notes ?? ""
            primaryMuscles = exercise.primaryMuscles
            secondaryMuscles = exercise.secondaryMuscles
            selectedImplementIds = exercise.implementIds

            // Convert CompletedSetGroups to SetGroups, preserving completed set data
            setGroups = exercise.completedSetGroups.map { group in
                let completedSets = group.sets.filter { $0.completed }
                let firstSet = group.sets.first

                // For unilateral exercises, the logical set count is half the SetData count
                let logicalSetCount = group.isUnilateral ? group.sets.count / 2 : group.sets.count

                // Store completed sets and all sets for later reconstruction
                completedSetsMap[group.setGroupId] = completedSets
                allSetsMap[group.setGroupId] = group.sets

                return SetGroup(
                    id: group.setGroupId,
                    sets: logicalSetCount,
                    targetReps: firstSet?.reps,
                    targetWeight: firstSet?.weight,
                    targetDuration: firstSet?.duration,
                    targetDistance: firstSet?.distance,
                    targetHoldTime: firstSet?.holdTime,
                    restPeriod: group.restPeriod,
                    isInterval: group.isInterval,
                    workDuration: group.workDuration,
                    intervalRestDuration: group.intervalRestDuration,
                    isAMRAP: group.isAMRAP,
                    amrapTimeLimit: group.amrapTimeLimit,
                    isUnilateral: group.isUnilateral,
                    trackRPE: group.trackRPE,
                    implementMeasurables: group.implementMeasurables
                )
            }

            // Determine isUnilateral from first set group
            isUnilateral = exercise.completedSetGroups.first?.isUnilateral ?? false

            if setGroups.isEmpty {
                showingAddSetGroup = true
            }
        } else if let instance = instance {
            // Builder mode: load from ExerciseInstance
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

        // Session mode: convert SetGroups back to CompletedSetGroups and save via callback
        if isSessionMode, var updatedExercise = sessionExercise,
           let moduleIndex = sessionModuleIndex, let exerciseIndex = sessionExerciseIndex {
            updatedExercise.exerciseName = trimmedName
            updatedExercise.exerciseType = exerciseType
            updatedExercise.cardioMetric = cardioMetric
            updatedExercise.mobilityTracking = mobilityTracking
            updatedExercise.distanceUnit = distanceUnit
            updatedExercise.primaryMuscles = primaryMuscles
            updatedExercise.secondaryMuscles = secondaryMuscles
            updatedExercise.implementIds = selectedImplementIds
            updatedExercise.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

            // Convert SetGroups back to CompletedSetGroups, preserving completed sets
            // Use exercise-level isUnilateral (not setGroup-level) to propagate toggle changes
            var newSetGroups: [CompletedSetGroup] = []
            for setGroup in setGroups {
                var sets: [SetData] = []
                let wasUnilateral = setGroup.isUnilateral
                let nowUnilateral = isUnilateral

                // Check if we have preserved all sets from history editing
                if let allSets = allSetsMap[setGroup.id], !allSets.isEmpty {
                    if wasUnilateral == nowUnilateral {
                        // No change in unilateral state
                        sets = allSets
                    } else if nowUnilateral && !wasUnilateral {
                        // Bilateral → Unilateral: duplicate each set into L/R pairs
                        for existingSet in allSets {
                            var leftSet = existingSet
                            leftSet.side = .left
                            sets.append(leftSet)
                            var rightSet = SetData(
                                setNumber: existingSet.setNumber,
                                weight: existingSet.weight,
                                reps: existingSet.reps,
                                completed: false,
                                duration: existingSet.duration,
                                distance: existingSet.distance,
                                holdTime: existingSet.holdTime,
                                side: .right
                            )
                            // Preserve completion only for the left side
                            sets.append(rightSet)
                        }
                    } else {
                        // Unilateral → Bilateral: keep only left-side sets, clear side
                        for existingSet in allSets {
                            if existingSet.side == .left || existingSet.side == nil {
                                var bilateralSet = existingSet
                                bilateralSet.side = nil
                                sets.append(bilateralSet)
                            }
                            // Drop right-side sets
                        }
                    }
                } else {
                    // Use preserved completed sets, then add remaining incomplete sets
                    let completedSets = completedSetsMap[setGroup.id] ?? []

                    if wasUnilateral == nowUnilateral {
                        sets.append(contentsOf: completedSets)
                    } else if nowUnilateral && !wasUnilateral {
                        // Bilateral → Unilateral: duplicate completed sets into L/R
                        for existingSet in completedSets {
                            var leftSet = existingSet
                            leftSet.side = .left
                            sets.append(leftSet)
                            var rightSet = SetData(
                                setNumber: existingSet.setNumber,
                                weight: existingSet.weight,
                                reps: existingSet.reps,
                                completed: false,
                                duration: existingSet.duration,
                                distance: existingSet.distance,
                                holdTime: existingSet.holdTime,
                                side: .right
                            )
                            sets.append(rightSet)
                        }
                    } else {
                        // Unilateral → Bilateral: keep left-side completed sets
                        for existingSet in completedSets {
                            if existingSet.side == .left || existingSet.side == nil {
                                var bilateralSet = existingSet
                                bilateralSet.side = nil
                                sets.append(bilateralSet)
                            }
                        }
                    }

                    let completedLogicalSets = nowUnilateral
                        ? sets.count / 2
                        : sets.count
                    let remainingLogicalSets = setGroup.sets - completedLogicalSets

                    for i in 0..<max(0, remainingLogicalSets) {
                        let setNumber = completedLogicalSets + i + 1

                        if nowUnilateral {
                            sets.append(SetData(
                                setNumber: setNumber,
                                weight: setGroup.targetWeight,
                                reps: setGroup.targetReps,
                                completed: false,
                                duration: setGroup.targetDuration,
                                distance: setGroup.targetDistance,
                                holdTime: setGroup.targetHoldTime,
                                side: .left
                            ))
                            sets.append(SetData(
                                setNumber: setNumber,
                                weight: setGroup.targetWeight,
                                reps: setGroup.targetReps,
                                completed: false,
                                duration: setGroup.targetDuration,
                                distance: setGroup.targetDistance,
                                holdTime: setGroup.targetHoldTime,
                                side: .right
                            ))
                        } else {
                            sets.append(SetData(
                                setNumber: setNumber,
                                weight: setGroup.targetWeight,
                                reps: setGroup.targetReps,
                                completed: false,
                                duration: setGroup.targetDuration,
                                distance: setGroup.targetDistance,
                                holdTime: setGroup.targetHoldTime
                            ))
                        }
                    }
                }

                if !sets.isEmpty {
                    newSetGroups.append(CompletedSetGroup(
                        setGroupId: setGroup.id,
                        restPeriod: setGroup.restPeriod,
                        sets: sets,
                        isInterval: setGroup.isInterval,
                        workDuration: setGroup.workDuration,
                        intervalRestDuration: setGroup.intervalRestDuration,
                        isAMRAP: setGroup.isAMRAP,
                        amrapTimeLimit: setGroup.amrapTimeLimit,
                        isUnilateral: isUnilateral,
                        trackRPE: setGroup.trackRPE,
                        implementMeasurables: setGroup.implementMeasurables
                    ))
                }
            }

            updatedExercise.completedSetGroups = newSetGroups
            onSessionSave?(moduleIndex, exerciseIndex, updatedExercise)
            dismiss()
            return
        }

        // Builder mode: save to module
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
                    .subheadline(color: AppColors.dominant)
                    .fontWeight(.semibold)
            }

            // Set info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(setGroup.formattedTarget)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                HStack(spacing: AppSpacing.sm) {
                    if let rest = setGroup.formattedRest {
                        Label(rest, systemImage: "timer")
                            .caption(color: AppColors.textSecondary)
                    }

                    if let notes = setGroup.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .caption(color: AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .caption(color: AppColors.textTertiary)
                .fontWeight(.semibold)
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
                        .headline(color: AppColors.textPrimary)
                    Text("Main muscles worked by this exercise")
                        .caption(color: AppColors.textSecondary)

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
                        .headline(color: AppColors.textPrimary)
                    Text("Supporting muscles engaged during the movement")
                        .caption(color: AppColors.textSecondary)

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
        .background(AppColors.background)
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
                    .subheadline(color: isSelected ? .white : AppColors.textPrimary)

                Text(muscle.rawValue)
                    .subheadline(color: isSelected ? .white : AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .body(color: .white)
                }
            }
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
        ExerciseFormView(instance: nil, moduleId: UUID(), sessionExercise: nil, sessionModuleIndex: nil, sessionExerciseIndex: nil, onSessionSave: nil)
            .environmentObject(ModuleViewModel())
    }
}
