//
//  PostCard.swift
//  gym app
//
//  Strava/Twitter-style card for displaying posts in the feed
//

import SwiftUI

struct PostCard: View {
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            PostHeaderView(
                author: post.author,
                createdAt: post.post.createdAt,
                contentType: post.post.content.contentTypeLabel,
                isOwnPost: isOwnPost,
                onProfileTap: onProfileTap,
                onDelete: { showingDeleteConfirmation = true }
            )

            // Caption (above content, Twitter-style)
            if let caption = post.post.caption, !caption.isEmpty {
                Text(caption)
                    .body(color: AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.sm)
            }

            // Content
            PostContentView(content: post.post.content)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Footer with actions
            PostFooterView(
                likeCount: post.post.likeCount,
                commentCount: post.post.commentCount,
                isLiked: post.isLikedByCurrentUser,
                isLikeAnimating: $isLikeAnimating,
                onLike: {
                    withAnimation(AppAnimation.quick) {
                        isLikeAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isLikeAnimating = false
                    }
                    onLike()
                },
                onComment: onComment
            )
        }
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
        )
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
}

// MARK: - Post Header View

private struct PostHeaderView: View {
    let author: UserProfile
    let createdAt: Date
    let contentType: String?
    let isOwnPost: Bool
    let onProfileTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Avatar
            Button(action: onProfileTap) {
                PostAvatarView(
                    displayName: author.displayName,
                    username: author.username,
                    size: 44
                )
            }
            .buttonStyle(.plain)

