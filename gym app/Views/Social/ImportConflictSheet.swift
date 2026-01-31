//
//  ImportConflictSheet.swift
//  gym app
//
//  Sheet for resolving conflicts when importing shared content
//

import SwiftUI

struct ImportConflictSheet: View {
    let conflicts: [ImportConflict]
    let contentName: String
    let onConfirm: (ImportOptions) -> Void
    let onCancel: () -> Void

    @State private var options = ImportOptions()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding()
                    .background(AppColors.surfaceSecondary)

                Divider()

                // Conflicts list
                if conflicts.isEmpty {
                    noConflictsView
                } else {
                    conflictsList
                }

                Divider()

                // Action buttons
                actionButtons
                    .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Import Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.warning)

                Text("Conflicts Detected")
                    .headline(color: AppColors.textPrimary)
            }

            Text("Some items in \"\(contentName)\" already exist in your library. Choose how to handle each conflict.")
                .subheadline(color: AppColors.textSecondary)
        }
    }

    private var noConflictsView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.success)

            Text("No Conflicts")
                .headline(color: AppColors.textPrimary)

            Text("All items can be imported without conflicts")
                .subheadline(color: AppColors.textSecondary)

            Spacer()
        }
    }

    private var conflictsList: some View {
        List {
            ForEach(conflicts) { conflict in
                ConflictRow(
                    conflict: conflict,
                    resolution: binding(for: conflict)
                )
            }
        }
        .listStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: onCancel) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfaceSecondary)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(AppCorners.medium)
            }

            Button {
                onConfirm(options)
            } label: {
                Text("Import")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.dominant)
                    .foregroundColor(.white)
                    .cornerRadius(AppCorners.medium)
            }
        }
    }

    private func binding(for conflict: ImportConflict) -> Binding<ConflictResolution> {
        Binding(
            get: { options.resolution(for: conflict.id) },
            set: { options.conflictResolutions[conflict.id] = $0 }
        )
    }
}

// MARK: - Conflict Row

struct ConflictRow: View {
    let conflict: ImportConflict
    @Binding var resolution: ConflictResolution

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Conflict title
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundColor(AppColors.warning)

                Text(conflict.title)
                    .headline(color: AppColors.textPrimary)
            }

            // Description
            Text(conflictDescription)
                .caption(color: AppColors.textSecondary)

            // Resolution picker
            Picker("Resolution", selection: $resolution) {
                ForEach(ConflictResolution.allCases) { option in
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.rawValue)
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var iconName: String {
        switch conflict {
        case .template:
            return "dumbbell.fill"
        case .implement:
            return "wrench.and.screwdriver.fill"
        }
    }

    private var conflictDescription: String {
        switch conflict {
        case .template(let tc):
            return "You already have an exercise named \"\(tc.existingName)\""
        case .implement(let ic):
            return "You already have equipment named \"\(ic.existingName)\""
        }
    }
}

// MARK: - Preview

#Preview {
    ImportConflictSheet(
        conflicts: [
            .template(TemplateConflict(
                existingId: UUID(),
                existingName: "Custom Squat",
                importedTemplate: ExerciseTemplate(
                    name: "Custom Squat",
                    category: .legs,
                    primary: [.quads]
                )
            ))
        ],
        contentName: "Push Pull Legs",
        onConfirm: { _ in },
        onCancel: {}
    )
}
