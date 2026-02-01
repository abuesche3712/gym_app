//
//  ComposePostSheet.swift
//  gym app
//
//  Sheet for creating new posts to the feed
//

import SwiftUI

struct ComposePostSheet: View {
    @StateObject private var viewModel: ComposePostViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCaptionFocused: Bool

    /// Initialize for a text-only post
    init() {
        _viewModel = StateObject(wrappedValue: ComposePostViewModel())
    }

    /// Initialize with shareable content (session, exercise, etc.)
    init(content: any ShareableContent) {
        _viewModel = StateObject(wrappedValue: ComposePostViewModel(content: content))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Show error if content creation failed
                    if let error = viewModel.contentCreationError {
                        contentErrorView(error)
                    }
                    // Content preview (if not text-only and no error)
                    else if case .text = viewModel.content {
                        // Text-only post - no preview
                    } else {
                        contentPreview
                    }

                    // Caption input
                    captionInput
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            if await viewModel.createPost() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isPosting || isPostDisabled)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    // MARK: - Content Error View

    private func contentErrorView(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.error)

                Text("Unable to create post")
                    .headline(color: AppColors.error)
            }

            Text(error.localizedDescription)
                .caption(color: AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.error.opacity(0.1))
        .cornerRadius(AppCorners.large)
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Sharing")
                .caption(color: AppColors.textTertiary)
                .fontWeight(.semibold)

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: viewModel.contentIcon)
                    .font(.title3)
                    .foregroundColor(AppColors.dominant)
                    .frame(width: 40, height: 40)
                    .background(AppColors.dominant.opacity(0.15))
                    .cornerRadius(AppCorners.medium)

                Text(viewModel.contentPreview)
                    .subheadline(color: AppColors.textPrimary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .cornerRadius(AppCorners.large)
        }
    }

    // MARK: - Caption Input

    private var captionInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(isTextOnlyPost ? "What's on your mind?" : "Add a caption (optional)")
                .caption(color: AppColors.textTertiary)
                .fontWeight(.semibold)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.caption)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.surfacePrimary)
                    .frame(minHeight: 100)
                    .cornerRadius(AppCorners.large)
                    .focused($isCaptionFocused)

                if viewModel.caption.isEmpty {
                    Text(isTextOnlyPost ? "Share something..." : "Say something about this...")
                        .subheadline(color: AppColors.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }

            // Character count
            HStack {
                Spacer()
                Text("\(viewModel.caption.count)/500")
                    .caption2(color: viewModel.caption.count > 500 ? AppColors.error : AppColors.textTertiary)
            }
        }
    }

    // MARK: - Helpers

    private var isTextOnlyPost: Bool {
        if case .text = viewModel.content {
            return true
        }
        return false
    }

    private var isPostDisabled: Bool {
        if isTextOnlyPost {
            return viewModel.caption.isEmpty || viewModel.caption.count > 500
        }
        return viewModel.caption.count > 500
    }
}

// MARK: - Preview

#Preview("Text Post") {
    ComposePostSheet()
}
