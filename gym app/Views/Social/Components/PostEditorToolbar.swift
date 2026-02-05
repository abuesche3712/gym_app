//
//  PostEditorToolbar.swift
//  gym app
//
//  Reusable toolbar for post creation/editing
//

import SwiftUI

struct PostEditorToolbar: ToolbarContent {
    let isProcessing: Bool
    let canSubmit: Bool
    let submitTitle: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
                .font(.body)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(action: onSubmit) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(submitTitle)
                        .font(.headline.weight(.semibold))
                }
            }
            .disabled(isProcessing || !canSubmit)
            .foregroundColor(!canSubmit ? AppColors.textTertiary : AppColors.dominant)
        }
    }
}
