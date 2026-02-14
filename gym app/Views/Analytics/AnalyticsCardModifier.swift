//
//  AnalyticsCardModifier.swift
//  gym app
//
//  Shared styling for analytics cards.
//

import SwiftUI

private struct AnalyticsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func analyticsCard() -> some View {
        modifier(AnalyticsCardModifier())
    }
}