            // Name, username, and time
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Button(action: onProfileTap) {
                        Text(author.displayName ?? author.username)
                            .headline(color: AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Text("@\(author.username)")
                        .caption(color: AppColors.textTertiary)
                }

                HStack(spacing: AppSpacing.xs) {
                    Text(relativeTime)
                        .caption(color: AppColors.textTertiary)

                    if let type = contentType {
                        Text("·")
                            .caption(color: AppColors.textTertiary)

                        Text(type)
                            .caption(color: AppColors.accent2)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // More menu (for own posts)
            if isOwnPost {
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(AppSpacing.cardPadding)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Post Avatar View

struct PostAvatarView: View {
    let displayName: String?
    let username: String
    let size: CGFloat

    private var initials: String {
        if let displayName = displayName, !displayName.isEmpty {
            let words = displayName.split(separator: " ")
            if words.count >= 2 {
                return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            }
            return String(displayName.prefix(2)).uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(AppColors.accent2.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.accent2)
            }
            .overlay {
                Circle()
                    .stroke(AppColors.accent2.opacity(0.3), lineWidth: 1.5)
            }
    }
}

// MARK: - Post Content View

private struct PostContentView: View {
    let content: PostContent

    var body: some View {
        Group {
            switch content {
            case .text(let text):
                TextPostContent(text: text)

            case .session(_, let workoutName, let date, let snapshot):
                SessionPostContent(workoutName: workoutName, date: date, snapshot: snapshot)

            case .exercise(let snapshot):
                ExercisePostContent(snapshot: snapshot)

            case .set(let snapshot):
                SetPostContent(snapshot: snapshot)

            case .completedModule(let snapshot):
                CompletedModulePostContent(snapshot: snapshot)

            case .program(_, let name, let snapshot):
                ProgramPostContent(name: name, snapshot: snapshot)

            case .workout(_, let name, let snapshot):
                WorkoutPostContent(name: name, snapshot: snapshot)

            case .module(_, let name, let snapshot):
                ModulePostContent(name: name, snapshot: snapshot)
            }
        }
    }
}

// MARK: - Text Post Content

private struct TextPostContent: View {
    let text: String

    var body: some View {
        Text(text)
            .body(color: AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Session Post Content (Strava-style workout completion)

private struct SessionPostContent: View {
    let workoutName: String
    let date: Date
    let snapshot: Data

    private var sessionBundle: SessionShareBundle? {
        try? SessionShareBundle.decode(from: snapshot)
    }

    private var session: Session? {
        sessionBundle?.session
    }

    private var exerciseCount: Int {
        guard let modules = session?.completedModules else { return 0 }
        return modules.reduce(0) { $0 + $1.completedExercises.count }
    }

    private var setCount: Int {
        guard let modules = session?.completedModules else { return 0 }
        var total = 0
        for module in modules {
            for exercise in module.completedExercises {
                for setGroup in exercise.completedSetGroups {
                    total += setGroup.sets.count
                }
            }
        }
        return total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Type badge
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                Text("COMPLETED WORKOUT")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.success)

            // Workout name and duration
            HStack(alignment: .top) {
                Text(workoutName)
                    .displaySmall(color: AppColors.textPrimary)
                    .fontWeight(.bold)

                Spacer()

                if let duration = session?.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(duration) min")
                            .subheadline(color: AppColors.textPrimary)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }

            // Stats boxes
            HStack(spacing: AppSpacing.sm) {
                StatBox(value: "\(exerciseCount)", label: "exercises", color: AppColors.dominant)
                StatBox(value: "\(setCount)", label: "sets", color: AppColors.accent3)
            }

            // Date
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .caption(color: AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.success.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.success.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Exercise Post Content

private struct ExercisePostContent: View {
    let snapshot: Data

    private var bundle: ExerciseShareBundle? {
        try? ExerciseShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Type badge
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.semibold))
                    Text("EXERCISE")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                }
                .foregroundColor(AppColors.dominant)

                // Exercise name
                Text(bundle.exerciseName)
                    .headline(color: AppColors.textPrimary)
                    .fontWeight(.bold)

                // Sets summary
                HStack(spacing: AppSpacing.sm) {
                    StatBox(value: "\(bundle.setData.count)", label: "sets", color: AppColors.dominant)

                    if let bestSet = bundle.setData.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
                       let weight = bestSet.weight {
                        StatBox(value: "\(Int(weight))", label: "lbs max", color: AppColors.accent2)
                    }
                }

                // Date
                Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                    .caption(color: AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.dominant.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(AppColors.dominant.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Set Post Content (PR Celebration)

private struct SetPostContent: View {
    let snapshot: Data

    private var bundle: SetShareBundle? {
        try? SetShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(spacing: AppSpacing.md) {
                // PR badge or regular set
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: bundle.isPR ? "trophy.fill" : "flame.fill")
                        .font(.caption.weight(.semibold))
                    Text(bundle.isPR ? "PERSONAL BEST" : "SET")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                }
                .foregroundColor(bundle.isPR ? AppColors.reward : AppColors.accent2)

                // Big numbers
                VStack(spacing: AppSpacing.xs) {
                    if let weight = bundle.setData.weight, let reps = bundle.setData.reps {
                        HStack(spacing: AppSpacing.sm) {
                            Text("\(Int(weight))")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                            Text("lbs")
                                .headline(color: AppColors.textSecondary)

                            Text("×")
                                .font(.title2)
                                .foregroundColor(AppColors.textTertiary)

                            Text("\(reps)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                            Text("reps")
                                .headline(color: AppColors.textSecondary)
                        }
                        .foregroundColor(bundle.isPR ? AppColors.reward : AppColors.textPrimary)
                    } else if let duration = bundle.setData.duration {
                        let minutes = duration / 60
                        let seconds = duration % 60
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(bundle.isPR ? AppColors.reward : AppColors.textPrimary)
                    }

                    Text(bundle.exerciseName)
                        .headline(color: AppColors.textSecondary)
                }

                // Date
                Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                    .caption(color: AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(bundle.isPR ? AppColors.reward.opacity(0.12) : AppColors.accent2.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(
                        bundle.isPR ? AppColors.reward.opacity(0.4) : AppColors.accent2.opacity(0.2),
                        lineWidth: bundle.isPR ? 1.5 : 1
                    )
            )
        }
    }
}

// MARK: - Program Post Content

private struct ProgramPostContent: View {
    let name: String
    let snapshot: Data

    private var bundle: ProgramShareBundle? {
        try? ProgramShareBundle.decode(from: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Type badge
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "doc.text.fill")
                    .font(.caption.weight(.semibold))
                Text("PROGRAM")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.accent4)

            // Program name
            Text(name)
                .headline(color: AppColors.textPrimary)
                .fontWeight(.bold)

            // Stats
            if let bundle = bundle {
                HStack(spacing: AppSpacing.sm) {
                    StatBox(value: "\(bundle.program.durationWeeks)", label: "weeks", color: AppColors.accent4)
                    StatBox(value: "\(bundle.workouts.count)", label: "workouts", color: AppColors.accent3)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.accent4.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.accent4.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Workout Post Content

private struct WorkoutPostContent: View {
    let name: String
    let snapshot: Data

    private var bundle: WorkoutShareBundle? {
        try? WorkoutShareBundle.decode(from: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Type badge
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "figure.run")
                    .font(.caption.weight(.semibold))
                Text("WORKOUT")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.dominant)

            // Workout name
            Text(name)
                .headline(color: AppColors.textPrimary)
                .fontWeight(.bold)

            // Stats
            if let bundle = bundle {
                let exerciseCount = bundle.modules.reduce(0) { $0 + $1.exercises.count }

                HStack(spacing: AppSpacing.sm) {
                    StatBox(value: "\(bundle.modules.count)", label: "modules", color: AppColors.dominant)
                    StatBox(value: "\(exerciseCount)", label: "exercises", color: AppColors.accent3)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.dominant.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.dominant.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Module Post Content

private struct ModulePostContent: View {
    let name: String
    let snapshot: Data

    private var bundle: ModuleShareBundle? {
        try? ModuleShareBundle.decode(from: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Type badge with module type color
            let moduleColor = bundle?.module.type.color ?? AppColors.accent3

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: bundle?.module.type.icon ?? "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold))
                Text(bundle?.module.type.displayName.uppercased() ?? "MODULE")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(moduleColor)

            // Module name
            Text(name)
                .headline(color: AppColors.textPrimary)
                .fontWeight(.bold)

            // Stats
            if let bundle = bundle {
                HStack(spacing: AppSpacing.sm) {
                    StatBox(value: "\(bundle.module.exercises.count)", label: "exercises", color: moduleColor)

                    if let duration = bundle.module.estimatedDuration {
                        StatBox(value: "\(duration)", label: "min", color: AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill((bundle?.module.type.color ?? AppColors.accent3).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke((bundle?.module.type.color ?? AppColors.accent3).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Completed Module Post Content (from session)

private struct CompletedModulePostContent: View {
    let snapshot: Data

    private var bundle: CompletedModuleShareBundle? {
        try? CompletedModuleShareBundle.decode(from: snapshot)
    }

    private var exerciseCount: Int {
        bundle?.module.completedExercises.count ?? 0
    }

    private var setCount: Int {
        guard let exercises = bundle?.module.completedExercises else { return 0 }
        var total = 0
        for exercise in exercises {
            for setGroup in exercise.completedSetGroups {
                total += setGroup.sets.filter(\.completed).count
            }
        }
        return total
    }

    var body: some View {
        if let bundle = bundle {
            let moduleColor = AppColors.moduleColor(bundle.module.moduleType)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Type badge
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: bundle.module.moduleType.icon)
                        .font(.caption.weight(.semibold))
                    Text("COMPLETED \(bundle.module.moduleType.displayName.uppercased())")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                }
                .foregroundColor(moduleColor)

                // Module name
                Text(bundle.module.moduleName)
                    .headline(color: AppColors.textPrimary)
                    .fontWeight(.bold)

                // Stats
                HStack(spacing: AppSpacing.sm) {
                    StatBox(value: "\(exerciseCount)", label: "exercises", color: moduleColor)
                    StatBox(value: "\(setCount)", label: "sets", color: AppColors.accent3)
                }

                // Date and workout context
                VStack(alignment: .leading, spacing: 2) {
                    Text(bundle.workoutName)
                        .caption(color: AppColors.textSecondary)
                    Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                        .caption(color: AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(moduleColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(moduleColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Stat Box Component

private struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
        }
        .frame(minWidth: 60)
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Post Footer View

private struct PostFooterView: View {
    let likeCount: Int
    let commentCount: Int
    let isLiked: Bool
    @Binding var isLikeAnimating: Bool
    let onLike: () -> Void
    let onComment: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Action buttons
            HStack(spacing: AppSpacing.xl) {
                // Like button
                Button(action: onLike) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.body.weight(.medium))
                            .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                            .scaleEffect(isLikeAnimating ? 1.3 : 1.0)

                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .subheadline(color: isLiked ? AppColors.error : AppColors.textSecondary)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                // Comment button
                Button(action: onComment) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "bubble.right")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        if commentCount > 0 {
                            Text("\(commentCount)")
                                .subheadline(color: AppColors.textSecondary)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                // Share button
                Button {
                    // Share action - can be implemented later
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
    }
}

// MARK: - Post Content Extensions

extension PostContent {
    var contentTypeLabel: String? {
        switch self {
        case .session: return "Workout"
        case .exercise: return "Exercise"
        case .set(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot), bundle.isPR {
                return "PR"
            }
            return "Set"
        case .completedModule: return "Module"
        case .program: return "Program"
        case .workout: return "Template"
        case .module: return "Module"
        case .text: return nil
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            // Text post
            PostCard(
                post: PostWithAuthor(
                    post: Post(
                        authorId: "user1",
                        content: .text("Just finished an amazing leg day! Feeling the burn but so worth it. Time to recover and grow! 💪"),
                        caption: nil,
                        likeCount: 12,
                        commentCount: 3
                    ),
                    author: UserProfile(id: UUID(), username: "johndoe", displayName: "John Doe"),
                    isLikedByCurrentUser: true
                ),
                onLike: {},
                onComment: {},
                onDelete: {},
                onProfileTap: {}
            )

            // Session post (would need real snapshot data)
            PostCard(
                post: PostWithAuthor(
                    post: Post(
                        authorId: "user2",
                        content: .text("Crushed my push workout today!"),
                        caption: "New PR on bench press!",
                        likeCount: 24,
                        commentCount: 5
                    ),
                    author: UserProfile(id: UUID(), username: "janedoe", displayName: "Jane Doe"),
                    isLikedByCurrentUser: false
                ),
                onLike: {},
                onComment: {},
                onDelete: nil,
                onProfileTap: {}
            )
        }
        .padding()
    }
    .background(AppColors.background)
}
