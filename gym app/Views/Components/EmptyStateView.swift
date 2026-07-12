//
//  EmptyStateView.swift
//  gym app
//
//  Reusable empty state component for list views
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var buttonIcon: String? = nil
    var onButtonTap: (() -> Void)? = nil

    /// Base icon point size (at the default Dynamic Type size), scaled with accessibility text sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(AppColors.textTertiary)

            Text(title)
                .headline(color: AppColors.textSecondary)

            Text(subtitle)
                .caption(color: AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            if let buttonTitle, let onButtonTap {
                Button {
                    onButtonTap()
                } label: {
                    if let buttonIcon {
                        Label(buttonTitle, systemImage: buttonIcon)
                    } else {
                        Text(buttonTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.dominant)
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}
