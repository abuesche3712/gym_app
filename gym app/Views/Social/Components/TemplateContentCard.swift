//
//  TemplateContentCard.swift
//  gym app
//
//  Template content card for post detail view (programs, workouts, modules)
//

import SwiftUI

struct TemplateContentCard: View {
    let type: String
    let name: String
    let icon: String
    let color: Color
    let snapshot: Data
    let onTap: (() -> Void)?

    init(type: String, name: String, icon: String, color: Color, snapshot: Data, onTap: (() -> Void)? = nil) {
        self.type = type
        self.name = name
        self.icon = icon
        self.color = color
        self.snapshot = snapshot
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(type.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(color)

            Text(name)
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            if onTap != nil {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                    Text("Tap to preview")
                }
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
