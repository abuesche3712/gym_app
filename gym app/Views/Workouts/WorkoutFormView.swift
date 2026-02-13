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

    // Content
    @State private var selectedModuleIds: [UUID] = []
    @State private var standaloneExercises: [ExerciseInstance] = []

    // UI state
    @State private var showingModulePicker = false
    @State private var showingExercisePicker = false
    @State private var exerciseSearchText = ""
    @State private var editingExercise: ExerciseInstance?
    @State private var selectedForSuperset: Set<UUID> = []
    @State private var isSelectingForSuperset = false
    @State private var showingCreateExercise = false
    @State private var showingShareSheet = false
    @State private var showingPostToFeed = false
    @FocusState private var focusedField: Bool

    private var isEditing: Bool { workout != nil }

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
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    focusedField = false
                    dismiss()
                }
                .foregroundColor(AppColors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = false
                    saveWorkout()
                }
                .fontWeight(.semibold)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.dominant)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ToolbarItem(placement: .primaryAction) {
                if isEditing, let existingWorkout = workout {
                    Menu {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share with Friend", systemImage: "paperplane")
                        }
                        Button {
                            showingPostToFeed = true
                        } label: {
                            Label("Post to Feed", systemImage: "rectangle.stack")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppColors.dominant)
                    }
                    .buttonStyle(.plain)
                }
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
            ExercisePickerView(onSelectMultiple: { templates in
                for template in templates {
                    addExerciseFromTemplate(template)
                }
            })
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
        .sheet(isPresented: $showingShareSheet) {
            if let existingWorkout = workout,
               let currentWorkout = workoutViewModel.getWorkout(id: existingWorkout.id) {
                ShareWithFriendSheet(content: currentWorkout) { conversationWithProfile in
                    let chatViewModel = ChatViewModel(
                        conversation: conversationWithProfile.conversation,
                        otherParticipant: conversationWithProfile.otherParticipant,
                        otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                    )
                    let content = try currentWorkout.createMessageContent()
                    try await chatViewModel.sendSharedContent(content)
                }
            }
        }
        .sheet(isPresented: $showingPostToFeed) {
            if let existingWorkout = workout,
               let currentWorkout = workoutViewModel.getWorkout(id: existingWorkout.id) {
                ComposePostSheet(content: currentWorkout)
            }
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
                        .elegantLabel(color: AppColors.dominant)

                    Text(name.isEmpty ? "New Workout" : name)
                        .displaySmall(color: AppColors.textPrimary)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Stats
            HStack(spacing: AppSpacing.lg) {
                statBadge(value: "\(selectedModuleIds.count)", label: "modules", icon: "square.stack.3d.up", color: AppColors.accent1)
                statBadge(value: "\(totalExerciseCount)", label: "exercises", icon: "dumbbell", color: AppColors.dominant)
                Spacer()
            }
            .padding(.top, AppSpacing.xs)

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.dominant.opacity(0.6), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.top, AppSpacing.sm)
        }
    }

    private var totalExerciseCount: Int {
        let moduleExercises = selectedModuleIds.compactMap { moduleViewModel.getModule(id: $0) }
            .reduce(0) { $0 + $1.exercises.count }
        return moduleExercises + standaloneExercises.count
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .caption(color: color)
                .fontWeight(.medium)
            Text(value)
                .subheadline(color: AppColors.textPrimary)
                .fontWeight(.bold)
            Text(label)
                .caption(color: AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    // MARK: - Workout Info Section

    private var workoutInfoSection: some View {
        FormSection(title: "Workout Info", icon: "figure.strengthtraining.traditional", iconColor: AppColors.dominant) {
            FormTextField(label: "Name", text: $name, icon: "textformat", placeholder: "e.g., Monday - Lower A")
        }
    }

    // MARK: - Modules Section

    private var modulesSection: some View {
        FormSection(title: "Modules", icon: "square.stack.3d.up", iconColor: AppColors.accent1) {
            VStack(spacing: 0) {
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

    private var emptyModulesView: some View {
        BuilderEmptyState(
            icon: "square.stack.3d.up",
            title: "No modules added",
            subtitle: "Browse your library to add modules"
        )
    }

    private var modulesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedModuleIds.enumerated()), id: \.element) { index, moduleId in
                if let module = moduleViewModel.getModule(id: moduleId) {
                    moduleRow(module: module, index: index)
                        .onDrag {
                            draggedModuleId = moduleId
                            return NSItemProvider(object: moduleId.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: ModuleDropDelegate(
                            item: moduleId,
                            items: $selectedModuleIds,
                            draggedItem: $draggedModuleId
                        ))

                    if index < selectedModuleIds.count - 1 {
                        FormDivider()
                    }
                }
            }
        }
    }

    private func moduleRow(module: Module, index: Int) -> some View {
        BuilderItemRow(
            index: index,
            title: module.name,
            subtitle: "\(module.type.displayName) • \(module.exercises.count) exercises",
            accentColor: AppColors.moduleColor(module.type),
            showDragHandle: true,
            onDelete: {
                withAnimation {
                    _ = selectedModuleIds.remove(at: index)
                }
            }
        )
    }

    private var browseModulesButton: some View {
        BuilderActionButton(
            icon: "folder",
            title: "Browse Module Library",
            color: AppColors.accent1,
            action: { showingModulePicker = true }
        )
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        FormSection(title: "Standalone Exercises", icon: "dumbbell", iconColor: AppColors.dominant) {
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
                    .background(AppColors.surfacePrimary)
            }
        }
    }

    private var exerciseQuickAddBar: some View {
        BuilderQuickAddBar(
            placeholder: "Quick add exercise...",
            text: $exerciseSearchText,
            accentColor: AppColors.dominant,
            showAddButton: true,
            onAdd: {
                addCustomExercise(name: exerciseSearchText)
                exerciseSearchText = ""
            }
        )
    }

    private var exerciseSearchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(quickExerciseResults) { template in
                BuilderSearchResultRow(
                    icon: template.exerciseType.icon,
                    iconColor: AppColors.dominant,
                    title: template.name,
                    subtitle: template.exerciseType.displayName,
                    accentColor: AppColors.dominant,
                    onSelect: {
                        addExerciseFromTemplate(template)
                        exerciseSearchText = ""
                    }
                )

                if template.id != quickExerciseResults.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    private var emptyExercisesView: some View {
        BuilderEmptyState(
            icon: "dumbbell",
            title: "No standalone exercises",
            subtitle: "Add exercises that aren't part of a module"
        )
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
    @State private var draggedModuleId: UUID?

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
                        .foregroundColor(AppColors.dominant)
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
                    .foregroundColor(AppColors.dominant)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surfacePrimary)
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
                        .font(.title3)
                        .foregroundColor(selectedForSuperset.contains(exercise.id) ? AppColors.dominant : AppColors.textTertiary)
                }
            } else {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 20)
            }

            // Superset indicator
            if let supersetId = exercise.supersetGroupId {
                let supersetIndex = getSupersetIndex(for: supersetId)
                ZStack {
                    Circle()
                        .fill(AppColors.accent1.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Text("S\(supersetIndex)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.accent1)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.dominant.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.dominant)
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
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 32, height: 32)
            }

            Button {
                withAnimation {
                    _ = standaloneExercises.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundColor(AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var browseExercisesButton: some View {
        VStack(spacing: 0) {
            BuilderActionButton(
                icon: "books.vertical",
                title: "Browse Exercise Library",
                color: AppColors.dominant,
                action: { showingExercisePicker = true }
            )

            FormDivider()

            BuilderActionButton(
                icon: "plus.circle",
                title: "Create New Exercise",
                color: AppColors.accent1,
                action: { showingCreateExercise = true }
            )
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

    // MARK: - Actions

    private func loadWorkout() {
        if let workout = workout {
            name = workout.name
            notes = workout.notes ?? ""
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
            cardioMetric: template.cardioMetric,
            distanceUnit: template.distanceUnit,
            mobilityTracking: template.mobilityTracking,
            isBodyweight: template.isBodyweight,
            isUnilateral: template.isUnilateral,
            recoveryActivityType: template.recoveryActivityType,
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

        let moduleRefs = selectedModuleIds.enumerated().map { index, moduleId in
            ModuleReference(moduleId: moduleId, order: index)
        }

        let workoutExercises = standaloneExercises.enumerated().map { index, instance in
            WorkoutExercise(exercise: instance, order: index)
        }

        if var existingWorkout = workout {
            existingWorkout.name = trimmedName
            existingWorkout.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            existingWorkout.moduleReferences = moduleRefs
            existingWorkout.standaloneExercises = workoutExercises
            existingWorkout.updatedAt = Date()
            workoutViewModel.saveWorkout(existingWorkout)
        } else {
            let newWorkout = Workout(
                name: trimmedName,
                moduleReferences: moduleRefs,
                standaloneExercises: workoutExercises,
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
                    CategoryPill(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(ModuleType.allCases) { type in
                        CategoryPill(title: type.displayName, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.surfaceTertiary)

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
                                        .font(.title3)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(AppColors.textTertiary)
                                        .font(.title3)
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
                    .background(AppColors.accent1)
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

// MARK: - Module Drop Delegate

struct ModuleDropDelegate: DropDelegate {
    let item: UUID
    @Binding var items: [UUID]
    @Binding var draggedItem: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let fromIndex = items.firstIndex(of: draggedItem),
              let toIndex = items.firstIndex(of: item) else {
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
