//
//  BuilderEmptyState.swift
//  gym app
//
//  Reusable empty state placeholder for builder views
//

import SwiftUI

struct BuilderEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .displaySmall(color: AppColors.textTertiary.opacity(0.5))

            Text(title)
                .subheadline(color: AppColors.textTertiary)

            Text(subtitle)
                .caption(color: AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.surfacePrimary)
    }
}

#Preview {
    VStack(spacing: 20) {
        BuilderEmptyState(
            icon: "dumbbell",
            title: "No exercises yet",
            subtitle: "Search above or browse the library"
        )

        BuilderEmptyState(
            icon: "square.stack.3d.up",
            title: "No modules added",
            subtitle: "Search above or browse your library"
        )
    }
    .padding()
    .background(AppColors.background)
}
