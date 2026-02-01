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
    let onDelete: (() -> Void)?
    let onProfileTap: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var isLikeAnimating = false

    private var isOwnPost: Bool {
        onDelete != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Top row: Avatar + Author info
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Button(action: onProfileTap) {
                    PostAvatarView(
                        displayName: post.author.displayName,
                        username: post.author.username,
                        size: 40
                    )
                }
                .buttonStyle(.plain)

                // Author line
                authorLine
            }

            // Caption (if any) - left aligned, full width
            if let caption = post.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Attachment card (centered on full width)
            attachmentContent
                .frame(maxWidth: .infinity)

            // Engagement bar (centered, spans full width)
            engagementBar
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.background)
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

            // More menu (for own posts)
            if isOwnPost {
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
            case .session(_, _, _, let snapshot):
                // Use WorkoutAttachmentCard for sessions
                if let session = decodeSession(from: snapshot) {
                    WorkoutAttachmentCard(session: session)
                }

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
            }
        }
    }

    // MARK: - Engagement Bar

    private var engagementBar: some View {
        HStack(spacing: 0) {
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
                // Share action
            } label: {
                Image(systemName: "paperplane")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Helpers

    private var relativeTime: String {
        let now = Date()
        let seconds = now.timeIntervalSince(post.post.createdAt)

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
            return formatter.string(from: post.post.createdAt)
        }
    }

    private func decodeSession(from snapshot: Data) -> Session? {
        guard let bundle = try? SessionShareBundle.decode(from: snapshot) else { return nil }
        return bundle.session
    }
}

// MARK: - Exercise Attachment Card

private struct ExerciseAttachmentCard: View {
    let snapshot: Data

    private var bundle: ExerciseShareBundle? {
        try? ExerciseShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "dumbbell.fill")
                        .font(.subheadline)
                        .foregroundColor(AppColors.dominant)

                    Text(bundle.exerciseName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                }

                // Sets summary
                let completedSets = bundle.setData.filter { $0.weight != nil || $0.duration != nil }
                if let topSet = completedSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
                   let weight = topSet.weight, let reps = topSet.reps {
                    HStack(spacing: AppSpacing.xs) {
                        Text("\(completedSets.count) sets")
                            .caption(color: AppColors.textSecondary)
                        Text("·")
                            .caption(color: AppColors.textTertiary)
                        Text("Top: \(formatWeight(weight)) × \(reps)")
                            .caption(color: AppColors.dominant)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Set Attachment Card (PR Celebration)

private struct SetAttachmentCard: View {
    let snapshot: Data

    private var bundle: SetShareBundle? {
        try? SetShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(spacing: AppSpacing.md) {
                // PR Badge
                if bundle.isPR {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.caption.weight(.bold))
                        Text("NEW PR")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                    }
                    .foregroundColor(AppColors.warning)
                }

                // Exercise name
                Text(bundle.exerciseName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textSecondary)

                // Big numbers
                if let weight = bundle.setData.weight, let reps = bundle.setData.reps {
                    HStack(spacing: AppSpacing.sm) {
                        Text("\(Int(weight))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(bundle.isPR ? AppColors.warning : AppColors.textPrimary)

                        Text("×")
                            .font(.title2)
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(reps)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(bundle.isPR ? AppColors.warning : AppColors.textPrimary)
                    }

                    Text("lbs")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .padding(.horizontal, AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(bundle.isPR ? AppColors.warning.opacity(0.08) : AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        bundle.isPR ? AppColors.warning.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.5),
                        lineWidth: bundle.isPR ? 1.5 : 1
                    )
            )
        }
    }
}

// MARK: - Module Attachment Card

private struct ModuleAttachmentCard: View {
    let snapshot: Data

    private var bundle: CompletedModuleShareBundle? {
        try? CompletedModuleShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            let moduleColor = AppColors.moduleColor(bundle.module.moduleType)
            let exerciseCount = bundle.module.completedExercises.count
            let setCount = bundle.module.completedExercises.reduce(0) { total, exercise in
                total + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(AppColors.success)

                    Image(systemName: bundle.module.moduleType.icon)
                        .font(.caption)
                        .foregroundColor(moduleColor)

                    Text(bundle.module.moduleName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                }

                HStack(spacing: AppSpacing.md) {
                    Label("\(exerciseCount) exercises", systemImage: "dumbbell.fill")
                    Label("\(setCount) sets", systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Template Attachment Card (Programs, Workouts, Modules)

private struct TemplateAttachmentCard: View {
    let type: String
    let name: String
    let snapshot: Data

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: iconForType)
                    .font(.caption.weight(.semibold))
                Text(type)
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.dominant)

            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
        )
    }

    private var iconForType: String {
        switch type {
        case "PROGRAM": return "doc.text.fill"
        case "WORKOUT": return "figure.run"
        default: return "square.stack.3d.up.fill"
        }
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
