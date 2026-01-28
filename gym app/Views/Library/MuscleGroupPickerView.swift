//
//  MuscleGroupPickerView.swift
//  gym app
//
//  Multi-select picker for muscle groups
//

import SwiftUI

struct MuscleGroupPickerView: View {
    @StateObject private var libraryService = LibraryService.shared
    @Binding var selectedIds: Set<UUID>
    var title: String = "Muscle Groups"
    var subtitle: String? = "Select muscles this exercise targets"

    // Grid layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Grid of muscle groups
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(libraryService.muscleGroups, id: \.id) { muscleGroup in
                    MuscleGroupChip(
                        name: muscleGroup.name,
                        isSelected: selectedIds.contains(muscleGroup.id),
                        action: {
                            toggleSelection(muscleGroup.id)
                        }
                    )
                }
            }

            // Selected count
            if !selectedIds.isEmpty {
                Text("\(selectedIds.count) selected")
                    .font(.caption)
                    .foregroundColor(AppColors.dominant)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

// MARK: - Muscle Group Chip

struct MuscleGroupChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch name {
        case "Chest": return "figure.arms.open"
        case "Back": return "figure.walk"
        case "Shoulders": return "figure.boxing"
        case "Biceps": return "figure.strengthtraining.traditional"
        case "Triceps": return "figure.strengthtraining.functional"
        case "Core": return "figure.core.training"
        case "Quads": return "figure.run"
        case "Hamstrings": return "figure.cooldown"
        case "Glutes": return "figure.hiking"
        case "Calves": return "shoeprints.fill"
        case "Cardio": return "heart.fill"
        default: return "figure.mixed.cardio"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? AppColors.dominant : AppColors.surfaceTertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Muscle Group Display

struct MuscleGroupDisplay: View {
    let muscleGroupIds: Set<UUID>
    @StateObject private var libraryService = LibraryService.shared

    private var muscleNames: [String] {
        muscleGroupIds.compactMap { id in
            libraryService.getMuscleGroup(id: id)?.name
        }.sorted()
    }

    var body: some View {
        if muscleNames.isEmpty {
            Text("None selected")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        } else {
            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(muscleNames, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.dominant.opacity(0.12))
                        )
                        .foregroundColor(AppColors.dominant)
                }
            }
        }
    }
}

#Preview {
    MuscleGroupPickerView(selectedIds: .constant([]))
        .padding()
}
