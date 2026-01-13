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
                        .foregroundStyle(Color(currentModule.type.color))
                        .frame(width: 60, height: 60)
                        .background(Color(currentModule.type.color).opacity(0.2))
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
                if currentModule.exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Add exercises to this module")
                    )
                } else {
                    ForEach(currentModule.exercises) { exercise in
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise, moduleId: currentModule.id)) {
                            ExerciseRow(exercise: exercise)
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)
                }
            } header: {
                HStack {
                    Text("Exercises (\(currentModule.exercises.count))")
                    Spacer()
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Module", systemImage: "trash")
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
                ExerciseFormView(exercise: nil, moduleId: currentModule.id)
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
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: Exercise

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

#Preview {
    NavigationStack {
        ModuleDetailView(module: Module.sampleStrength)
            .environmentObject(ModuleViewModel())
    }
}
