//
//  SharedModulePreviewView.swift
//  gym app
//
//  Read-only preview of a shared module from a ShareBundle
//

import SwiftUI

struct SharedModulePreviewView: View {
    let module: Module
    let showImportButton: Bool
    let onImport: (() -> Void)?

    init(module: Module, showImportButton: Bool = true, onImport: (() -> Void)? = nil) {
        self.module = module
        self.showImportButton = showImportButton
        self.onImport = onImport
    }

    var body: some View {
        List {
            // Module Info Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: module.type.icon)
                        .font(.title)
                        .foregroundColor(module.type.color)
                        .frame(width: 60, height: 60)
                        .background(module.type.color.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.name)
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text(module.type.displayName)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        if let duration = module.estimatedDuration {
                            Label("\(duration) min", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Notes Section
            if let notes = module.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Exercises Section
            Section {
                if !module.hasExercises {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("This module has no exercises")
                    )
                } else {
                    ForEach(module.resolvedExercisesGrouped(), id: \.first?.id) { exerciseGroup in
                        if exerciseGroup.count > 1 {
                            // Superset group
                            PreviewSupersetGroupRow(exercises: exerciseGroup)
                        } else if let resolved = exerciseGroup.first {
                            // Single exercise
                            PreviewExerciseRow(exercise: resolved)
                        }
                    }
                }
            } header: {
                Text("Exercises (\(module.exerciseCount))")
            }

            // Import Button Section
            if showImportButton, let onImport = onImport {
                Section {
                    Button {
                        onImport()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Import Module", systemImage: "square.and.arrow.down")
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
        .navigationTitle("Module Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview Exercise Row

private struct PreviewExerciseRow: View {
    let exercise: ResolvedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(exercise.exerciseType.displayName)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.surfaceTertiary)
                    .clipShape(Capsule())
            }

            Text(exercise.formattedSetScheme)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Superset Group Row

private struct PreviewSupersetGroupRow: View {
    let exercises: [ResolvedExercise]

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

                        PreviewCompactExerciseRow(exercise: resolved)
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
}

// MARK: - Preview Compact Exercise Row (for supersets)

private struct PreviewCompactExerciseRow: View {
    let exercise: ResolvedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            Text(exercise.formattedSetScheme)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        SharedModulePreviewView(
            module: Module.sampleStrength,
            showImportButton: true,
            onImport: {}
        )
    }
}
