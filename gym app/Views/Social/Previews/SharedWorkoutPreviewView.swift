//
//  SharedWorkoutPreviewView.swift
//  gym app
//
//  Read-only preview of a shared workout from a ShareBundle
//

import SwiftUI

struct SharedWorkoutPreviewView: View {
    let workout: Workout
    let modules: [Module]
    let showImportButton: Bool
    let onImport: (() -> Void)?

    init(workout: Workout, modules: [Module], showImportButton: Bool = true, onImport: (() -> Void)? = nil) {
        self.workout = workout
        self.modules = modules
        self.showImportButton = showImportButton
        self.onImport = onImport
    }

    // Helper to get module by ID from bundle
    private func module(for reference: ModuleReference) -> Module? {
        modules.first { $0.id == reference.moduleId }
    }

    private var totalExerciseCount: Int {
        modules.reduce(0) { $0 + $1.exerciseCount }
    }

    private var estimatedDuration: Int? {
        let durations = modules.compactMap { $0.estimatedDuration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    var body: some View {
        List {
            // Workout Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundColor(AppColors.dominant)
                            .frame(width: 60, height: 60)
                            .background(AppColors.dominant.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(.title3.weight(.bold))
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: AppSpacing.md) {
                                Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)

                                Label("\(totalExerciseCount) exercises", systemImage: "dumbbell")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            if let duration = estimatedDuration {
                                Label("\(duration) min", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Notes Section
            if let notes = workout.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Modules Section
            Section {
                if workout.moduleReferences.isEmpty {
                    ContentUnavailableView(
                        "No Modules",
                        systemImage: "square.stack.3d.up",
                        description: Text("This workout has no modules")
                    )
                } else {
                    ForEach(Array(workout.moduleReferences.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, reference in
                        if let module = module(for: reference) {
                            NavigationLink {
                                SharedModulePreviewView(
                                    module: module,
                                    showImportButton: false,
                                    onImport: nil
                                )
                            } label: {
                                ModuleReferenceRow(
                                    index: index + 1,
                                    module: module,
                                    reference: reference
                                )
                            }
                        }
                    }
                }
            } header: {
                Text("Modules (\(modules.count))")
            }

            // Import Button Section
            if showImportButton, let onImport = onImport {
                Section {
                    Button {
                        onImport()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Import Workout", systemImage: "square.and.arrow.down")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .listRowBackground(AppColors.dominant)
                    .foregroundColor(.white)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Module Reference Row

private struct ModuleReferenceRow: View {
    let index: Int
    let module: Module
    let reference: ModuleReference

    var body: some View {
        HStack(spacing: 12) {
            // Order number
            Text("\(index)")
                .font(.headline.monospacedDigit())
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 28, height: 28)
                .background(AppColors.surfaceTertiary)
                .clipShape(Circle())

            // Module info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: module.type.icon)
                        .font(.caption)
                        .foregroundColor(module.type.color)

                    Text(module.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }

                HStack(spacing: AppSpacing.sm) {
                    Text(module.type.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text("·")
                        .foregroundColor(AppColors.textTertiary)

                    Text("\(module.exerciseCount) exercises")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    if let duration = module.estimatedDuration {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SharedWorkoutPreviewView(
            workout: Workout(name: "Sample Workout", moduleReferences: []),
            modules: [],
            showImportButton: true,
            onImport: {}
        )
    }
}
