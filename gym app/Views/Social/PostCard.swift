//
//  PostCard.swift
//  gym app
//
//  Strava/Twitter-style card for displaying posts in the feed
//  Visual hierarchy: Data is the hero, breathing room, native iOS feel
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
    @State private var isCaptionExpanded = false

    private var isOwnPost: Bool {
        onDelete != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author row
            authorRow

            // Caption (above content, Twitter-style)
            if let caption = post.post.caption, !caption.isEmpty {
                captionView(caption)
            }

            // Hero content - the attachment card
            PostContentView(content: post.post.content)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.md)

            // Engagement bar
            engagementBar
        }
        .padding(.top, AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
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

    // MARK: - Author Row

    private var authorRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Gradient avatar
            Button(action: onProfileTap) {
                PostAvatarView(
                    displayName: post.author.displayName,
                    username: post.author.username,
                    size: 40
                )
            }
            .buttonStyle(.plain)

            // Name, username, time stack
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Button(action: onProfileTap) {
                        Text(post.author.displayName ?? post.author.username)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Text(relativeTime)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Text("@\(post.author.username)")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

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
                        .font(.subheadline)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - Caption View

    private func captionView(_ caption: String) -> some View {
        let shouldTruncate = caption.count > 280 && !isCaptionExpanded

        return VStack(alignment: .leading, spacing: 0) {
            if shouldTruncate {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(String(caption.prefix(280)))
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)
                    + Text("...")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCaptionExpanded = true
                        }
                    } label: {
                        Text("more")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.dominant)
                    }
                }
            } else {
                Text(caption)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .lineSpacing(4)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: - Engagement Bar

    private var engagementBar: some View {
        VStack(spacing: 0) {
            // Subtle divider
            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.3))
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Action buttons
            HStack(spacing: AppSpacing.xl) {
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
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.body.weight(.medium))
                            .foregroundColor(post.isLikedByCurrentUser ? AppColors.error : AppColors.textSecondary)
                            .scaleEffect(isLikeAnimating ? 1.25 : 1.0)

                        if post.post.likeCount > 0 {
                            Text("\(post.post.likeCount)")
                                .font(.caption)
                                .foregroundColor(post.isLikedByCurrentUser ? AppColors.error : AppColors.textSecondary)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                // Comment button
                Button(action: onComment) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "bubble.left")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)

                        if post.post.commentCount > 0 {
                            Text("\(post.post.commentCount)")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                // Share button (right-aligned)
                Button {
                    // Share action
                } label: {
                    Image(systemName: "paperplane")
                        .font(.body.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Relative Time

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
            // More than a week, show date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: post.post.createdAt)
        }
    }
}

// MARK: - Post Avatar View

struct PostAvatarView: View {
    let displayName: String?
    let username: String
    let size: CGFloat

    private var initial: String {
        if let displayName = displayName, !displayName.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return String(username.prefix(1)).uppercased()
    }

    /// Generate a consistent color from username hash
    private var avatarColor: Color {
        let hash = abs(username.hashValue)
        let colors: [Color] = [
            AppColors.dominant,
            AppColors.accent1,
            AppColors.accent2,
            AppColors.accent3,
            AppColors.accent4,
            AppColors.success
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatarColor, avatarColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Initial letter
            Text(initial)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(avatarColor.opacity(0.3), lineWidth: 1.5)
        )
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
        // For text-only posts, the text is already shown in caption
        // This case shouldn't be hit if caption is used properly
        EmptyView()
    }
}

