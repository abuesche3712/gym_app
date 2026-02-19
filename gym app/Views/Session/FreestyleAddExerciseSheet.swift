//
//  FreestyleAddExerciseSheet.swift
//  gym app
//
//  Sheet for adding exercises to a freestyle session
//

import SwiftUI

struct FreestyleAddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel

    // Exercise picker state
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var showingExercisePicker = false
    @State private var showingModulePicker = false

    // Quick add state
    @State private var customName = ""
    @State private var selectedType: ExerciseType = .strength

    // Recent exercises from history
    @State private var recentExercises: [(name: String, type: ExerciseType, implementIds: Set<UUID>, isBodyweight: Bool)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Search from library
                    searchFromLibrarySection

                    // Add complete modules
                    modulesFromLibrarySection

                    // Recent exercises
                    if !recentExercises.isEmpty {
                        recentExercisesSection
                    }

                    // Divider
                    dividerRow

                    // Quick add custom
                    quickAddSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background)
            .navigationTitle("Add to Freestyle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedTemplate: $selectedTemplate,
                    customName: $customName,
                    onSelect: { template in
                        if let template = template {
                            addFromTemplate(template)
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingModulePicker) {
                FreestyleModulePickerSheet { modules in
                    addModules(modules)
                }
            }
            .onAppear {
                loadRecentExercises()
            }
        }
    }

    // MARK: - Search From Library Section

    private var searchFromLibrarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("FROM LIBRARY")
                .elegantLabel(color: AppColors.textTertiary)

            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textTertiary)

                    Text("Search exercises...")
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfacePrimary)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Modules From Library

    private var modulesFromLibrarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("MODULES")
                .elegantLabel(color: AppColors.textTertiary)

            Button {
                showingModulePicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundColor(AppColors.textTertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add module from library")
                            .body(color: AppColors.textPrimary)
                        Text(modulePickerSubtitle)
                            .caption(color: AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfacePrimary)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasAddableModules)
            .opacity(hasAddableModules ? 1 : 0.7)
        }
    }

    private var hasAddableModules: Bool {
        moduleViewModel.modules.contains(where: { $0.hasExercises })
    }

    private var modulePickerSubtitle: String {
        let count = moduleViewModel.modules.filter(\.hasExercises).count
        return count == 0
            ? "Create a module with exercises first"
            : "\(count) module\(count == 1 ? "" : "s") available"
    }

    // MARK: - Recent Exercises Section

    private var recentExercisesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("RECENT")
                .elegantLabel(color: AppColors.textTertiary)

            VStack(spacing: 0) {
                ForEach(Array(recentExercises.prefix(5).enumerated()), id: \.offset) { index, exercise in
                    Button {
                        addRecentExercise(exercise)
                    } label: {
                        HStack {
                            Image(systemName: exercise.type.icon)
                                .foregroundColor(AppColors.dominant)
                                .frame(width: 24)

                            Text(exercise.name)
                                .body()

                            Spacer()

                            Text(exercise.type.displayName)
                                .caption(color: AppColors.textTertiary)

                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.dominant)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .buttonStyle(.plain)

                    if index < min(recentExercises.count, 5) - 1 {
                        Divider()
                            .background(AppColors.surfaceTertiary)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfacePrimary)
            )
        }
    }

    // MARK: - Divider Row

    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(AppColors.surfaceTertiary)
                .frame(height: 1)

            Text("or")
                .caption(color: AppColors.textTertiary)

            Rectangle()
                .fill(AppColors.surfaceTertiary)
                .frame(height: 1)
        }
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("QUICK ADD")
                .elegantLabel(color: AppColors.textTertiary)

            VStack(spacing: AppSpacing.md) {
                // Exercise name field
                TextField("Exercise name", text: $customName)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfacePrimary)
                    )

                // Type picker
                HStack(spacing: AppSpacing.sm) {
                    ForEach([ExerciseType.strength, .cardio, .mobility, .isometric, .explosive, .recovery], id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.shortName)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppCorners.small)
                                    .fill(selectedType == type ? AppColors.dominant.opacity(0.2) : AppColors.surfacePrimary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.small)
                                    .stroke(selectedType == type ? AppColors.dominant : Color.clear, lineWidth: 1)
                            )
                            .foregroundColor(selectedType == type ? AppColors.dominant : AppColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Add button
                Button {
                    addCustomExercise()
                } label: {
                    Text("Add Exercise")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(customName.isEmpty ? AppColors.surfaceTertiary : AppColors.dominant)
                        )
                        .foregroundColor(customName.isEmpty ? AppColors.textTertiary : .white)
                }
                .buttonStyle(.plain)
                .disabled(customName.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func addFromTemplate(_ template: ExerciseTemplate) {
        sessionViewModel.addExerciseToFreestyle(
            exerciseName: template.name,
            exerciseType: template.exerciseType,
            implementIds: template.implementIds,
            isBodyweight: template.isBodyweight,
            distanceUnit: template.distanceUnit
        )
        HapticManager.shared.tap()
        dismiss()
    }

    private func addRecentExercise(_ exercise: (name: String, type: ExerciseType, implementIds: Set<UUID>, isBodyweight: Bool)) {
        sessionViewModel.addExerciseToFreestyle(
            exerciseName: exercise.name,
            exerciseType: exercise.type,
            implementIds: exercise.implementIds,
            isBodyweight: exercise.isBodyweight
        )
        HapticManager.shared.tap()
        dismiss()
    }

    private func addCustomExercise() {
        guard !customName.isEmpty else { return }
        sessionViewModel.addExerciseToFreestyle(
            exerciseName: customName,
            exerciseType: selectedType
        )
        HapticManager.shared.tap()
        dismiss()
    }

    private func addModules(_ modules: [Module]) {
        guard !modules.isEmpty else { return }
        sessionViewModel.addModulesToFreestyle(modules)
        HapticManager.shared.tap()
        dismiss()
    }

    // MARK: - Data Loading

    private func loadRecentExercises() {
        // Get unique exercises from recent sessions
        var seen = Set<String>()
        var recent: [(name: String, type: ExerciseType, implementIds: Set<UUID>, isBodyweight: Bool)] = []

        for session in sessionViewModel.sessions.prefix(20) {
            for module in session.completedModules {
                for exercise in module.completedExercises {
                    let key = exercise.exerciseName.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        recent.append((
                            name: exercise.exerciseName,
                            type: exercise.exerciseType,
                            implementIds: exercise.implementIds,
                            isBodyweight: exercise.isBodyweight
                        ))
                    }
                    if recent.count >= 10 { break }
                }
                if recent.count >= 10 { break }
            }
            if recent.count >= 10 { break }
        }

        recentExercises = recent
    }
}

