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

    // Detect exercise type from set data
    private enum DetectedType {
        case strength
        case cardio
        case isometric
        case band
        case unknown
    }

    private func detectType(from sets: [SetData]) -> DetectedType {
        let firstCompleted = sets.first { $0.completed }
        guard let set = firstCompleted else { return .unknown }

        if let holdTime = set.holdTime, holdTime > 0 {
            return .isometric
        } else if (set.duration != nil && set.duration! > 0) || (set.distance != nil && set.distance! > 0) {
            // Check if it looks like cardio (no reps, just time/distance)
            if set.reps == nil || set.reps == 0 {
                return .cardio
            }
        }
        if let bandColor = set.bandColor, !bandColor.isEmpty {
            return .band
        }
        if set.weight != nil || set.reps != nil {
            return .strength
        }
        return .unknown
    }

    var body: some View {
        if let bundle = bundle {
            let completedSets = bundle.setData.filter { $0.completed }
            let detectedType = detectType(from: completedSets)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: iconForType(detectedType))
                        .font(.subheadline)
                        .foregroundColor(colorForType(detectedType))

                    Text(bundle.exerciseName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                }

                // Sets summary based on type
                exerciseSummary(completedSets: completedSets, type: detectedType)
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

    @ViewBuilder
    private func exerciseSummary(completedSets: [SetData], type: DetectedType) -> some View {
        switch type {
        case .strength:
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

        case .cardio:
            let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
            let totalDistance = completedSets.compactMap { $0.distance }.reduce(0, +)
            HStack(spacing: AppSpacing.xs) {
                Text("\(completedSets.count) sets")
                    .caption(color: AppColors.textSecondary)
                if totalDuration > 0 {
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text(formatDurationSeconds(totalDuration))
                        .caption(color: AppColors.accent3)
                }
                if totalDistance > 0 {
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text(formatDistance(totalDistance))
                        .caption(color: AppColors.accent1)
                }
            }

        case .isometric:
            let totalHoldTime = completedSets.compactMap { $0.holdTime }.reduce(0, +)
            HStack(spacing: AppSpacing.xs) {
                Text("\(completedSets.count) sets")
                    .caption(color: AppColors.textSecondary)
                Text("·")
                    .caption(color: AppColors.textTertiary)
                Text("Total: \(formatDurationSeconds(totalHoldTime))")
                    .caption(color: AppColors.accent2)
            }

        case .band:
            if let topSet = completedSets.first, let bandColor = topSet.bandColor, let reps = topSet.reps {
                HStack(spacing: AppSpacing.xs) {
                    Text("\(completedSets.count) sets")
                        .caption(color: AppColors.textSecondary)
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text("\(bandColor) × \(reps)")
                        .caption(color: AppColors.accent3)
                }
            }

        case .unknown:
            Text("\(completedSets.count) sets")
                .caption(color: AppColors.textSecondary)
        }
    }

    private func iconForType(_ type: DetectedType) -> String {
        switch type {
        case .strength, .band: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .isometric: return "timer"
        case .unknown: return "dumbbell.fill"
        }
    }

    private func colorForType(_ type: DetectedType) -> Color {
        switch type {
        case .strength: return AppColors.dominant
        case .cardio: return AppColors.accent1
        case .isometric: return AppColors.accent2
        case .band: return AppColors.accent3
        case .unknown: return AppColors.dominant
        }
    }

    private func formatDurationSeconds(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)h \(mins)m"
        } else if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(mins)m \(secs)s"
            }
            return "\(mins)m"
        } else {
            return "\(seconds)s"
        }
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(distance)) mi"
        }
        return String(format: "%.1f mi", distance)
    }
}

// MARK: - Set Attachment Card (PR Celebration)

private struct SetAttachmentCard: View {
    let snapshot: Data

    private var bundle: SetShareBundle? {
        try? SetShareBundle.decode(from: snapshot)
    }

    // Detect set type from data
    private enum DetectedType {
        case strength
        case cardio
        case isometric
        case band
    }

    private func detectType(from set: SetData) -> DetectedType {
        if let holdTime = set.holdTime, holdTime > 0 {
            return .isometric
        }
        if let bandColor = set.bandColor, !bandColor.isEmpty {
            return .band
        }
        if (set.duration != nil && set.duration! > 0) || (set.distance != nil && set.distance! > 0) {
            if set.reps == nil || set.reps == 0 {
                return .cardio
            }
        }
        return .strength
    }

    var body: some View {
        if let bundle = bundle {
            let detectedType = detectType(from: bundle.setData)

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

                // Display based on type
                setDisplay(set: bundle.setData, type: detectedType, isPR: bundle.isPR)
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

    @ViewBuilder
    private func setDisplay(set: SetData, type: DetectedType, isPR: Bool) -> some View {
        switch type {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                HStack(spacing: AppSpacing.sm) {
                    Text("\(Int(weight))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)

                    Text("×")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)

                    Text("\(reps)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)
                }

                Text("lbs")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }

        case .cardio:
            HStack(spacing: AppSpacing.lg) {
                if let duration = set.duration, duration > 0 {
                    VStack(spacing: 4) {
                        Text(formatDurationSeconds(duration))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent3)
                        Text("time")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                if let distance = set.distance, distance > 0 {
                    VStack(spacing: 4) {
                        Text(formatDistanceValue(distance))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent1)
                        Text("mi")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

        case .isometric:
            if let holdTime = set.holdTime {
                VStack(spacing: 4) {
                    Text(formatDurationSeconds(holdTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.accent2)
                    Text("hold")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

        case .band:
            if let bandColor = set.bandColor, let reps = set.reps {
                VStack(spacing: 4) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(bandColor)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent3)

                        Text("×")
                            .font(.title2)
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(reps)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)
                    }
                    Text("reps")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private func formatDurationSeconds(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)h \(mins)m"
        } else if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(mins):\(String(format: "%02d", secs))"
            }
            return "\(mins)m"
        } else {
            return "\(seconds)s"
        }
    }

    private func formatDistanceValue(_ distance: Double) -> String {
        if distance.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(distance))"
        }
        return String(format: "%.1f", distance)
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
