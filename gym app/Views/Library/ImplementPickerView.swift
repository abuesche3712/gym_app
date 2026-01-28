//
//  ImplementPickerView.swift
//  gym app
//
//  Multi-select picker for implements (equipment)
//

import SwiftUI

struct ImplementPickerView: View {
    @StateObject private var libraryService = LibraryService.shared
    @Binding var selectedIds: Set<UUID>
    var title: String = "Equipment"
    var subtitle: String? = "What equipment does this exercise use?"

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

            // Grid of implements
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(libraryService.implements, id: \.id) { implement in
                    ImplementChip(
                        name: implement.name,
                        isSelected: selectedIds.contains(implement.id),
                        action: {
                            toggleSelection(implement.id)
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

// MARK: - Implement Chip

struct ImplementChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch name {
        case "Barbell": return "figure.strengthtraining.traditional"
        case "Dumbbell": return "dumbbell.fill"
        case "Cable": return "cable.connector"
        case "Machine": return "gearshape.fill"
        case "Kettlebell": return "figure.strengthtraining.functional"
        case "Box": return "square.stack.3d.up.fill"
        case "Band": return "circle.hexagonpath.fill"
        case "Bodyweight": return "figure.stand"
        default: return "wrench.and.screwdriver.fill"
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
                    .fill(isSelected ? AppColors.accent1 : AppColors.surfaceTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(isSelected ? AppColors.accent1 : AppColors.surfaceTertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Implement Display

struct ImplementDisplay: View {
    let implementIds: Set<UUID>
    @StateObject private var libraryService = LibraryService.shared

    private var implementNames: [String] {
        implementIds.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }

    var body: some View {
        if implementNames.isEmpty {
            Text("None selected")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        } else {
            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(implementNames, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.accent1.opacity(0.12))
                        )
                        .foregroundColor(AppColors.accent1)
                }
            }
        }
    }
}

// MARK: - Band Color Input

struct BandColorInput: View {
    @Binding var color: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Band Color")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            TextField("e.g., Red, Blue, Green", text: $color)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    ImplementPickerView(selectedIds: .constant([]))
        .padding()
}