// MARK: - Freestyle Module Picker

private struct FreestyleModulePickerSheet: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let onAdd: ([Module]) -> Void

    @State private var searchText = ""
    @State private var selectedType: ModuleType?
    @State private var pendingSelections: Set<UUID> = []

    private var filteredModules: [Module] {
        var modules = moduleViewModel.modules.filter(\.hasExercises)

        if let type = selectedType {
            modules = modules.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            modules = modules.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return modules.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                List {
                    if filteredModules.isEmpty {
                        ContentUnavailableView(
                            "No Modules",
                            systemImage: "square.stack.3d.up",
                            description: Text("No modules with exercises match this filter")
                        )
                    } else {
                        ForEach(filteredModules) { module in
                            Button {
                                toggleSelection(module.id)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    Image(systemName: module.type.icon)
                                        .foregroundColor(AppColors.moduleColor(module.type))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(module.name)
                                            .subheadline(color: AppColors.textPrimary)
                                        Text("\(module.exercises.count) exercises")
                                            .caption(color: AppColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: pendingSelections.contains(module.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(pendingSelections.contains(module.id) ? AppColors.success : AppColors.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)

                if !pendingSelections.isEmpty {
                    Button {
                        let selectedModules = moduleViewModel.modules.filter { pendingSelections.contains($0.id) }
                        onAdd(selectedModules)
                        dismiss()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add \(pendingSelections.count) Module\(pendingSelections.count == 1 ? "" : "s")")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.dominant)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
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
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if pendingSelections.contains(id) {
            pendingSelections.remove(id)
        } else {
            pendingSelections.insert(id)
        }
    }
}

// MARK: - ExerciseType Extension

private extension ExerciseType {
    var shortName: String {
        switch self {
        case .strength: return "Str"
        case .cardio: return "Car"
        case .mobility: return "Mob"
        case .isometric: return "Iso"
        case .explosive: return "Exp"
        case .recovery: return "Rec"
        }
    }
}
