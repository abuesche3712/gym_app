//
//  FeedPostRow.swift
//  gym app
//
//  Twitter-style flat post row for the feed
//  Flat layout with dividers, avatar on left, single elevated attachment
//

import SwiftUI

struct FeedPostRow: View {
    let post: PostWithAuthor
    let onLike: () -> Void
    let onComment: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onProfileTap: () -> Void
    var onShare: (() -> Void)? = nil
    var onPostTap: (() -> Void)? = nil
    var onReact: ((ReactionType) -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onHideAuthor: (() -> Void)? = nil

    @State private var showingDeleteConfirmation = false
    @State private var isLikeAnimating = false
    @State private var showReactionPicker = false

    private var isOwnPost: Bool {
        onDelete != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Top row: Avatar + Author info
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Button(action: onProfileTap) {
                    ProfilePhotoView(
                        profile: post.author,
                        size: 40,
                        borderWidth: 0
                    )
                }
                .buttonStyle(.plain)

                // Author line
                authorLine
            }

            // Tappable content area (caption + attachment)
            Button {
                onPostTap?()
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    // Caption (if any) - left aligned, full width
                    if let caption = post.post.caption, !caption.isEmpty {
                        RichTextView(caption)
                    }

                    // Attachment card (centered on full width)
                    attachmentContent
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
            .disabled(onPostTap == nil)

            // Engagement bar (centered, spans full width)
            engagementBar
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.background)
        .overlay {
            // Tap-to-dismiss overlay for reaction picker (bounded to row, not 2000x2000)
            if showReactionPicker {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            showReactionPicker = false
                        }
                    }
            }
        }
        .confirmationDialog(
            "Delete Post?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this post.")
        }
    }

    // MARK: - Author Line

    private var authorLine: some View {
        HStack(spacing: AppSpacing.xs) {
            Button(action: onProfileTap) {
                Text(post.author.displayName ?? post.author.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            .buttonStyle(.plain)

            Text("@\(post.author.username)")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            Text("·")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            Text(relativeTime)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            Spacer()

            // More menu
            if isOwnPost || onReport != nil || onHideAuthor != nil {
                Menu {
                    if let onEdit = onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    if isOwnPost {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if !isOwnPost, let onReport = onReport {
                        Button {
                            onReport()
                        } label: {
                            Label("Report", systemImage: "flag")
                        }
                    }

                    if !isOwnPost, let onHideAuthor = onHideAuthor {
                        Button {
                            onHideAuthor()
                        } label: {
                            Label("Hide @\(post.author.username)", systemImage: "eye.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Attachment Content

    @ViewBuilder
    private var attachmentContent: some View {
        Group {
            switch post.post.content {
            case .session(_, let workoutName, let date, let snapshot):
                // Use SessionPostContent which supports user-selected highlights
                SessionPostContent(workoutName: workoutName, date: date, snapshot: snapshot)

            case .text:
                // Text-only posts have no attachment (caption is the content)
                EmptyView()

            case .exercise(let snapshot):
                ExerciseAttachmentCard(snapshot: snapshot)

            case .set(let snapshot):
                SetAttachmentCard(snapshot: snapshot)

            case .completedModule(let snapshot):
                ModuleAttachmentCard(snapshot: snapshot)

            case .program(_, let name, let snapshot):
                TemplateAttachmentCard(type: "PROGRAM", name: name, snapshot: snapshot)

            case .workout(_, let name, let snapshot):
                TemplateAttachmentCard(type: "WORKOUT", name: name, snapshot: snapshot)

            case .module(_, let name, let snapshot):
                TemplateAttachmentCard(type: "MODULE", name: name, snapshot: snapshot)

            case .highlights(let snapshot):
                HighlightsInlineCards(snapshot: snapshot)
            }
        }
    }

    // MARK: - Engagement Bar

    private var engagementBar: some View {
        VStack(spacing: AppSpacing.xs) {
            // Reaction summary (shows emoji counts, excluding heart which is shown by the like button)
            if let counts = post.post.reactionCounts?.filter({ $0.key != ReactionType.heart.rawValue && $0.value > 0 }), !counts.isEmpty {
                reactionSummary(counts)
            }

            HStack(spacing: 0) {
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
                    onLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(post.isLikedByCurrentUser ? AppColors.error : AppColors.textTertiary)
                            .scaleEffect(isLikeAnimating ? 1.25 : 1.0)

                        if post.post.likeCount > 0 {
                            Text("\(post.post.likeCount)")
                                .font(.caption)
                                .foregroundColor(post.isLikedByCurrentUser ? AppColors.error : AppColors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .onLongPressGesture(minimumDuration: 0.3) {
                    HapticManager.shared.impact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showReactionPicker = true
                    }
                }

                // Comment button
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textTertiary)

                        if post.post.commentCount > 0 {
                            Text("\(post.post.commentCount)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Share/DM button
                Button {
                    onShare?()
                } label: {
                    Image(systemName: "paperplane")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, AppSpacing.sm)
        .overlay(alignment: .topLeading) {
            if showReactionPicker {
                reactionPickerView
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }

    private var reactionPickerView: some View {
        HStack(spacing: AppSpacing.md) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showReactionPicker = false
                    }
                    onReact?(reaction)
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
    }

    private func reactionSummary(_ counts: [String: Int]) -> some View {
        HStack(spacing: 4) {
            // Show emojis with counts, sorted by count descending
            let sorted = counts.sorted { $0.value > $1.value }
            ForEach(sorted.prefix(3), id: \.key) { key, count in
                if let reaction = ReactionType(rawValue: key), count > 0 {
                    HStack(spacing: 2) {
                        Text(reaction.emoji)
                            .font(.caption2)
                        if count > 1 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var relativeTime: String { formatRelativeTimeShort(post.post.createdAt) }

    private func decodeSession(from snapshot: Data) -> Session? {
        guard let bundle = try? SessionShareBundle.decode(from: snapshot) else { return nil }
        return bundle.session
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)

            FeedPostRow(
                post: PostWithAuthor(
                    post: Post(
                        authorId: "user1",
                        content: .text("Great workout today!"),
                        caption: "Crushed my leg day! Feeling strong and ready for more.",
                        likeCount: 12,
                        commentCount: 3
                    ),
                    author: UserProfile(id: UUID(), username: "fitguy", displayName: "Fit Guy"),
                    isLikedByCurrentUser: true
                ),
                onLike: {},
                onComment: {},
                onEdit: {},
                onDelete: {},
                onProfileTap: {}
            )

            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)
        }
    }
    .background(AppColors.background)
}
