//
//  WorkoutFormView.swift
//  gym app
//
//  Form for creating/editing a workout - all in one view
//

import SwiftUI

struct WorkoutFormView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resolver = ExerciseResolver.shared

    let workout: Workout?

    // Workout info
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var estimatedDuration: String = ""

    // Content
    @State private var selectedModuleIds: [UUID] = []
    @State private var standaloneExercises: [ExerciseInstance] = []

    // UI state
    @State private var showingModulePicker = false
    @State private var showingExercisePicker = false
    @State private var moduleSearchText = ""
    @State private var exerciseSearchText = ""
    @State private var editingExercise: ExerciseInstance?
    @State private var selectedForSuperset: Set<UUID> = []
    @State private var isSelectingForSuperset = false
    @State private var showingCreateExercise = false

    private var isEditing: Bool { workout != nil }

    // Quick search results for modules
    private var quickModuleResults: [Module] {
        guard !moduleSearchText.isEmpty else { return [] }
        return moduleViewModel.modules
            .filter { $0.name.localizedCaseInsensitiveContains(moduleSearchText) }
            .filter { !selectedModuleIds.contains($0.id) }
            .prefix(4)
            .map { $0 }
    }

    // Quick search results for exercises
    private var quickExerciseResults: [ExerciseTemplate] {
        guard !exerciseSearchText.isEmpty else { return [] }
        let allExercises = resolver.builtInExercises + resolver.customExercises
        return allExercises
            .filter { $0.name.localizedCaseInsensitiveContains(exerciseSearchText) }
            .sorted { $0.name < $1.name }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header
                builderHeader

                // Workout Info
                workoutInfoSection

                // Modules
                modulesSection

                // Standalone Exercises
                exercisesSection

                // Notes
                notesSection
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
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
                    saveWorkout()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.accentBlue)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingModulePicker) {
            NavigationStack {
                ModulePickerSheet(
                    selectedModuleIds: $selectedModuleIds,
                    onDone: { }
                )
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                WorkoutExercisePickerSheet(onSelect: { templates in
                    for template in templates {
                        addExerciseFromTemplate(template)
                    }
                })
            }
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                InlineExerciseEditor(
                    exercise: exercise,
                    onSave: { updated in
                        if let index = standaloneExercises.firstIndex(where: { $0.id == updated.id }) {
                            standaloneExercises[index] = updated
                        }
                        editingExercise = nil
                    },
                    onCancel: {
                        editingExercise = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingCreateExercise) {
            AddExerciseSheet(onExerciseCreated: { newTemplate in
                addExerciseFromTemplate(newTemplate)
            })
        }
        .onAppear {
            loadWorkout()
        }
    }

    // MARK: - Header

    private var builderHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "EDITING" : "BUILDING")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isEditing ? AppColors.warning : AppColors.accentBlue)
                        .tracking(1.5)

                    Text(name.isEmpty ? "New Workout" : name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                completionRing
            }

            // Stats
            HStack(spacing: AppSpacing.lg) {
                statBadge(value: "\(selectedModuleIds.count)", label: "modules", icon: "square.stack.3d.up", color: AppColors.accentTeal)
                statBadge(value: "\(totalExerciseCount)", label: "exercises", icon: "dumbbell", color: AppColors.accentBlue)

                if let duration = Int(estimatedDuration), duration > 0 {
                    statBadge(value: "\(duration)", label: "min", icon: "clock", color: AppColors.accentPurple)
                }

                Spacer()
            }
            .padding(.top, AppSpacing.xs)

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [(isEditing ? AppColors.warning : AppColors.accentBlue).opacity(0.6), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.top, AppSpacing.sm)
        }
    }

    private var completionRing: some View {
        let progress = completionProgress
        return ZStack {
            Circle()
                .stroke(AppColors.surfaceLight, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1.0 ? AppColors.success : AppColors.accentBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: progress >= 1.0 ? "checkmark" : "hammer.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(progress >= 1.0 ? AppColors.success : AppColors.accentBlue)
        }
        .frame(width: 44, height: 44)
    }

    private var completionProgress: Double {
        var filled = 0.0
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { filled += 1 }
        if !selectedModuleIds.isEmpty || !standaloneExercises.isEmpty { filled += 1 }
        if Int(estimatedDuration) ?? 0 > 0 { filled += 1 }
        return filled / 3.0
    }

    private var totalExerciseCount: Int {
        let moduleExercises = selectedModuleIds.compactMap { moduleViewModel.getModule(id: $0) }
            .reduce(0) { $0 + $1.exercises.count }
        return moduleExercises + standaloneExercises.count
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    // MARK: - Workout Info Section

    private var workoutInfoSection: some View {
        FormSection(title: "Workout Info", icon: "figure.strengthtraining.traditional", iconColor: AppColors.accentBlue) {
            FormTextField(label: "Name", text: $name, icon: "textformat", placeholder: "e.g., Monday - Lower A")
            FormDivider()
            FormTextField(label: "Duration", text: $estimatedDuration, icon: "clock", placeholder: "minutes", keyboardType: .numberPad)
        }
    }

    // MARK: - Modules Section

    private var modulesSection: some View {
        FormSection(title: "Modules", icon: "square.stack.3d.up", iconColor: AppColors.accentTeal) {
            VStack(spacing: 0) {
                // Quick search
                moduleQuickAddBar

                // Search results
                if !moduleSearchText.isEmpty && !quickModuleResults.isEmpty {
                    moduleSearchResultsDropdown
                }

                FormDivider()

                // Module list
                if selectedModuleIds.isEmpty {
                    emptyModulesView
                } else {
                    modulesList
                }

                FormDivider()

                // Browse modules button
                browseModulesButton
            }
        }
    }

    private var moduleQuickAddBar: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            TextField("Quick add module...", text: $moduleSearchText)
                .textFieldStyle(.plain)
                .submitLabel(.done)

            if !moduleSearchText.isEmpty {
                Button {
                    moduleSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private var moduleSearchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(quickModuleResults) { module in
                Button {
                    selectedModuleIds.append(module.id)
                    moduleSearchText = ""
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: module.type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.moduleColor(module.type))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Text("\(module.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.accentTeal)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surfaceLight)
                }
                .buttonStyle(.plain)

                if module.id != quickModuleResults.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    private var emptyModulesView: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary.opacity(0.5))
            Text("No modules added")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)
            Text("Search above or browse your library")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.cardBackground)
    }

    private var modulesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedModuleIds.enumerated()), id: \.element) { index, moduleId in
                if let module = moduleViewModel.getModule(id: moduleId) {
                    moduleRow(module: module, index: index)

                    if index < selectedModuleIds.count - 1 {
                        FormDivider()
                    }
                }
            }
        }
    }

    private func moduleRow(module: Module, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.moduleColor(module.type).opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.moduleColor(module.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                HStack(spacing: AppSpacing.sm) {
                    Text(module.type.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("•")
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(module.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    _ = selectedModuleIds.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private var browseModulesButton: some View {
        Button {
            showingModulePicker = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accentTeal)
                    .frame(width: 24)
                Text("Browse Module Library")
                    .foregroundColor(AppColors.accentTeal)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        FormSection(title: "Standalone Exercises", icon: "dumbbell", iconColor: AppColors.accentBlue) {
            VStack(spacing: 0) {
                // Quick search
                exerciseQuickAddBar

                // Search results
                if !exerciseSearchText.isEmpty && !quickExerciseResults.isEmpty {
                    exerciseSearchResultsDropdown
                }

                FormDivider()

                // Superset toolbar (when we have 2+ exercises)
                if standaloneExercises.count >= 2 {
                    supersetToolbar
                }

                // Exercise list
                if standaloneExercises.isEmpty {
                    emptyExercisesView
                } else {
                    exercisesList
                }

                FormDivider()

                // Browse exercises button
                browseExercisesButton

                // Footer
                Text("Add exercises directly without creating a module")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
            }
        }
    }

    private var exerciseQuickAddBar: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            TextField("Quick add exercise...", text: $exerciseSearchText)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit {
                    if !exerciseSearchText.isEmpty {
                        addCustomExercise(name: exerciseSearchText)
                        exerciseSearchText = ""
                    }
                }

            if !exerciseSearchText.isEmpty {
                Button {
                    addCustomExercise(name: exerciseSearchText)
                    exerciseSearchText = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private var exerciseSearchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(quickExerciseResults) { template in
                Button {
                    addExerciseFromTemplate(template)
                    exerciseSearchText = ""
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: template.exerciseType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.accentBlue)
                            .frame(width: 24)

                        Text(template.name)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(template.exerciseType.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)

                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.accentBlue)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surfaceLight)
                }
                .buttonStyle(.plain)

                if template.id != quickExerciseResults.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    private var emptyExercisesView: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "dumbbell")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary.opacity(0.5))
            Text("No standalone exercises")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)
            Text("Add exercises that aren't part of a module")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.cardBackground)
    }

    private var exercisesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(standaloneExercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(exercise: exercise, index: index)
                    .onDrag {
                        draggedExercise = exercise
                        return NSItemProvider(object: exercise.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                        item: exercise,
                        items: $standaloneExercises,
                        draggedItem: $draggedExercise
                    ))

                if index < standaloneExercises.count - 1 {
                    FormDivider()
                }
            }
        }
    }

    @State private var draggedExercise: ExerciseInstance?

    private var supersetToolbar: some View {
        HStack(spacing: AppSpacing.md) {
            if isSelectingForSuperset {
                Button {
                    withAnimation {
                        isSelectingForSuperset = false
                        selectedForSuperset.removeAll()
                    }
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if selectedForSuperset.count >= 2 {
                    Button {
                        createSupersetFromSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("Link \(selectedForSuperset.count) as Superset")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.accentBlue)
                    }
                } else {
                    Text("Select 2+ exercises")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else {
                Spacer()
                Button {
                    withAnimation {
                        isSelectingForSuperset = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                        Text("Create Superset")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
    }

    private func createSupersetFromSelection() {
        let supersetId = UUID()
        for i in standaloneExercises.indices {
            if selectedForSuperset.contains(standaloneExercises[i].id) {
                standaloneExercises[i].supersetGroupId = supersetId
            }
        }
        withAnimation {
            isSelectingForSuperset = false
            selectedForSuperset.removeAll()
        }
    }

    private func getSupersetIndex(for supersetId: UUID) -> Int {
        let uniqueSupersetIds = Array(Set(standaloneExercises.compactMap { $0.supersetGroupId }))
            .sorted { id1, id2 in
                let index1 = standaloneExercises.firstIndex { $0.supersetGroupId == id1 } ?? 0
                let index2 = standaloneExercises.firstIndex { $0.supersetGroupId == id2 } ?? 0
                return index1 < index2
            }
        return (uniqueSupersetIds.firstIndex(of: supersetId) ?? 0) + 1
    }

    private func exerciseRow(exercise: ExerciseInstance, index: Int) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Selection checkbox when in superset selection mode
            if isSelectingForSuperset {
                Button {
                    if selectedForSuperset.contains(exercise.id) {
                        selectedForSuperset.remove(exercise.id)
                    } else {
                        selectedForSuperset.insert(exercise.id)
                    }
                } label: {
                    Image(systemName: selectedForSuperset.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(selectedForSuperset.contains(exercise.id) ? AppColors.accentBlue : AppColors.textTertiary)
                }
            } else {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 20)
            }

            // Superset indicator
            if let supersetId = exercise.supersetGroupId {
                let supersetIndex = getSupersetIndex(for: supersetId)
                ZStack {
                    Circle()
                        .fill(AppColors.accentTeal.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text("S\(supersetIndex)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.accentTeal)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.accentBlue.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.accentBlue)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                HStack(spacing: AppSpacing.sm) {
                    Text(exercise.exerciseType.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    if !exercise.setGroups.isEmpty {
                        Text("•")
                            .foregroundColor(AppColors.textTertiary)
                        Text(formatSetScheme(exercise.setGroups))
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            Button {
                editingExercise = exercise
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 32, height: 32)
            }

            Button {
                withAnimation {
                    _ = standaloneExercises.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    private var browseExercisesButton: some View {
        VStack(spacing: 0) {
            Button {
                showingExercisePicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 24)
                    Text("Browse Exercise Library")
                        .foregroundColor(AppColors.accentBlue)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.cardBackground)
            }
            .buttonStyle(.plain)

            FormDivider()

            Button {
                showingCreateExercise = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accentTeal)
                        .frame(width: 24)
                    Text("Create New Exercise")
                        .foregroundColor(AppColors.accentTeal)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.cardBackground)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        FormSection(title: "Notes", icon: "note.text", iconColor: AppColors.textTertiary) {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Actions

    private func loadWorkout() {
        if let workout = workout {
            name = workout.name
            notes = workout.notes ?? ""
            if let duration = workout.estimatedDuration {
                estimatedDuration = "\(duration)"
            }
            selectedModuleIds = workout.moduleReferences
                .sorted { $0.order < $1.order }
                .map { $0.moduleId }
            standaloneExercises = workout.standaloneExercises
                .sorted { $0.order < $1.order }
                .map(\.exercise)
        }
    }

    private func addExerciseFromTemplate(_ template: ExerciseTemplate) {
        let instance = ExerciseInstance(
            templateId: template.id,
            name: template.name,
            exerciseType: template.exerciseType,
            primaryMuscles: template.primaryMuscles,
            secondaryMuscles: template.secondaryMuscles,
            implementIds: template.implementIds,
            order: standaloneExercises.count
        )
        withAnimation {
            standaloneExercises.append(instance)
        }
    }

    private func addCustomExercise(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let template = resolver.findTemplate(named: trimmedName) {
            addExerciseFromTemplate(template)
        } else {
            let instance = ExerciseInstance(
                templateId: nil,
                name: trimmedName,
                exerciseType: .strength,
                order: standaloneExercises.count
            )
            withAnimation {
                standaloneExercises.append(instance)
            }
        }
    }

    private func formatSetScheme(_ setGroups: [SetGroup]) -> String {
        setGroups.map { group in
            if let reps = group.targetReps {
                return "\(group.sets)×\(reps)"
            } else if let duration = group.targetDuration {
                return "\(group.sets)×\(duration)s"
            }
            return "\(group.sets) sets"
        }.joined(separator: " + ")
    }

    private func saveWorkout() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let duration = Int(estimatedDuration)

        let moduleRefs = selectedModuleIds.enumerated().map { index, moduleId in
            ModuleReference(moduleId: moduleId, order: index)
        }

        let workoutExercises = standaloneExercises.enumerated().map { index, instance in
            WorkoutExercise(exercise: instance, order: index)
        }

        if var existingWorkout = workout {
            existingWorkout.name = trimmedName
            existingWorkout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingWorkout.estimatedDuration = duration
            existingWorkout.moduleReferences = moduleRefs
            existingWorkout.standaloneExercises = workoutExercises
            existingWorkout.updatedAt = Date()
            workoutViewModel.saveWorkout(existingWorkout)
        } else {
            let newWorkout = Workout(
                name: trimmedName,
                moduleReferences: moduleRefs,
                standaloneExercises: workoutExercises,
                estimatedDuration: duration,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            workoutViewModel.saveWorkout(newWorkout)
        }

        dismiss()
    }
}

// MARK: - Module Picker Sheet (Multi-select)

struct ModulePickerSheet: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModuleIds: [UUID]
    let onDone: () -> Void

    @State private var searchText = ""
    @State private var selectedType: ModuleType?
    @State private var pendingSelections: Set<UUID> = []

    private var filteredModules: [Module] {
        var modules = moduleViewModel.modules

        if let type = selectedType {
            modules = modules.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            modules = modules.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return modules.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ModuleFilterChip(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(ModuleType.allCases) { type in
                        ModuleFilterChip(title: type.displayName, isSelected: selectedType == type, color: type.color) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.surfaceLight)

            // Module list
            List {
                if filteredModules.isEmpty {
                    ContentUnavailableView(
                        "No Modules",
                        systemImage: "square.stack.3d.up",
                        description: Text("Create modules first to add them here")
                    )
                } else {
                    ForEach(filteredModules) { module in
                        Button {
                            toggleSelection(module.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: module.type.icon)
                                    .foregroundStyle(module.type.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.name)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("\(module.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if isSelected(module.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                        .font(.system(size: 22))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(AppColors.textTertiary)
                                        .font(.system(size: 22))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)

            // Add button
            if !pendingSelections.isEmpty {
                Button {
                    for id in pendingSelections {
                        if !selectedModuleIds.contains(id) {
                            selectedModuleIds.append(id)
                        }
                    }
                    onDone()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(pendingSelections.count) Module\(pendingSelections.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accentTeal)
                    .foregroundColor(.white)
                    .cornerRadius(AppCorners.medium)
                }
                .padding(AppSpacing.screenPadding)
                .background(AppColors.background)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Module Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search modules...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func isSelected(_ id: UUID) -> Bool {
        pendingSelections.contains(id) || selectedModuleIds.contains(id)
    }

    private func toggleSelection(_ id: UUID) {
        // Don't allow toggling already-added modules
        guard !selectedModuleIds.contains(id) else { return }

        if pendingSelections.contains(id) {
            pendingSelections.remove(id)
        } else {
            pendingSelections.insert(id)
        }
    }
}

// MARK: - Exercise Picker for Workouts (Multi-select)

struct WorkoutExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var resolver = ExerciseResolver.shared

    let onSelect: ([ExerciseTemplate]) -> Void

    @State private var searchText = ""
    @State private var selectedType: ExerciseType?
    @State private var selectedTemplates: [ExerciseTemplate] = []

    private var filteredExercises: [ExerciseTemplate] {
        var exercises = resolver.builtInExercises + resolver.customExercises

        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    private func isSelected(_ template: ExerciseTemplate) -> Bool {
        selectedTemplates.contains { $0.id == template.id }
    }

    private func toggleSelection(_ template: ExerciseTemplate) {
        if let index = selectedTemplates.firstIndex(where: { $0.id == template.id }) {
            selectedTemplates.remove(at: index)
        } else {
            selectedTemplates.append(template)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ModuleFilterChip(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(ExerciseType.allCases) { type in
                        ModuleFilterChip(title: type.displayName, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.surfaceLight)

            // Exercise list
            List {
                ForEach(filteredExercises) { template in
                    Button {
                        toggleSelection(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(template.exerciseType.displayName)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if isSelected(template) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.success)
                                    .font(.system(size: 22))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(AppColors.textTertiary)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            // Add button
            if !selectedTemplates.isEmpty {
                Button {
                    onSelect(selectedTemplates)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(selectedTemplates.count) Exercise\(selectedTemplates.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(AppCorners.medium)
                }
                .padding(AppSpacing.screenPadding)
                .background(AppColors.background)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search exercises...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Module Filter Chip

private struct ModuleFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = AppColors.accentBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : AppColors.cardBackground)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Exercise Drop Delegate

struct ExerciseDropDelegate: DropDelegate {
    let item: ExerciseInstance
    @Binding var items: [ExerciseInstance]
    @Binding var draggedItem: ExerciseInstance?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    NavigationStack {
        WorkoutFormView(workout: nil)
            .environmentObject(WorkoutViewModel())
            .environmentObject(ModuleViewModel())
    }
}
