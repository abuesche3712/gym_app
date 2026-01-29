//
//  SyncErrorBanner.swift
//  gym app
//
//  User-facing sync error banner with retry capability
//

import SwiftUI

/// A dismissible banner that displays sync errors to the user
struct SyncErrorBanner: View {
    let errorInfo: SyncErrorInfo
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @State private var isRetrying = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Error icon
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.title2)
                .foregroundColor(.white)

            // Error message
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Error")
                    .subheadline(color: .white)
                    .fontWeight(.bold)

                Text(errorInfo.message)
                    .caption(color: .white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            // Action buttons
            HStack(spacing: AppSpacing.sm) {
                if errorInfo.isRetryable {
                    Button {
                        isRetrying = true
                        onRetry()
                    } label: {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isRetrying)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.error)
        )
        .padding(.horizontal, AppSpacing.md)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SyncErrorBanner(
            errorInfo: SyncErrorInfo(
                message: "Failed to connect to server. Check your internet connection.",
                isRetryable: true
            ),
            onDismiss: {},
            onRetry: {}
        )

        SyncErrorBanner(
            errorInfo: SyncErrorInfo(
                message: "Permission denied",
                isRetryable: false
            ),
            onDismiss: {},
            onRetry: {}
        )
    }
    .padding()
}
