//
//  BuilderQuickAddBar.swift
//  gym app
//
//  Reusable quick add search bar for builder views
//

import SwiftUI

struct BuilderQuickAddBar: View {
    let placeholder: String
    @Binding var text: String
    let accentColor: Color
    var showAddButton: Bool = true
    var onAdd: (() -> Void)?
    var onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .body(color: AppColors.textTertiary)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit {
                    if !text.isEmpty {
                        onAdd?()
                    }
                }

            if !text.isEmpty {
                if showAddButton {
                    Button {
                        onAdd?()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .displaySmall(color: accentColor)
                    }
                } else if let onClear = onClear {
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .body(color: AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }
}

#Preview {
    VStack(spacing: 0) {
        BuilderQuickAddBar(
            placeholder: "Quick add exercise...",
            text: .constant("Bench Press"),
            accentColor: AppColors.dominant,
            showAddButton: true,
            onAdd: { }
        )

        Divider()

        BuilderQuickAddBar(
            placeholder: "Quick add module...",
            text: .constant("Upper Body"),
            accentColor: AppColors.accent1,
            showAddButton: false,
            onClear: { }
        )
    }
    .background(AppColors.background)
}
