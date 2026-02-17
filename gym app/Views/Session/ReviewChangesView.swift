//
//  ReviewChangesView.swift
//  gym app
//
//  Sheet for reviewing and selecting structural changes to commit to module templates
//

import SwiftUI

struct ReviewChangesView: View {
    let changes: [StructuralChange]
    let onCommit: ([StructuralChange]) -> Void
    let onDiscard: () -> Void

    @State private var selectedChanges: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    // Group changes by module for display
    private var changesByModule: [(moduleName: String, moduleId: UUID, changes: [StructuralChange])] {
        Dictionary(grouping: changes) { $0.moduleId }
            .map { (moduleName: $0.value.first?.moduleName ?? "Unknown", moduleId: $0.key, changes: $0.value) }
            .sorted { $0.moduleName < $1.moduleName }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header explanation
                    headerSection

                    // Changes grouped by module
                    ForEach(changesByModule, id: \.moduleId) { group in
                        moduleChangeSection(group)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard All") {
                        onDiscard()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Selected") {
                        let selected = changes.filter { selectedChanges.contains($0.id) }
                        onCommit(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(selectedChanges.isEmpty ? AppColors.textTertiary : AppColors.dominant)
                    .disabled(selectedChanges.isEmpty)
                }
            }
            .onAppear {
                // Pre-select all changes by default
                selectedChanges = Set(changes.map { $0.id })
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(AppColors.dominant)

                Text("Workout Changes Detected")
                    .headline(color: AppColors.textPrimary)
            }

            Text("You modified your workout during this session. Select which changes to save back to your templates for next time.")
                .subheadline(color: AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Module Change Section

    private func moduleChangeSection(_ group: (moduleName: String, moduleId: UUID, changes: [StructuralChange])) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Module header with Select All / None
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "folder")
                        .foregroundColor(AppColors.dominant)
                    Text(group.moduleName)
                        .headline(color: AppColors.textPrimary)
                }

                Spacer()

                Button(allSelected(in: group.changes) ? "Deselect All" : "Select All") {
                    toggleAll(in: group.changes)
                }
                .font(.caption)
                .foregroundColor(AppColors.dominant)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // Individual changes
            VStack(spacing: 0) {
                ForEach(Array(group.changes.enumerated()), id: \.element.id) { index, change in
                    ChangeRow(
                        change: change,
                        isSelected: selectedChanges.contains(change.id),
                        onToggle: { toggleChange(change) }
                    )

                    if index < group.changes.count - 1 {
                        Divider()
                            .background(AppColors.surfaceTertiary)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Selection Helpers

    private func allSelected(in changes: [StructuralChange]) -> Bool {
        changes.allSatisfy { selectedChanges.contains($0.id) }
    }

    private func toggleAll(in changes: [StructuralChange]) {
        if allSelected(in: changes) {
            // Deselect all in this group
            for change in changes {
                selectedChanges.remove(change.id)
            }
        } else {
            // Select all in this group
            for change in changes {
                selectedChanges.insert(change.id)
            }
        }
    }

    private func toggleChange(_ change: StructuralChange) {
        if selectedChanges.contains(change.id) {
            selectedChanges.remove(change.id)
        } else {
            selectedChanges.insert(change.id)
        }
    }
}

// MARK: - Change Row

struct ChangeRow: View {
    let change: StructuralChange
    let isSelected: Bool
    let onToggle: () -> Void

    private var changeColor: Color {
        switch change.color {
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error": return AppColors.error
        default: return AppColors.dominant
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            onToggle()
        }) {
            HStack(spacing: AppSpacing.md) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.dominant : AppColors.textTertiary)

                // Icon
                ZStack {
                    Circle()
                        .fill(changeColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: change.icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(changeColor)
                }

                // Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.exerciseName)
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.medium)

                    Text(changeDescription)
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var changeDescription: String {
        switch change {
        case .setCountChanged(_, _, _, _, let from, let to):
            let direction = to > from ? "+" : ""
            let diff = to - from
            return "\(direction)\(diff) sets (\(from) → \(to))"

        case .exerciseAdded:
            return "New exercise added"

        case .exerciseRemoved:
            return "Exercise removed"

        case .exerciseReordered(_, _, _, _, let from, let to):
            let direction = to < from ? "Moved up" : "Moved down"
            return "\(direction) in order"

        case .exerciseSubstituted(_, let originalName, let newName, _, _):
            return "\(originalName) → \(newName)"
        }
    }
}

// MARK: - Preview

#Preview {
    ReviewChangesView(
        changes: [
            .setCountChanged(
                exerciseInstanceId: UUID(),
                exerciseName: "Bench Press",
                moduleId: UUID(),
                moduleName: "Push",
                from: 3,
                to: 4
            ),
            .exerciseRemoved(
                exerciseInstanceId: UUID(),
                exerciseName: "Tricep Pushdown",
                moduleId: UUID(),
                moduleName: "Push"
            )
        ],
        onCommit: { _ in },
        onDiscard: { }
    )
}
