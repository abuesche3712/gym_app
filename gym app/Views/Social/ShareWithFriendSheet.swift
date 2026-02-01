//
//  ShareWithFriendSheet.swift
//  gym app
//
//  Sheet for selecting a friend to share content with
//

import SwiftUI

// MARK: - Shareable Content Protocol

/// Protocol for content that can be shared with friends
protocol ShareableContent {
    var shareTitle: String { get }
    var shareSubtitle: String? { get }
    var shareIcon: String { get }
    func createMessageContent() throws -> MessageContent
}

// MARK: - Program Conformance

extension Program: ShareableContent {
    var shareTitle: String { name }
    var shareSubtitle: String? {
        let workoutCount = workoutSlots.count
        return "\(workoutCount) workout\(workoutCount == 1 ? "" : "s")"
    }
    var shareIcon: String { "doc.text.fill" }

    func createMessageContent() throws -> MessageContent {
        let bundle = try SharingService.shared.createProgramBundle(self)
        let data = try bundle.encode()
        return .sharedProgram(id: id, name: name, snapshot: data)
    }
}

// MARK: - Workout Conformance

extension Workout: ShareableContent {
    var shareTitle: String { name }
    var shareSubtitle: String? {
        let moduleCount = moduleReferences.count
        return "\(moduleCount) module\(moduleCount == 1 ? "" : "s")"
    }
    var shareIcon: String { "figure.run" }

    func createMessageContent() throws -> MessageContent {
        let bundle = try SharingService.shared.createWorkoutBundle(self)
        let data = try bundle.encode()
        return .sharedWorkout(id: id, name: name, snapshot: data)
    }
}

// MARK: - Module Conformance

extension Module: ShareableContent {
    var shareTitle: String { name }
    var shareSubtitle: String? {
        let exerciseCount = exercises.count
        return "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
    }
    var shareIcon: String { "square.stack.3d.up.fill" }

    func createMessageContent() throws -> MessageContent {
        let bundle = try SharingService.shared.createModuleBundle(self)
        let data = try bundle.encode()
        return .sharedModule(id: id, name: name, snapshot: data)
    }
}

// MARK: - Session Conformance

extension Session: ShareableContent {
    var shareTitle: String { workoutName }
    var shareSubtitle: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    var shareIcon: String { "checkmark.circle.fill" }

    func createMessageContent() throws -> MessageContent {
        let bundle = try SharingService.shared.createSessionBundle(self, workoutName: workoutName)
        let data = try bundle.encode()
        return .sharedSession(id: id, workoutName: workoutName, date: date, snapshot: data)
    }
}

// MARK: - Exercise Performance Wrapper

/// Wrapper for sharing a completed exercise with all its context
struct ShareableExercisePerformance: ShareableContent, Identifiable {
    let id: UUID
    let exercise: SessionExercise
    let workoutName: String
    let date: Date

    init(exercise: SessionExercise, workoutName: String, date: Date) {
        self.id = exercise.id
        self.exercise = exercise
        self.workoutName = workoutName
        self.date = date
    }

    var shareTitle: String { exercise.exerciseName }
    var shareSubtitle: String? {
        if let topSet = exercise.topSet {
            return formatTopSet(topSet)
        }
        let setCount = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        return "\(setCount) set\(setCount == 1 ? "" : "s") completed"
    }
    var shareIcon: String { "figure.strengthtraining.traditional" }

    func createMessageContent() throws -> MessageContent {
        // Populate sharing context on the exercise
        var exerciseWithContext = exercise
        exerciseWithContext.workoutName = workoutName
        exerciseWithContext.date = date

        let allSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
        let bundle = try SharingService.shared.createExerciseBundle(
            exerciseName: exercise.exerciseName,
            setData: allSets,
            workoutName: workoutName
        )
        let data = try bundle.encode()
        return .sharedExercise(snapshot: data)
    }

    private func formatTopSet(_ set: SetData) -> String? {
        switch exercise.exerciseType {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                return "\(formatWeight(weight)) × \(reps)"
            } else if let band = set.bandColor, let reps = set.reps {
                return "\(band) × \(reps)"
            }
        case .cardio:
            if let distance = set.distance {
                return "\(formatDistanceValue(distance)) \(exercise.distanceUnit.abbreviation)"
            }
        case .isometric:
            if let holdTime = set.holdTime {
                return "\(formatDuration(holdTime)) hold"
            }
        default:
            if let reps = set.reps {
                return "\(reps) reps"
            }
        }
        return nil
    }
}

// MARK: - Module Performance Wrapper

/// Wrapper for sharing a completed module with all its exercises
struct ShareableModulePerformance: ShareableContent, Identifiable {
    let id: UUID
    let module: CompletedModule
    let workoutName: String
    let date: Date

    init(module: CompletedModule, workoutName: String, date: Date) {
        self.id = module.id
        self.module = module
        self.workoutName = workoutName
        self.date = date
    }

    var shareTitle: String { module.moduleName }
    var shareSubtitle: String? {
        let exerciseCount = module.completedExercises.count
        let setCount = module.completedExercises.reduce(0) { sum, ex in
            sum + ex.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        }
        return "\(exerciseCount) exercises · \(setCount) sets"
    }
    var shareIcon: String { module.moduleType.icon }

    func createMessageContent() throws -> MessageContent {
        // Create a snapshot of the completed module performance
        let bundle = CompletedModuleShareBundle(
            module: module,
            workoutName: workoutName,
            date: date
        )
        let data = try bundle.encode()
        return .sharedCompletedModule(snapshot: data)
    }
}

// MARK: - Set Performance Wrapper

