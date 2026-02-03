//
//  BuilderItemRow.swift
//  gym app
//
//  Reusable item row for builder views
//

import SwiftUI

struct BuilderItemRow: View {
    let index: Int
    let title: String
    let subtitle: String?
    let accentColor: Color
    var showDragHandle: Bool = false
    var showEditButton: Bool = false
    var customIndicator: AnyView? = nil
    var onEdit: (() -> Void)?
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Drag handle (optional)
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .subheadline(color: AppColors.textTertiary)
                    .fontWeight(.medium)
                    .frame(width: 20)
            }

            // Order indicator or custom indicator
            if let customIndicator = customIndicator {
                customIndicator
            } else {
                orderIndicator
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .caption(color: AppColors.textSecondary)
                }
            }

            Spacer()

            // Edit button (optional)
            if showEditButton, let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .subheadline(color: AppColors.textTertiary)
                        .frame(width: 32, height: 32)
                }
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .body(color: AppColors.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var orderIndicator: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 28, height: 28)
            Text("\(index + 1)")
                .caption(color: accentColor)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        BuilderItemRow(
            index: 0,
            title: "Bench Press",
            subtitle: "Strength - 3x10",
            accentColor: AppColors.dominant,
            showDragHandle: true,
            showEditButton: true,
            onEdit: { },
            onDelete: { }
        )

        Divider()

        BuilderItemRow(
            index: 1,
            title: "Upper Body Push",
            subtitle: "Strength - 5 exercises",
            accentColor: AppColors.accent1,
            showDragHandle: true,
            onDelete: { }
        )

        Divider()

        BuilderItemRow(
            index: 2,
            title: "Squats",
            subtitle: nil,
            accentColor: AppColors.dominant,
            showEditButton: true,
            onEdit: { },
            onDelete: { }
        )
    }
    .background(AppColors.background)
}
