//
//  BuilderSearchResultRow.swift
//  gym app
//
//  Reusable search result row for builder views
//

import SwiftUI

struct BuilderSearchResultRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .subheadline(color: iconColor)
                    .frame(width: 24)

                Text(title)
                    .subheadline(color: AppColors.textPrimary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .caption(color: AppColors.textTertiary)
                }

                Image(systemName: "plus.circle")
                    .body(color: accentColor)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceTertiary)
        }
        .buttonStyle(.plain)
    }
}

struct BuilderSearchResultRowWithDetail: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .subheadline(color: iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .subheadline(color: AppColors.textPrimary)
                    Text(detail)
                        .caption(color: AppColors.textTertiary)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .body(color: accentColor)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceTertiary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        BuilderSearchResultRow(
            icon: "dumbbell",
            iconColor: AppColors.dominant,
            title: "Bench Press",
            subtitle: "Strength",
            accentColor: AppColors.dominant,
            onSelect: { }
        )

        Divider().padding(.leading, 56)

        BuilderSearchResultRowWithDetail(
            icon: "square.stack.3d.up",
            iconColor: AppColors.accent1,
            title: "Upper Body Push",
            detail: "5 exercises",
            accentColor: AppColors.accent1,
            onSelect: { }
        )
    }
    .background(AppColors.background)
}
