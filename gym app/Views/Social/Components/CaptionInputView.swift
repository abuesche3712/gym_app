//
//  CaptionInputView.swift
//  gym app
//
//  Reusable caption input component for post creation/editing
//

import SwiftUI

struct CaptionInputView: View {
    @Binding var caption: String
    var isFocused: FocusState<Bool>.Binding
    var label: String = "CAPTION"
    var placeholder: String = "Add a caption..."
    var maxLength: Int = 500
    var minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Label
            Text(label)
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            // Text editor with placeholder
            ZStack(alignment: .topLeading) {
                TextEditor(text: $caption)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: minHeight)
                    .focused(isFocused)

                if caption.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        isFocused.wrappedValue ? AppColors.dominant.opacity(0.5) : AppColors.surfaceTertiary.opacity(0.3),
                        lineWidth: isFocused.wrappedValue ? 1.5 : 1
                    )
            )

            // Character count
            HStack {
                Spacer()
                Text("\(caption.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundColor(characterCountColor)
            }
        }
    }

    private var characterCountColor: Color {
        if caption.count > maxLength { return AppColors.error }
        if caption.count > maxLength - 100 { return AppColors.warning }
        return AppColors.textTertiary
    }
}
