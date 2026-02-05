//
//  ContentPreviewCard.swift
//  gym app
//
//  Reusable content preview card for post creation/editing
//

import SwiftUI

struct ContentPreviewCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    var isLocked: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundColor(iconColor)
            }

            // Content info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            // Trailing: lock icon or remove button
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            } else if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
    }
}