/// Wrapper for sharing a single set (typically a PR)
struct ShareableSetPerformance: ShareableContent, Identifiable {
    let id: UUID
    let set: SetData
    let exerciseName: String
    let exerciseType: ExerciseType
    let workoutName: String?
    let date: Date
    let isPR: Bool

    init(set: SetData, exerciseName: String, exerciseType: ExerciseType, workoutName: String? = nil, date: Date = Date(), isPR: Bool = false) {
        self.id = set.id
        self.set = set
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType
        self.workoutName = workoutName
        self.date = date
        self.isPR = isPR
    }

    var shareTitle: String { exerciseName }
    var shareSubtitle: String? {
        var result = formatSetData()
        if isPR {
            result = "🏆 PR: " + (result ?? "")
        }
        return result
    }
    var shareIcon: String { isPR ? "trophy.fill" : "flame.fill" }

    func createMessageContent() throws -> MessageContent {
        let bundle = try SharingService.shared.createSetBundle(
            exerciseName: exerciseName,
            setData: set,
            isPR: isPR,
            workoutName: workoutName
        )
        let data = try bundle.encode()
        return .sharedSet(snapshot: data)
    }

    private func formatSetData() -> String? {
        switch exerciseType {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                var result = "\(formatWeight(weight)) × \(reps)"
                if let rpe = set.rpe {
                    result += " @ RPE \(rpe)"
                }
                return result
            } else if let band = set.bandColor, let reps = set.reps {
                return "\(band) × \(reps)"
            }
        case .cardio:
            var parts: [String] = []
            if let duration = set.duration { parts.append(formatDuration(duration)) }
            if let distance = set.distance { parts.append("\(formatDistanceValue(distance)) mi") }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")
        case .isometric:
            if let holdTime = set.holdTime {
                return "\(formatDuration(holdTime)) hold"
            }
        default:
            if let reps = set.reps {
                return "\(reps) reps"
            }
        }
        return nil
    }
}

// MARK: - Share With Friend Sheet

struct ShareWithFriendSheet: View {
    let content: any ShareableContent
    let onShare: (ConversationWithProfile) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsViewModel = FriendsViewModel()
    @StateObject private var conversationsViewModel = ConversationsViewModel()
    @State private var isSharing = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var shareSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview header
                SharePreviewHeader(content: content)
                    .padding()
                    .background(AppColors.surfaceSecondary)

                Divider()

                // Friends list
                if friendsViewModel.friends.isEmpty && !friendsViewModel.isLoading {
                    emptyState
                } else {
                    friendsList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Share with Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                friendsViewModel.loadFriendships()
                conversationsViewModel.loadConversations()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(error?.localizedDescription ?? "Failed to share")
            }
            .overlay {
                if shareSuccess {
                    successOverlay
                }
            }
        }
    }

    private var friendsList: some View {
        List {
            ForEach(friendsViewModel.friends) { friendship in
                FriendShareRow(
                    friendship: friendship,
                    isSharing: isSharing,
                    onTap: {
                        Task {
                            await shareWithFriend(friendship)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No Friends Yet")
                .headline(color: AppColors.textPrimary)

            Text("Add friends to share your workouts and programs with them")
                .subheadline(color: AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }

    private var successOverlay: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.success)

            Text("Shared!")
                .headline(color: AppColors.textPrimary)
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    private func shareWithFriend(_ friend: FriendWithProfile) async {
        isSharing = true
        defer { isSharing = false }

        do {
            // Get the friend's Firebase UID
            guard let currentUserId = conversationsViewModel.currentUserId,
                  let friendFirebaseId = friend.friendship.otherUserId(from: currentUserId) else {
                throw SharingError.profileNotFound
            }

            // Get or create conversation with friend
            let conversation = try await conversationsViewModel.startConversation(with: friendFirebaseId)

            let conversationWithProfile = ConversationWithProfile(
                conversation: conversation,
                otherParticipant: friend.profile,
                otherParticipantFirebaseId: friendFirebaseId
            )

            try await onShare(conversationWithProfile)
            shareSuccess = true
        } catch {
            self.error = error
            showingError = true
        }
    }
}

// MARK: - Friend Share Row

struct FriendShareRow: View {
    let friendship: FriendWithProfile
    let isSharing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Avatar
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(avatarInitials)
                            .subheadline(color: AppColors.dominant)
                            .fontWeight(.semibold)
                    }

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    if let displayName = friendship.profile.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .headline(color: AppColors.textPrimary)
                    }
                    Text("@\(friendship.profile.username)")
                        .subheadline(color: AppColors.textSecondary)
                }

                Spacer()

                if isSharing {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppColors.dominant)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSharing)
    }

    private var avatarInitials: String {
        if let displayName = friendship.profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(friendship.profile.username.prefix(2)).uppercased()
    }
}

// MARK: - Share Preview Header

struct SharePreviewHeader: View {
    let content: any ShareableContent

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            Image(systemName: content.shareIcon)
                .font(.title2)
                .foregroundColor(AppColors.dominant)
                .frame(width: 44, height: 44)
                .background(AppColors.dominant.opacity(0.15))
                .cornerRadius(AppCorners.medium)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(content.shareTitle)
                    .headline(color: AppColors.textPrimary)

                if let subtitle = content.shareSubtitle {
                    Text(subtitle)
                        .caption(color: AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Sharing Errors

enum SharingError: LocalizedError {
    case profileNotFound
    case encodingFailed
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Could not find friend's profile"
        case .encodingFailed:
            return "Failed to prepare content for sharing"
        case .sendFailed:
            return "Failed to send shared content"
        }
    }
}
