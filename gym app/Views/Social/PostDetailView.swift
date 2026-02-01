//
//  PostDetailView.swift
//  gym app
//
//  Detailed view of a single post with comments
//

import SwiftUI

struct PostDetailView: View {
    @StateObject private var viewModel: PostDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @FocusState private var isCommentFieldFocused: Bool

    init(post: PostWithAuthor) {
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(post: post))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        // Post content
                        postSection

                        // Comments
                        commentsSection
                    }
                    .padding(.vertical, AppSpacing.md)
                }

                // Comment input
                commentInput
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadComments()
            }
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Author header
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(avatarInitials)
                            .subheadline(color: AppColors.dominant)
                            .fontWeight(.semibold)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.post.author.displayName ?? viewModel.post.author.username)
                        .headline(color: AppColors.textPrimary)

                    Text(formattedDate)
                        .caption(color: AppColors.textTertiary)
                }

                Spacer()
            }

            // Content
            Group {
                switch viewModel.post.post.content {
                case .text(let text):
                    Text(text)
                        .body(color: AppColors.textPrimary)
                default:
                    SharedContentCard(
                        content: viewModel.post.post.content.toMessageContent(),
                        isFromCurrentUser: false
                    )
                }
            }

            // Caption
            if let caption = viewModel.post.post.caption, !caption.isEmpty {
                Text(caption)
                    .subheadline(color: AppColors.textPrimary)
            }

            // Actions
            HStack(spacing: AppSpacing.lg) {
                Button {
                    Task {
                        await viewModel.toggleLike()
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: viewModel.post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.headline)
                            .foregroundColor(viewModel.post.isLikedByCurrentUser ? AppColors.error : AppColors.textSecondary)

                        Text("\(viewModel.post.post.likeCount) likes")
                            .subheadline(color: AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Text("\(viewModel.post.post.commentCount) comments")
                    .subheadline(color: AppColors.textSecondary)

                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(AppCorners.large)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Comments")
                .headline(color: AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.screenPadding)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.comments.isEmpty {
                Text("No comments yet")
                    .subheadline(color: AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(
                            comment: comment,
                            canDelete: comment.comment.authorId == viewModel.currentUserId,
                            onDelete: {
                                Task {
                                    await viewModel.deleteComment(comment)
                                }
                            }
                        )

                        if comment.id != viewModel.comments.last?.id {
                            Divider()
                                .background(AppColors.surfaceTertiary.opacity(0.5))
                        }
                    }
                }
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppCorners.large)
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("Add a comment...", text: $commentText)
                .textFieldStyle(.plain)
                .padding(AppSpacing.sm)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.medium)
                .focused($isCommentFieldFocused)

            Button {
                Task {
                    let text = commentText
                    commentText = ""
                    isCommentFieldFocused = false
                    await viewModel.sendComment(text: text)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(commentText.isEmpty ? AppColors.textTertiary : AppColors.dominant)
            }
            .disabled(commentText.isEmpty || viewModel.isSendingComment)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Helpers

    private var avatarInitials: String {
        if let displayName = viewModel.post.author.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(viewModel.post.author.username.prefix(2)).uppercased()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: viewModel.post.post.createdAt)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: CommentWithAuthor
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Avatar
            Circle()
                .fill(AppColors.dominant.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(avatarInitials)
                        .caption2(color: AppColors.dominant)
                        .fontWeight(.semibold)
                }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(comment.author.displayName ?? comment.author.username)
                        .caption(color: AppColors.textPrimary)
                        .fontWeight(.semibold)

                    Text(relativeTime)
                        .caption2(color: AppColors.textTertiary)

                    Spacer()

                    if canDelete {
                        Menu {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                Text(comment.comment.text)
                    .subheadline(color: AppColors.textPrimary)
            }
        }
        .padding(AppSpacing.md)
        .confirmationDialog(
            "Delete Comment?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatarInitials: String {
        if let displayName = comment.author.displayName, !displayName.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return String(comment.author.username.prefix(1)).uppercased()
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: comment.comment.createdAt, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    PostDetailView(
        post: PostWithAuthor(
            post: Post(
                authorId: "user1",
                content: .text("Just finished an amazing workout!"),
                likeCount: 5,
                commentCount: 2
            ),
            author: UserProfile(id: UUID(), username: "johndoe", displayName: "John Doe"),
            isLikedByCurrentUser: true
        )
    )
}
