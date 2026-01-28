//
//  ModuleDetailView.swift
//  gym app
//
//  Detailed view of a module with its exercises
//

import SwiftUI

struct ModuleDetailView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let module: Module

    @State private var showingEditModule = false
    @State private var showingAddExercise = false
    @State private var showingDeleteConfirmation = false
    @State private var isSelectingForSuperset = false
    @State private var selectedExerciseIds: Set<UUID> = []

    private var currentModule: Module {
        moduleViewModel.getModule(id: module.id) ?? module
    }

    var body: some View {
        List {
            // Module Info Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: currentModule.type.icon)
                        .font(.largeTitle)
                        .foregroundStyle(currentModule.type.color)
                        .frame(width: 60, height: 60)
                        .background(currentModule.type.color.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentModule.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(currentModule.type.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let duration = currentModule.estimatedDuration {
                            Label("\(duration) min", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Notes Section
            if let notes = currentModule.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Exercises Section
            Section {
                if !currentModule.hasExercises {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Add exercises to this module")
                    )
                } else {
                    ForEach(currentModule.resolvedExercisesGrouped(), id: \.first?.id) { exerciseGroup in
                        if exerciseGroup.count > 1 {
                            // Superset group
                            SupersetGroupRow(
                                exercises: exerciseGroup,
                                moduleId: currentModule.id,
                                isSelecting: isSelectingForSuperset,
                                selectedIds: $selectedExerciseIds,
                                onBreakSuperset: {
                                    if let supersetId = exerciseGroup.first?.supersetGroupId {
                                        breakSupersetGroup(supersetId)
                                    }
                                }
                            )
                        } else if let resolved = exerciseGroup.first {
                            // Single exercise
                            if isSelectingForSuperset {
                                Button {
                                    toggleSelection(resolved.id)
                                } label: {
                                    HStack {
                                        Image(systemName: selectedExerciseIds.contains(resolved.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedExerciseIds.contains(resolved.id) ? AppColors.dominant : .gray)
                                        ExerciseRow(exercise: resolved)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(destination: ExerciseFormView(instance: resolved.instance, moduleId: currentModule.id)) {
                                    ExerciseRow(exercise: resolved)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)
                }
            } header: {
                HStack {
                    Text("Exercises (\(currentModule.exerciseCount))")
                    Spacer()
                    if isSelectingForSuperset {
                        Button("Done") {
                            if selectedExerciseIds.count >= 2 {
                                createSuperset()
                            }
                            isSelectingForSuperset = false
                            selectedExerciseIds.removeAll()
                        }
                        .disabled(selectedExerciseIds.count < 2)
                    } else {
                        Button {
                            showingAddExercise = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("Module")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditModule = true
                    } label: {
                        Label("Edit Module", systemImage: "pencil")
                    }

                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }

                    if currentModule.exerciseCount >= 2 {
                        Divider()

                        Button {
                            isSelectingForSuperset = true
                            selectedExerciseIds.removeAll()
                        } label: {
                            Label("Create Superset", systemImage: "link")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Module", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditModule) {
            NavigationStack {
                ModuleFormView(module: currentModule)
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            NavigationStack {
                ExerciseFormView(instance: nil, moduleId: currentModule.id)
            }
        }
        .confirmationDialog(
            "Delete Module",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                moduleViewModel.deleteModule(currentModule)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(currentModule.name)\"? This action cannot be undone.")
        }
    }

    private func deleteExercise(at offsets: IndexSet) {
        var updatedModule = currentModule
        updatedModule.exercises.remove(atOffsets: offsets)
        updatedModule.updatedAt = Date()
        moduleViewModel.saveModule(updatedModule)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        var updatedModule = currentModule
        updatedModule.exercises.move(fromOffsets: source, toOffset: destination)
        updatedModule.updatedAt = Date()
        moduleViewModel.saveModule(updatedModule)
    }

    private func toggleSelection(_ exerciseId: UUID) {
        if selectedExerciseIds.contains(exerciseId) {
            selectedExerciseIds.remove(exerciseId)
        } else {
            selectedExerciseIds.insert(exerciseId)
        }
    }

    private func createSuperset() {
        var updatedModule = currentModule
        updatedModule.createSuperset(exerciseIds: Array(selectedExerciseIds))
        moduleViewModel.saveModule(updatedModule)
    }

    private func breakSupersetGroup(_ supersetGroupId: UUID) {
        var updatedModule = currentModule
        updatedModule.breakSupersetGroup(supersetGroupId: supersetGroupId)
        moduleViewModel.saveModule(updatedModule)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ResolvedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                Text(exercise.exerciseType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }

            Text(exercise.formattedSetScheme)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Superset Group Row

struct SupersetGroupRow: View {
    let exercises: [ResolvedExercise]
    let moduleId: UUID
    let isSelecting: Bool
    @Binding var selectedIds: Set<UUID>
    let onBreakSuperset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Superset header
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(AppColors.warning)
                Text("SUPERSET")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.warning)
                Spacer()
                if !isSelecting {
                    Button {
                        onBreakSuperset()
                    } label: {
                        Text("Unlink")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 8)

            // Exercises in superset
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, resolved in
                    HStack(spacing: 12) {
                        // Connector line
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(AppColors.warning.opacity(index == 0 ? 0 : 0.5))
                                .frame(width: 2)
                            Circle()
                                .fill(AppColors.warning)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(AppColors.warning.opacity(index == exercises.count - 1 ? 0 : 0.5))
                                .frame(width: 2)
                        }
                        .frame(width: 8)

                        if isSelecting {
                            Button {
                                toggleSelection(resolved.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedIds.contains(resolved.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedIds.contains(resolved.id) ? AppColors.dominant : .gray)
                                    CompactExerciseRow(exercise: resolved)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: ExerciseFormView(instance: resolved.instance, moduleId: moduleId)) {
                                CompactExerciseRow(exercise: resolved)
                            }
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.warning.opacity(0.05))
        )
    }

    private func toggleSelection(_ exerciseId: UUID) {
        if selectedIds.contains(exerciseId) {
            selectedIds.remove(exerciseId)
        } else {
            selectedIds.insert(exerciseId)
        }
    }
}

// MARK: - Compact Exercise Row (for supersets)

struct CompactExerciseRow: View {
    let exercise: ResolvedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.subheadline.weight(.medium))

            Text(exercise.formattedSetScheme)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        ModuleDetailView(module: Module.sampleStrength)
            .environmentObject(ModuleViewModel())
    }
}
