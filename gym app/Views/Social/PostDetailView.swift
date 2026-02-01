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
    @State private var isLikeAnimating = false

    init(post: PostWithAuthor) {
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(post: post))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Full post
                        postSection

                        // Comments section
                        commentsSection
                    }
                    .padding(.vertical, AppSpacing.md)
                }

                // Comment input bar
                commentInputBar
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
            }
            .onAppear {
                viewModel.loadComments()
            }
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author row
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                PostAvatarView(
                    displayName: viewModel.post.author.displayName,
                    username: viewModel.post.author.username,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.post.author.displayName ?? viewModel.post.author.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("@\(viewModel.post.author.username)")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.cardPadding)

            // Caption
            if let caption = viewModel.post.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.md)
            }

            // Content (if not text-only)
            if case .text = viewModel.post.post.content {
                // Text-only post, caption is the content
            } else {
                PostContentCard(content: viewModel.post.post.content)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.md)
            }

            // Engagement stats
            HStack(spacing: AppSpacing.lg) {
                // Like button
                Button {
                    HapticManager.shared.impact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLikeAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isLikeAnimating = false
                        }
                    }
                    Task {
                        await viewModel.toggleLike()
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: viewModel.post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.headline)
                            .foregroundColor(viewModel.post.isLikedByCurrentUser ? AppColors.error : AppColors.textSecondary)
                            .scaleEffect(isLikeAnimating ? 1.25 : 1.0)

                        Text("\(viewModel.post.post.likeCount)")
                            .font(.subheadline)
                            .foregroundColor(viewModel.post.isLikedByCurrentUser ? AppColors.error : AppColors.textSecondary)

                        Text("likes")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                // Comment count
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "bubble.left")
                        .font(.subheadline)
                    Text("\(viewModel.post.post.commentCount)")
                    Text("comments")
                }
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Section header
            HStack {
                Text("Comments")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                if viewModel.post.post.commentCount > 0 {
                    Text("(\(viewModel.post.post.commentCount))")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)

            // Comments list
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xl)
            } else if viewModel.comments.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bubble.left")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)

                    Text("Be the first to comment")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(
                            comment: comment,
                            canDelete: comment.comment.authorId == viewModel.currentUserId ||
                                       viewModel.post.post.authorId == viewModel.currentUserId,
                            onDelete: {
                                Task {
                                    await viewModel.deleteComment(comment)
                                }
                            }
                        )

                        if comment.id != viewModel.comments.last?.id {
                            Divider()
                                .background(AppColors.surfaceTertiary.opacity(0.3))
                                .padding(.leading, 48)
                        }
                    }
                }
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Text field
            TextField("Add a comment...", text: $commentText)
                .font(.body)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isCommentFieldFocused)

            // Send button
            Button {
                Task {
                    let text = commentText
                    commentText = ""
                    isCommentFieldFocused = false
                    HapticManager.shared.tap()
                    await viewModel.sendComment(text: text)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(commentText.isEmpty ? AppColors.textTertiary : AppColors.dominant)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingComment)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            AppColors.surfacePrimary
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: viewModel.post.post.createdAt)
    }
}

// MARK: - Post Content Card (for detail view)

private struct PostContentCard: View {
    let content: PostContent

    var body: some View {
        Group {
            switch content {
            case .session(_, let workoutName, let date, let snapshot):
                SessionContentCard(workoutName: workoutName, date: date, snapshot: snapshot)

            case .exercise(let snapshot):
                ExerciseContentCard(snapshot: snapshot)

            case .set(let snapshot):
                SetContentCard(snapshot: snapshot)

            case .completedModule(let snapshot):
                ModuleContentCard(snapshot: snapshot)

            case .program(_, let name, let snapshot):
                TemplateContentCard(type: "Program", name: name, icon: "doc.text.fill", color: AppColors.dominant, snapshot: snapshot)

            case .workout(_, let name, let snapshot):
                TemplateContentCard(type: "Workout", name: name, icon: "figure.run", color: AppColors.dominant, snapshot: snapshot)

            case .module(_, let name, let snapshot):
                TemplateContentCard(type: "Module", name: name, icon: "square.stack.3d.up.fill", color: AppColors.accent3, snapshot: snapshot)

            case .text:
                EmptyView()
            }
        }
    }
}

// Placeholder content cards for detail view - reuse patterns from PostCard
private struct SessionContentCard: View {
    let workoutName: String
    let date: Date
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedSession(id: UUID(), workoutName: workoutName, date: date, snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}

private struct ExerciseContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedExercise(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}

private struct SetContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedSet(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}

private struct ModuleContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedCompletedModule(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}

private struct TemplateContentCard: View {
    let type: String
    let name: String
    let icon: String
    let color: Color
    let snapshot: Data

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
            PostAvatarView(
                displayName: comment.author.displayName,
                username: comment.author.username,
                size: 32
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack(spacing: AppSpacing.xs) {
                    Text(comment.author.displayName ?? comment.author.username)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)

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
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24, height: 24)
                        }
                    }
                }

                // Comment text
                Text(comment.comment.text)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(2)
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

    private var relativeTime: String {
        let now = Date()
        let seconds = now.timeIntervalSince(comment.comment.createdAt)

        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h"
        } else if seconds < 604800 {
            let days = Int(seconds / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: comment.comment.createdAt)
        }
    }
}

// MARK: - Preview

#Preview {
    PostDetailView(
        post: PostWithAuthor(
            post: Post(
                authorId: "user1",
                content: .text("Just finished an amazing workout!"),
                caption: "Just finished an amazing workout! Feeling great after crushing my goals today.",
                likeCount: 5,
                commentCount: 2
            ),
            author: UserProfile(id: UUID(), username: "johndoe", displayName: "John Doe"),
            isLikedByCurrentUser: true
        )
    )
}
