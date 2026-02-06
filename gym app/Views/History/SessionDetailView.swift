//
//  SessionDetailView.swift
//  gym app
//
//  Beautiful, modular view for completed sessions
//  Designed for social sharing at every level of the hierarchy
//

import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    let session: Session
    let readOnly: Bool

    init(session: Session, readOnly: Bool = false) {
        self.session = session
        self.readOnly = readOnly
    }

    @State private var showingDeleteConfirmation = false
    @State private var showingEditSession = false
    @State private var showingShareSheet = false
    @State private var showingShareWithFriend = false
    @State private var showingPostToFeed = false
    @State private var shareContent: String = ""
    @State private var animateIn = false
    @State private var moduleToShare: ShareableModulePerformance?
    @State private var moduleToPost: ShareableModulePerformance?
    @State private var exerciseToShare: ShareableExercisePerformance?
    @State private var setToShare: ShareableSetPerformance?
    @State private var exerciseToPost: ShareableExercisePerformance?
    @State private var setToPost: ShareableSetPerformance?

    private var currentSession: Session {
        if readOnly { return session }
        return sessionViewModel.sessions.first { $0.id == session.id } ?? session
    }

    // Computed stats
    private var totalVolume: Double {
        session.completedModules.filter { !$0.skipped }.reduce(0) { moduleTotal, module in
            moduleTotal + module.completedExercises.reduce(0) { $0 + $1.totalVolume }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Hero Section
                heroSection

                // Quick Stats
                statsGrid

                // Notes (if any)
                if let notes = session.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Module Cards
                modulesSection
            }
            .padding(AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !readOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppSpacing.md) {
                        // Share menu
                        Menu {
                            Button {
                                showingPostToFeed = true
                            } label: {
                                Label("Post to Feed", systemImage: "rectangle.stack")
                            }

                            Button {
                                showingShareWithFriend = true
                            } label: {
                                Label("Share with Friend", systemImage: "paperplane")
                            }

                            Divider()

                            Button {
                                shareContent = generateSessionShareText()
                                showingShareSheet = true
                            } label: {
                                Label("Share via...", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.medium))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        // Edit button (only shown if session is editable)
                        if currentSession.isEditable {
                            Button {
                                showingEditSession = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        // Delete button
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.medium))
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSession) {
            EditSessionView(session: currentSession)
        }
        .sheet(isPresented: $showingShareSheet) {
            SessionShareSheet(items: [shareContent])
        }
        .sheet(isPresented: $showingShareWithFriend) {
            ShareWithFriendSheet(content: currentSession) { conversationWithProfile in
                let chatViewModel = ChatViewModel(
                    conversation: conversationWithProfile.conversation,
                    otherParticipant: conversationWithProfile.otherParticipant,
                    otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                )
                let content = try currentSession.createMessageContent()
                try await chatViewModel.sendSharedContent(content)
            }
        }
        .sheet(item: $exerciseToShare) { exercise in
            ShareWithFriendSheet(content: exercise) { conversationWithProfile in
                let chatViewModel = ChatViewModel(
                    conversation: conversationWithProfile.conversation,
                    otherParticipant: conversationWithProfile.otherParticipant,
                    otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                )
                let content = try exercise.createMessageContent()
                try await chatViewModel.sendSharedContent(content)
            }
        }
        .sheet(item: $setToShare) { setPerformance in
            ShareWithFriendSheet(content: setPerformance) { conversationWithProfile in
                let chatViewModel = ChatViewModel(
                    conversation: conversationWithProfile.conversation,
                    otherParticipant: conversationWithProfile.otherParticipant,
                    otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                )
                let content = try setPerformance.createMessageContent()
                try await chatViewModel.sendSharedContent(content)
            }
        }
        .sheet(isPresented: $showingPostToFeed) {
            ComposePostSheet(content: currentSession)
        }
        .sheet(item: $moduleToShare) { modulePerformance in
            ShareWithFriendSheet(content: modulePerformance) { conversationWithProfile in
                let chatViewModel = ChatViewModel(
                    conversation: conversationWithProfile.conversation,
                    otherParticipant: conversationWithProfile.otherParticipant,
                    otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                )
                let content = try modulePerformance.createMessageContent()
                try await chatViewModel.sendSharedContent(content)
            }
        }
        .sheet(item: $moduleToPost) { modulePerformance in
            ComposePostSheet(content: modulePerformance)
        }
        .sheet(item: $exerciseToPost) { exercise in
            ComposePostSheet(content: exercise)
        }
        .sheet(item: $setToPost) { setPerformance in
            ComposePostSheet(content: setPerformance)
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                sessionViewModel.deleteSession(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this workout from your history.")
        }
        .onAppear {
            withAnimation(AppAnimation.entrance) {
                animateIn = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Workout name
            Text(session.workoutName)
                .displayMedium(color: AppColors.textPrimary)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Date, duration, feeling
            HStack(spacing: AppSpacing.md) {
                Label(session.formattedDate, systemImage: "calendar")

                if let duration = session.formattedDuration {
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    Label(duration, systemImage: "clock")
                }

                if let feeling = session.overallFeeling {
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    Label("\(feeling)/10", systemImage: "star.fill")
                        .foregroundColor(feelingColor(feeling))
                }
            }
            .subheadline(color: AppColors.textSecondary)

            // Program context (if available)
            if let programName = session.programName {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "text.book.closed.fill")
                        .caption(color: AppColors.accent2)
                    Text(programName)
                        .caption(color: AppColors.accent2)
                        .fontWeight(.medium)
                    if let week = session.programWeekNumber {
                        Text("· Week \(week)")
                            .caption(color: AppColors.accent2)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.accent2.opacity(0.15))
                )
            }
        }
        .padding(.top, AppSpacing.lg)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: AppSpacing.md) {
            statCard(
                value: "\(session.totalSetsCompleted)",
                label: "SETS",
                color: AppColors.dominant
            )

            statCard(
                value: "\(session.totalExercisesCompleted)",
                label: "EXERCISES",
                color: AppColors.accent1
            )

            statCard(
                value: formatVolume(totalVolume),
                label: "VOLUME",
                color: AppColors.accent3
            )
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.1), value: animateIn)
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .displayMedium(color: color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .statLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("NOTES")
                .elegantLabel(color: AppColors.textTertiary)

            Text(notes)
                .subheadline(color: AppColors.textSecondary)
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfacePrimary)
                )
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(AppAnimation.entrance.delay(0.15), value: animateIn)
    }

    // MARK: - Modules Section

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("BREAKDOWN")
                .elegantLabel(color: AppColors.textSecondary)

            ForEach(Array(session.completedModules.enumerated()), id: \.element.id) { index, module in
                SessionModuleCard(
                    module: module,
                    sessionViewModel: sessionViewModel,
                    workoutId: session.workoutId,
                    workoutName: session.workoutName,
                    sessionDate: session.date,
                    onShareText: { content in
                        shareContent = content
                        showingShareSheet = true
                    },
                    onShareModuleWithFriend: { completedModule in
                        moduleToShare = ShareableModulePerformance(
                            module: completedModule,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    },
                    onPostModuleToFeed: { completedModule in
                        moduleToPost = ShareableModulePerformance(
                            module: completedModule,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    },
                    onShareExerciseWithFriend: { exercise in
                        exerciseToShare = ShareableExercisePerformance(
                            exercise: exercise,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    },
                    onShareSetWithFriend: { set, exerciseName, exerciseType, distanceUnit in
                        setToShare = ShareableSetPerformance(
                            set: set,
                            exerciseName: exerciseName,
                            exerciseType: exerciseType,
                            distanceUnit: distanceUnit,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    },
                    onPostExerciseToFeed: { exercise in
                        exerciseToPost = ShareableExercisePerformance(
                            exercise: exercise,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    },
                    onPostSetToFeed: { set, exerciseName, exerciseType, distanceUnit in
                        setToPost = ShareableSetPerformance(
                            set: set,
                            exerciseName: exerciseName,
                            exerciseType: exerciseType,
                            distanceUnit: distanceUnit,
                            workoutName: session.workoutName,
                            date: session.date
                        )
                    }
                )
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(AppAnimation.entrance.delay(0.2 + Double(index) * 0.05), value: animateIn)
            }
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 10000 {
            return String(format: "%.1fk", volume / 1000)
        } else if volume >= 1000 {
            return String(format: "%.0f", volume)
        } else {
            return String(format: "%.0f", volume)
        }
    }

    private func feelingColor(_ feeling: Int) -> Color {
        switch feeling {
        case 1...3: return AppColors.error
        case 4...6: return AppColors.warning
        case 7...10: return AppColors.success
        default: return AppColors.textSecondary
        }
    }

    private func generateSessionShareText() -> String {
        var text = "\(session.workoutName)\n"
        text += "\(session.formattedDate)"
        if let duration = session.formattedDuration {
            text += " · \(duration)"
        }
        text += "\n\n"
        text += "\(session.totalSetsCompleted) sets · "
        text += "\(session.totalExercisesCompleted) exercises"
        if totalVolume > 0 {
            text += " · \(formatVolume(totalVolume)) lbs"
        }
        text += "\n"

        // Add module summaries
        for module in session.completedModules where !module.skipped {
            text += "\n\(module.moduleName):\n"
            for exercise in module.completedExercises {
                if let summary = exerciseSummaryText(exercise) {
                    text += "• \(exercise.exerciseName): \(summary)\n"
                }
            }
        }

        return text
    }

    private func exerciseSummaryText(_ exercise: SessionExercise) -> String? {
        switch exercise.exerciseType {
        case .strength:
            if let topSet = exercise.topSet, let reps = topSet.reps {
                if exercise.isBodyweight {
                    if let weight = topSet.weight, weight > 0 {
                        return "BW + \(formatWeight(weight)) × \(reps)"
                    } else {
                        return "BW × \(reps)"
                    }
                } else if let band = topSet.bandColor, !band.isEmpty {
                    // Band exercise - show color instead of weight
                    return "\(band) × \(reps)"
                } else if let weight = topSet.weight {
                    return "\(formatWeight(weight)) × \(reps)"
                }
            }
        case .cardio:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            let totalDistance = allSets.compactMap { $0.distance }.reduce(0, +)
            if totalDistance > 0 {
                return "\(formatDistanceValue(totalDistance)) \(exercise.distanceUnit.abbreviation)"
            }
        case .isometric:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            if let longestHold = allSets.compactMap({ $0.holdTime }).max() {
                return "\(formatDuration(longestHold)) hold"
            }
        default:
            let totalReps = exercise.completedSetGroups.flatMap { $0.sets }.compactMap { $0.reps }.reduce(0, +)
            if totalReps > 0 {
                return "\(totalReps) reps"
            }
        }
        return nil
    }
}

// MARK: - Session Module Card

struct SessionModuleCard: View {
    let module: CompletedModule
    let sessionViewModel: SessionViewModel
    let workoutId: UUID
    let workoutName: String
    let sessionDate: Date
    let onShareText: (String) -> Void
    let onShareModuleWithFriend: (CompletedModule) -> Void
    let onPostModuleToFeed: (CompletedModule) -> Void
    let onShareExerciseWithFriend: (SessionExercise) -> Void
    let onShareSetWithFriend: (SetData, String, ExerciseType, DistanceUnit) -> Void
    let onPostExerciseToFeed: (SessionExercise) -> Void
    let onPostSetToFeed: (SetData, String, ExerciseType, DistanceUnit) -> Void

    @State private var isExpanded = true

    private var moduleColor: Color {
        AppColors.moduleColor(module.moduleType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Module Header
            Button {
                withAnimation(AppAnimation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.md) {
                    // Module icon
                    Image(systemName: module.moduleType.icon)
                        .font(.headline)
                        .foregroundColor(moduleColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(moduleColor.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.moduleName)
                            .headline()

                        Text("\(module.completedExercises.count) exercises · \(moduleSetCount) sets")
                            .caption()
                    }

                    Spacer()

                    if module.skipped {
                        Text("Skipped")
                            .caption(color: AppColors.warning)
                            .fontWeight(.medium)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppColors.warning.opacity(0.15))
                            )
                    }

                    // Share button
                    Menu {
                        Button {
                            onPostModuleToFeed(module)
                        } label: {
                            Label("Post to Feed", systemImage: "rectangle.stack")
                        }

                        Button {
                            onShareModuleWithFriend(module)
                        } label: {
                            Label("Share with Friend", systemImage: "paperplane")
                        }

                        Divider()

                        Button {
                            onShareText(generateModuleShareText())
                        } label: {
                            Label("Share via...", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .caption(color: AppColors.textTertiary)
                            .fontWeight(.medium)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary.opacity(0.5))
                            )
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }
                .padding(AppSpacing.cardPadding)
            }
            .buttonStyle(.plain)

            // Exercises (when expanded)
            if isExpanded && !module.skipped {
                Divider()
                    .background(AppColors.surfaceTertiary.opacity(0.5))

                VStack(spacing: 1) {
                    ForEach(module.completedExercises) { exercise in
                        SessionExerciseCard(
                            exercise: exercise,
                            sessionViewModel: sessionViewModel,
                            workoutId: workoutId,
                            moduleColor: moduleColor,
                            onShareText: onShareText,
                            onShareWithFriend: { onShareExerciseWithFriend(exercise) },
                            onShareSetWithFriend: { set in
                                onShareSetWithFriend(set, exercise.exerciseName, exercise.exerciseType, exercise.distanceUnit)
                            },
                            onPostToFeed: { onPostExerciseToFeed(exercise) },
                            onPostSetToFeed: { set in
                                onPostSetToFeed(set, exercise.exerciseName, exercise.exerciseType, exercise.distanceUnit)
                            }
                        )

                        if exercise.id != module.completedExercises.last?.id {
                            Divider()
                                .background(AppColors.surfaceTertiary.opacity(0.3))
                                .padding(.leading, AppSpacing.cardPadding)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(moduleColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var moduleSetCount: Int {
        module.completedExercises.reduce(0) { total, exercise in
            total + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        }
    }

    private func generateModuleShareText() -> String {
        var text = "\(module.moduleName)\n\n"

        for exercise in module.completedExercises {
            text += "• \(exercise.exerciseName)"
            if let summary = exerciseBriefSummary(exercise) {
                text += ": \(summary)"
            }
            text += "\n"
        }

        return text
    }

    private func exerciseBriefSummary(_ exercise: SessionExercise) -> String? {
        switch exercise.exerciseType {
        case .strength:
            if let topSet = exercise.topSet, let reps = topSet.reps {
                if exercise.isBodyweight {
                    if let weight = topSet.weight, weight > 0 {
                        return "BW + \(formatWeight(weight)) × \(reps)"
                    } else {
                        return "BW × \(reps)"
                    }
                } else if let band = topSet.bandColor, !band.isEmpty {
                    return "\(band) × \(reps)"
                } else if let weight = topSet.weight {
                    return "\(formatWeight(weight)) × \(reps)"
                }
            }
        default:
            return nil
        }
        return nil
    }
}

// MARK: - Session Exercise Card

struct SessionExerciseCard: View {
    let exercise: SessionExercise
    let sessionViewModel: SessionViewModel
    let workoutId: UUID
    let moduleColor: Color
    let onShareText: (String) -> Void
    let onShareWithFriend: () -> Void
    let onShareSetWithFriend: (SetData) -> Void
    let onPostToFeed: () -> Void
    let onPostSetToFeed: (SetData) -> Void

    @State private var isExpanded = false

    // Get previous session data for comparison
    private var previousExercise: SessionExercise? {
        sessionViewModel.getLastSessionData(for: exercise.exerciseName, workoutId: workoutId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Exercise header
            Button {
                withAnimation(AppAnimation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .subheadline(color: AppColors.textPrimary)
                            .fontWeight(.medium)

                        // Summary line
                        if let summary = exerciseSummary {
                            HStack(spacing: AppSpacing.xs) {
                                Text(summary)
                                    .caption(color: moduleColor)

                                // Comparison indicator
                                comparisonIndicator
                            }
                        }
                    }

                    Spacer()

                    // Share exercise button
                    Menu {
                        Button {
                            onPostToFeed()
                        } label: {
                            Label("Post to Feed", systemImage: "rectangle.stack")
                        }

                        Button {
                            onShareWithFriend()
                        } label: {
                            Label("Share with Friend", systemImage: "paperplane")
                        }

                        Divider()

                        Button {
                            onShareText(generateExerciseShareText())
                        } label: {
                            Label("Share via...", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)

                    Text(setsLabel)
                        .caption()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Expanded set details
            if isExpanded {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(exercise.completedSetGroups) { setGroup in
                        if setGroup.isInterval {
                            SessionIntervalSetRow(setGroup: setGroup)
                        } else {
                            ForEach(setGroup.sets) { set in
                                SessionSetRow(
                                    set: set,
                                    exercise: exercise,
                                    moduleColor: moduleColor,
                                    onShareText: onShareText,
                                    onShareWithFriend: { onShareSetWithFriend(set) },
                                    onPostToFeed: { onPostSetToFeed(set) }
                                )
                            }
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
    }

    // MARK: - Computed Properties

    private var setsLabel: String {
        let completedSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        return "\(completedSets)/\(totalSets)"
    }

    private var exerciseSummary: String? {
        switch exercise.exerciseType {
        case .strength:
            if exercise.isBodyweight {
                if let topSet = exercise.topSet, let reps = topSet.reps {
                    if let weight = topSet.weight, weight > 0 {
                        return "Top: BW + \(formatWeight(weight)) × \(reps)"
                    } else if let maxReps = exercise.completedSetGroups.flatMap({ $0.sets }).compactMap({ $0.reps }).max() {
                        return "Best: BW × \(maxReps)"
                    }
                }
            } else if let topSet = exercise.topSet, let band = topSet.bandColor, !band.isEmpty, let reps = topSet.reps {
                // Band exercise - show color instead of weight
                var result = "Top: \(band) × \(reps)"
                if let rpe = topSet.rpe {
                    result += " @ \(rpe)"
                }
                return result
            } else if let topSet = exercise.topSet, let weight = topSet.weight, let reps = topSet.reps {
                var result = "Top: \(formatWeight(weight)) × \(reps)"
                if let rpe = topSet.rpe {
                    result += " @ \(rpe)"
                }
                return result
            }

        case .cardio:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            let totalDistance = allSets.compactMap { $0.distance }.reduce(0, +)
            let totalDuration = allSets.compactMap { $0.duration }.reduce(0, +)
            var parts: [String] = []
            if totalDistance > 0 {
                parts.append("\(formatDistanceValue(totalDistance)) \(exercise.distanceUnit.abbreviation)")
            }
            if totalDuration > 0 {
                parts.append(formatDuration(totalDuration))
            }
            return parts.isEmpty ? nil : parts.joined(separator: " in ")

        case .isometric:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            if let longestHold = allSets.compactMap({ $0.holdTime }).max() {
                return "Best: \(formatDuration(longestHold)) hold"
            }

        case .explosive:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            if let bestHeight = allSets.compactMap({ $0.height }).max() {
                return "Best: \(formatHeight(bestHeight))"
            } else {
                let totalReps = allSets.compactMap { $0.reps }.reduce(0, +)
                if totalReps > 0 {
                    return "\(totalReps) total reps"
                }
            }

        case .mobility:
            let totalReps = exercise.completedSetGroups.flatMap { $0.sets }.compactMap { $0.reps }.reduce(0, +)
            if totalReps > 0 {
                return "\(totalReps) total reps"
            }

        case .recovery:
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            let totalDuration = allSets.compactMap { $0.duration }.reduce(0, +)
            if totalDuration > 0 {
                var result = formatDuration(totalDuration)
                if let activityType = exercise.recoveryActivityType {
                    result = "\(activityType.displayName): \(result)"
                }
                return result
            }
        }

        // Check for intervals
        let intervalGroups = exercise.completedSetGroups.filter { $0.isInterval }
        if !intervalGroups.isEmpty {
            let totalRounds = intervalGroups.reduce(0) { $0 + $1.rounds }
            if let first = intervalGroups.first, let work = first.workDuration, let rest = first.intervalRestDuration {
                return "\(totalRounds) rounds × \(formatDuration(work))/\(formatDuration(rest))"
            }
        }

        return nil
    }

    @ViewBuilder
    private var comparisonIndicator: some View {
        if exercise.exerciseType == .strength,
           let currentTop = exercise.topSet,
           let currentWeight = currentTop.weight,
           let previousTop = previousExercise?.topSet,
           let previousWeight = previousTop.weight,
           currentWeight > 0 && previousWeight > 0 {

            let diff = currentWeight - previousWeight
            if abs(diff) >= 2.5 {
                HStack(spacing: 2) {
                    Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(formatWeight(abs(diff)))
                        .font(.caption2.weight(.semibold))
                }
            }
        }
    }

    private func generateExerciseShareText() -> String {
        var text = "\(exercise.exerciseName)\n"

        if let summary = exerciseSummary {
            text += "\(summary)\n"
        }

        text += "\n"

        for setGroup in exercise.completedSetGroups {
            if setGroup.isInterval {
                text += "Interval: \(setGroup.rounds) rounds\n"
            } else {
                for set in setGroup.sets where set.completed {
                    if let formatted = formattedSetResult(set) {
                        text += "Set \(set.setNumber): \(formatted)\n"
                    }
                }
            }
        }

        return text
    }

    private func formattedSetResult(_ set: SetData) -> String? {
        switch exercise.exerciseType {
        case .strength:
            if exercise.isBodyweight {
                if let reps = set.reps {
                    if let weight = set.weight, weight > 0 {
                        return "BW + \(formatWeight(weight)) × \(reps)"
                    } else {
                        return "BW × \(reps)"
                    }
                }
            } else if let band = set.bandColor, !band.isEmpty, let reps = set.reps {
                // Band exercise - show color instead of weight
                var result = "\(band) × \(reps)"
                if let rpe = set.rpe {
                    result += " @ \(rpe)"
                }
                return result
            } else if let weight = set.weight, let reps = set.reps {
                var result = "\(formatWeight(weight)) × \(reps)"
                if let rpe = set.rpe {
                    result += " @ \(rpe)"
                }
                return result
            }

        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")

        case .isometric:
            if let holdTime = set.holdTime {
                return formatDuration(holdTime) + " hold"
            }

        case .explosive:
            var parts: [String] = []
            if let reps = set.reps { parts.append("\(reps) reps") }
            if let height = set.height { parts.append("@ \(formatHeight(height))") }
            return parts.isEmpty ? nil : parts.joined(separator: " ")

        case .mobility:
            if let reps = set.reps {
                var result = "\(reps) reps"
                if let duration = set.duration, duration > 0 {
                    result += " (\(formatDuration(duration)))"
                }
                return result
            }

        case .recovery:
            if let duration = set.duration {
                return formatDuration(duration)
            }
        }

        return nil
    }
}

// MARK: - Session Set Row

struct SessionSetRow: View {
    let set: SetData
    let exercise: SessionExercise
    let moduleColor: Color
    let onShareText: (String) -> Void
    let onShareWithFriend: () -> Void
    let onPostToFeed: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Set number badge
            Text("\(set.setNumber)")
                .caption2(color: set.completed ? moduleColor : AppColors.textTertiary)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(set.completed ? moduleColor.opacity(0.15) : AppColors.surfaceTertiary.opacity(0.5))
                )

            // Side indicator (for unilateral)
            if let side = set.side {
                Text(side == .left ? "L" : "R")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.semibold)
                    .frame(width: 16)
            }

            // Set data
            if let formatted = formattedSetData {
                Text(formatted)
                    .caption(color: set.completed ? AppColors.textPrimary : AppColors.textTertiary)
            }

            Spacer()

            // Share single set
            if set.completed {
                Menu {
                    Button {
                        onPostToFeed()
                    } label: {
                        Label("Post to Feed", systemImage: "rectangle.stack")
                    }

                    Button {
                        onShareWithFriend()
                    } label: {
                        Label("Share with Friend", systemImage: "paperplane")
                    }

                    Divider()

                    Button {
                        onShareText(generateSetShareText())
                    } label: {
                        Label("Share via...", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(AppColors.textTertiary.opacity(0.6))
                }
            }

            // Completion indicator
            if !set.completed {
                Text("skipped")
                    .caption2(color: AppColors.textTertiary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.leading, AppSpacing.lg)
    }

    private var formattedSetData: String? {
        switch exercise.exerciseType {
        case .strength:
            if exercise.isBodyweight {
                if let reps = set.reps {
                    if let weight = set.weight, weight > 0 {
                        var result = "BW + \(formatWeight(weight)) × \(reps)"
                        if let rpe = set.rpe { result += " @ \(rpe)" }
                        return result
                    } else {
                        var result = "BW × \(reps)"
                        if let rpe = set.rpe { result += " @ \(rpe)" }
                        return result
                    }
                }
            } else if let band = set.bandColor, !band.isEmpty, let reps = set.reps {
                // Band exercise - show color instead of weight
                var result = "\(band) × \(reps)"
                if let rpe = set.rpe { result += " @ \(rpe)" }
                return result
            } else if let weight = set.weight, let reps = set.reps {
                var result = "\(formatWeight(weight)) × \(reps)"
                if let rpe = set.rpe { result += " @ \(rpe)" }
                return result
            } else if let reps = set.reps {
                return "\(reps) reps"
            }

        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 { parts.append(formatDuration(duration)) }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")

        case .isometric:
            if let holdTime = set.holdTime { return "\(formatDuration(holdTime)) hold" }

        case .explosive:
            var parts: [String] = []
            if let reps = set.reps { parts.append("\(reps) reps") }
            if let height = set.height { parts.append("@ \(formatHeight(height))") }
            return parts.isEmpty ? nil : parts.joined(separator: " ")

        case .mobility:
            if let reps = set.reps { return "\(reps) reps" }

        case .recovery:
            if let duration = set.duration { return formatDuration(duration) }
        }

        return nil
    }

    private func generateSetShareText() -> String {
        var text = "\(exercise.exerciseName) - Set \(set.setNumber)\n"
        if let formatted = formattedSetData {
            text += "\(formatted)\n"
        }
        if let date = set.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            text += formatter.string(from: date)
        }
        return text
    }
}

// MARK: - Session Interval Set Row

struct SessionIntervalSetRow: View {
    let setGroup: CompletedSetGroup

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundColor(AppColors.warning)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Interval")
                    .caption(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                HStack(spacing: AppSpacing.xs) {
                    Text("\(setGroup.rounds) rounds")
                        .caption2(color: AppColors.warning)

                    if let work = setGroup.workDuration, let rest = setGroup.intervalRestDuration {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(formatDuration(work)) / \(formatDuration(rest))")
                            .caption2(color: AppColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.leading, AppSpacing.lg)
    }
}

// MARK: - Share Sheet

private struct SessionShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionDetailView(session: Session(
            workoutId: UUID(),
            workoutName: "Monday - Lower A",
            completedModules: [
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Strength",
                    moduleType: .strength,
                    completedExercises: [
                        SessionExercise(
                            exerciseId: UUID(),
                            exerciseName: "Barbell Squat",
                            exerciseType: .strength,
                            completedSetGroups: [
                                CompletedSetGroup(
                                    setGroupId: UUID(),
                                    sets: [
                                        SetData(setNumber: 1, weight: 225, reps: 8, completed: true),
                                        SetData(setNumber: 2, weight: 225, reps: 7, completed: true),
                                        SetData(setNumber: 3, weight: 225, reps: 6, completed: true)
                                    ]
                                )
                            ]
                        ),
                        SessionExercise(
                            exerciseId: UUID(),
                            exerciseName: "Romanian Deadlift",
                            exerciseType: .strength,
                            completedSetGroups: [
                                CompletedSetGroup(
                                    setGroupId: UUID(),
                                    sets: [
                                        SetData(setNumber: 1, weight: 185, reps: 10, completed: true),
                                        SetData(setNumber: 2, weight: 185, reps: 10, completed: true),
                                        SetData(setNumber: 3, weight: 185, reps: 8, completed: true)
                                    ]
                                )
                            ]
                        )
                    ]
                ),
                CompletedModule(
                    moduleId: UUID(),
                    moduleName: "Cardio",
                    moduleType: .cardioLong,
                    completedExercises: [
                        SessionExercise(
                            exerciseId: UUID(),
                            exerciseName: "Treadmill Run",
                            exerciseType: .cardio,
                            completedSetGroups: [
                                CompletedSetGroup(
                                    setGroupId: UUID(),
                                    sets: [
                                        SetData(setNumber: 1, completed: true, duration: 1200, distance: 2.0)
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ],
            duration: 75,
            overallFeeling: 8,
            notes: "Great session! Hit a PR on squats."
        ))
        .environmentObject(SessionViewModel())
    }
}
