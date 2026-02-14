//
//  UndoToast.swift
//  gym app
//
//  Undo toast shown after soft-deleting a session
//

import SwiftUI

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "trash")
                .font(.body.weight(.medium))
                .foregroundColor(.white)

            Text(message)
                .subheadline(color: .white)
                .lineLimit(1)

            Spacer()

            Button {
                onUndo()
            } label: {
                Text("Undo")
                    .subheadline(color: AppColors.accent2)
                    .fontWeight(.bold)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfaceSecondary)
        )
        .padding(.horizontal, AppSpacing.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