// MARK: - Session Post Content (Completed Workout)

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

    private var totalSets: Int {
        guard let modules = session?.completedModules else { return 0 }
        var total = 0
        for module in modules {
            for exercise in module.completedExercises {
                for setGroup in exercise.completedSetGroups {
                    total += setGroup.sets.filter(\.completed).count
                }
            }
        }
        return total
    }

    private var totalExercises: Int {
        guard let modules = session?.completedModules else { return 0 }
        return modules.reduce(0) { $0 + $1.completedExercises.count }
    }

    private var totalVolume: Double {
        guard let modules = session?.completedModules else { return 0 }
        return modules.reduce(0) { moduleTotal, module in
            moduleTotal + module.completedExercises.reduce(0) { $0 + $1.totalVolume }
        }
    }

    private var duration: Int? {
        session?.duration
    }

    /// Get top 3 strength exercises by weight
    private var topLifts: [(name: String, weight: Double, reps: Int)] {
        guard let modules = session?.completedModules else { return [] }
        var lifts: [(name: String, weight: Double, reps: Int)] = []

        for module in modules where !module.skipped {
            for exercise in module.completedExercises {
                guard exercise.exerciseType == .strength,
                      let topSet = exercise.topSet,
                      let weight = topSet.weight, weight > 0,
                      let reps = topSet.reps, reps > 0 else { continue }
                lifts.append((exercise.exerciseName, weight, reps))
            }
        }

        return Array(lifts.sorted { $0.weight > $1.weight }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header: Success checkmark + workout name
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName.uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xs) {
                        if let duration = duration {
                            Text("\(duration) min")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        if duration != nil {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer()
            }

            // Stats grid - reusing WorkoutSummaryView pattern
            HStack(spacing: AppSpacing.sm) {
                PostStatCard(value: "\(totalSets)", label: "SETS", color: AppColors.dominant)
                PostStatCard(value: "\(totalExercises)", label: "EXERCISES", color: AppColors.accent1)
                PostStatCard(value: formatVolume(totalVolume), label: "VOLUME", color: AppColors.accent3)
            }

            // Top Lifts section
            if !topLifts.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("TOP LIFTS")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundColor(AppColors.textTertiary)

                    ForEach(topLifts.indices, id: \.self) { index in
                        let lift = topLifts[index]
                        HStack {
                            Text(lift.name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            HStack(spacing: AppSpacing.xs) {
                                Text(formatWeight(lift.weight))
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)

                                Text("×")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)

                                Text("\(lift.reps)")
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.success.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.success.opacity(0.15), lineWidth: 1)
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
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "dumbbell.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.dominant)

                    Text(bundle.exerciseName.uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()
                }

                // Context
                HStack(spacing: AppSpacing.xs) {
                    Text("from \(bundle.workoutName)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text("·")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)

                    Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                // All sets
                VStack(spacing: AppSpacing.xs) {
                    ForEach(bundle.setData.indices, id: \.self) { index in
                        let set = bundle.setData[index]
                        let isTopSet = isTopSet(set, in: bundle.setData)

                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 50, alignment: .leading)

                            Spacer()

                            if let weight = set.weight, let reps = set.reps {
                                HStack(spacing: AppSpacing.xs) {
                                    Text(formatWeight(weight))
                                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                    Text("×")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                    Text("\(reps)")
                                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                }
                                .foregroundColor(isTopSet ? AppColors.dominant : AppColors.textPrimary)
                            } else if let duration = set.duration {
                                Text(formatDuration(duration))
                                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                    .foregroundColor(isTopSet ? AppColors.dominant : AppColors.textPrimary)
                            }

                            if isTopSet {
                                Text("Top Set")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(AppColors.dominant)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.dominant.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.dominant.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(AppColors.dominant.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func isTopSet(_ set: SetData, in sets: [SetData]) -> Bool {
        guard let weight = set.weight else { return false }
        let maxWeight = sets.compactMap(\.weight).max() ?? 0
        return weight == maxWeight && weight > 0
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

                // Exercise name (caption, centered)
                Text(bundle.exerciseName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textSecondary)

                // HUGE numbers
                if let weight = bundle.setData.weight, let reps = bundle.setData.reps {
                    HStack(spacing: AppSpacing.sm) {
                        Text("\(Int(weight))")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(bundle.isPR ? AppColors.warning : AppColors.textPrimary)

                        Text("×")
                            .font(.title)
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(reps)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(bundle.isPR ? AppColors.warning : AppColors.textPrimary)
                    }

                    Text("lbs")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                        .textCase(.uppercase)

                } else if let duration = bundle.setData.duration {
                    let minutes = duration / 60
                    let seconds = duration % 60
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(bundle.isPR ? AppColors.warning : AppColors.textPrimary)
                }

                // Context
                HStack(spacing: AppSpacing.xs) {
                    if let workoutName = bundle.workoutName {
                        Text(workoutName)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

                        Text("·")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
            .padding(.horizontal, AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(bundle.isPR ? AppColors.warning.opacity(0.08) : AppColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(
                        bundle.isPR ? AppColors.warning.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.3),
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
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            // Meta info
            if let bundle = bundle {
                HStack(spacing: AppSpacing.md) {
                    Label("\(bundle.program.durationWeeks) weeks", systemImage: "calendar")
                    Label("\(bundle.workouts.count) workouts", systemImage: "figure.run")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.accent4.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.accent4.opacity(0.15), lineWidth: 1)
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
                Text("WORKOUT TEMPLATE")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.dominant)

            // Workout name
            Text(name)
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            // Meta info
            if let bundle = bundle {
                let exerciseCount = bundle.modules.reduce(0) { $0 + $1.exercises.count }

                HStack(spacing: AppSpacing.md) {
                    Label("\(bundle.modules.count) modules", systemImage: "square.stack.3d.up.fill")
                    Label("\(exerciseCount) exercises", systemImage: "dumbbell.fill")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.dominant.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(AppColors.dominant.opacity(0.15), lineWidth: 1)
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
        let moduleColor = bundle?.module.type.color ?? AppColors.accent3

        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Type badge
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: bundle?.module.type.icon ?? "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold))
                Text((bundle?.module.type.displayName ?? "MODULE").uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(moduleColor)

            // Module name
            Text(name)
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            // Meta info
            if let bundle = bundle {
                HStack(spacing: AppSpacing.md) {
                    Label("\(bundle.module.exercises.count) exercises", systemImage: "dumbbell.fill")
                    if let duration = bundle.module.estimatedDuration {
                        Label("\(duration) min", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(moduleColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(moduleColor.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Completed Module Post Content

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
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.success)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: bundle.module.moduleType.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(moduleColor)

                            Text(bundle.module.moduleName.uppercased())
                                .font(.headline.weight(.bold))
                                .foregroundColor(AppColors.textPrimary)
                        }

                        HStack(spacing: AppSpacing.xs) {
                            Text("from \(bundle.workoutName)")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)

                            Text("·")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)

                            Text(bundle.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()
                }

                // Stats
                HStack(spacing: AppSpacing.sm) {
                    PostStatCard(value: "\(exerciseCount)", label: "EXERCISES", color: moduleColor)
                    PostStatCard(value: "\(setCount)", label: "SETS", color: AppColors.accent3)
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(moduleColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(moduleColor.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Post Stat Card Component

private struct PostStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
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
        VStack(spacing: AppSpacing.xl) {
            // Text post
            PostCard(
                post: PostWithAuthor(
                    post: Post(
                        authorId: "user1",
                        content: .text("Just finished an amazing leg day! Feeling the burn but so worth it. Time to recover and grow!"),
                        caption: "Just finished an amazing leg day! Feeling the burn but so worth it. Time to recover and grow!",
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

            // Another post
            PostCard(
                post: PostWithAuthor(
                    post: Post(
                        authorId: "user2",
                        content: .text("Crushed my push workout today!"),
                        caption: "New PR on bench press! Finally hit that goal I've been chasing for months.",
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
        .padding(AppSpacing.md)
    }
    .background(AppColors.background)
}
