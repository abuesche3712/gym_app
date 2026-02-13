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
    @State private var editingComment: CommentWithAuthor?
    @State private var editCommentText = ""
    @State private var isLikeAnimating = false
    @State private var previewingContent: MessageContent?
    @State private var showingShareSheet = false
    @State private var replyingTo: CommentWithAuthor?
    @State private var showReactionPicker = false

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
                .refreshable { viewModel.loadComments(resetPagination: true) }
                .scrollDismissesKeyboard(.interactively)

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
                viewModel.loadComments(resetPagination: true)
            }
            .alert("Edit Comment", isPresented: Binding(
                get: { editingComment != nil },
                set: { if !$0 { editingComment = nil } }
            )) {
                TextField("Comment", text: $editCommentText)
                Button("Save") {
                    if let comment = editingComment {
                        let newText = editCommentText
                        Task {
                            await viewModel.updateComment(comment, newText: newText)
                        }
                    }
                    editingComment = nil
                }
                Button("Cancel", role: .cancel) {
                    editingComment = nil
                }
            } message: {
                Text("Edit your comment")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareWithFriendSheet(
                    content: ShareablePostContent(post: viewModel.post.post)
                ) { conversationWithProfile in
                    let chatViewModel = ChatViewModel(
                        conversation: conversationWithProfile.conversation,
                        otherParticipant: conversationWithProfile.otherParticipant,
                        otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                    )
                    let messageContent = viewModel.post.post.content.toMessageContent()
                    try await chatViewModel.sendSharedContent(messageContent)
                }
            }
            .sheet(item: $previewingContent) { content in
                SharedContentPreviewSheet(
                    content: content,
                    onImport: nil  // Posts are view-only from preview
                )
            }
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author row
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                ProfilePhotoView(
                    profile: viewModel.post.author,
                    size: 44,
                    borderWidth: 0
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
                RichTextView(caption)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.md)
            }

            // Content (if not text-only)
            if case .text = viewModel.post.post.content {
                // Text-only post, caption is the content
            } else {
                PostContentCard(
                    content: viewModel.post.post.content,
                    onTap: viewModel.post.post.content.toMessageContent().isViewable ? {
                        previewingContent = viewModel.post.post.content.toMessageContent()
                    } : nil
                )
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.md)
            }

            // Reaction summary (excluding heart, which is shown by the like button)
            if let counts = viewModel.post.post.reactionCounts?.filter({ $0.key != ReactionType.heart.rawValue && $0.value > 0 }), !counts.isEmpty {
                let sorted = counts.sorted { $0.value > $1.value }
                HStack(spacing: 4) {
                    ForEach(sorted.prefix(5), id: \.key) { key, count in
                        if let reaction = ReactionType(rawValue: key), count > 0 {
                            HStack(spacing: 2) {
                                Text(reaction.emoji)
                                    .font(.caption)
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
            }

            // Engagement stats
            HStack(spacing: AppSpacing.lg) {
                // Like button (tap = heart, long-press = reaction picker)
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
                .onLongPressGesture(minimumDuration: 0.3) {
                    HapticManager.shared.impact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showReactionPicker = true
                    }
                }

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

                // Share button
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "paperplane")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.cardPadding)
            .overlay(alignment: .topLeading) {
                if showReactionPicker {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(ReactionType.allCases, id: \.self) { reaction in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showReactionPicker = false
                                }
                                Task {
                                    await viewModel.react(with: reaction)
                                }
                            } label: {
                                Text(reaction.emoji)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(AppColors.surfacePrimary)
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                    )
                    .offset(y: -44)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .padding(.leading, AppSpacing.cardPadding)
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
                VStack(spacing: AppSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(
                                comment: comment,
                                canDelete: comment.comment.authorId == viewModel.currentUserId ||
                                           viewModel.post.post.authorId == viewModel.currentUserId,
                                canEdit: comment.comment.authorId == viewModel.currentUserId,
                                onDelete: {
                                    Task {
                                        await viewModel.deleteComment(comment)
                                    }
                                },
                                onEdit: comment.comment.authorId == viewModel.currentUserId ? {
                                    editingComment = comment
                                    editCommentText = comment.comment.text
                                } : nil,
                                onReply: {
                                    replyingTo = comment
                                    isCommentFieldFocused = true
                                }
                            )

                            // Show replies for this comment
                            if let commentReplies = viewModel.replies[comment.comment.id], !commentReplies.isEmpty {
                                ForEach(commentReplies) { reply in
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(AppColors.surfaceTertiary.opacity(0.3))
                                            .frame(width: 2)
                                            .padding(.leading, 28)

                                        CommentRow(
                                            comment: reply,
                                            canDelete: reply.comment.authorId == viewModel.currentUserId ||
                                                       viewModel.post.post.authorId == viewModel.currentUserId,
                                            canEdit: reply.comment.authorId == viewModel.currentUserId,
                                            onDelete: {
                                                Task {
                                                    await viewModel.deleteComment(reply)
                                                }
                                            },
                                            onEdit: reply.comment.authorId == viewModel.currentUserId ? {
                                                editingComment = reply
                                                editCommentText = reply.comment.text
                                            } : nil
                                        )
                                    }
                                }
                            }

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

                    if viewModel.hasMoreComments {
                        Button {
                            viewModel.loadMoreComments()
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                if viewModel.isLoadingMoreComments {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                Text(viewModel.isLoadingMoreComments ? "Loading..." : "Load more comments")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppColors.dominant)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .stroke(AppColors.surfaceTertiary.opacity(0.4), lineWidth: 1)
                            )
                            .padding(.horizontal, AppSpacing.md)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoadingMoreComments)
                    }
                }
            }
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            // Reply indicator
            if let replyTarget = replyingTo {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.dominant)

                    Text("Replying to @\(replyTarget.author.username)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Button {
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.surfaceSecondary)
            }

            HStack(spacing: AppSpacing.sm) {
                // Text field
                TextField(replyingTo != nil ? "Write a reply..." : "Add a comment...", text: $commentText)
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
                        let replyTarget = replyingTo
                        commentText = ""
                        replyingTo = nil
                        isCommentFieldFocused = false
                        HapticManager.shared.tap()
                        if let replyTarget = replyTarget {
                            await viewModel.sendReply(to: replyTarget, text: text)
                        } else {
                            await viewModel.sendComment(text: text)
                        }
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
        }
        .background(
            AppColors.surfacePrimary
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Helpers

    private var formattedDate: String {
        DateFormatters.mediumDateTime.string(from: viewModel.post.post.createdAt)
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
