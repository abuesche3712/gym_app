//
//  BuilderActionButton.swift
//  gym app
//
//  Reusable action button for builder views (browse library, create new, etc.)
//

import SwiftUI

struct BuilderActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .body(color: color)
                    .frame(width: 24)

                Text(title)
                    .body(color: color)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        BuilderActionButton(
            icon: "books.vertical",
            title: "Browse Exercise Library",
            color: AppColors.dominant,
            action: { }
        )

        Divider()

        BuilderActionButton(
            icon: "plus.circle",
            title: "Create New Exercise",
            color: AppColors.accent1,
            action: { }
        )

        Divider()

        BuilderActionButton(
            icon: "folder",
            title: "Browse Module Library",
            color: AppColors.accent1,
            action: { }
        )
    }
    .background(AppColors.background)
}
