//
//  ComposePostSheet.swift
//  gym app
//
//  Sheet for creating new posts to the feed
//  Supports text posts and sharing templates/workout history
//

import SwiftUI

struct ComposePostSheet: View {
    @StateObject private var viewModel: ComposePostViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCaptionFocused: Bool

    // Content selection state
    @State private var showingContentPicker = false
    @State private var selectedContentType: ContentPickerType?
    @State private var didSubmit = false
    @State private var showDraftRestored = false
    @State private var showSchedulePicker = false

    /// Initialize for a text-only post (shows content picker option)
    init() {
        _viewModel = StateObject(wrappedValue: ComposePostViewModel())
    }

    /// Initialize with shareable content (session, exercise, etc.)
    init(content: any ShareableContent) {
        _viewModel = StateObject(wrappedValue: ComposePostViewModel(content: content))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Show error if content creation failed
                    if let error = viewModel.contentCreationError {
                        contentErrorView(error)
                    }
                    // Content attachment section
                    else if !isTextOnlyPost {
                        contentPreview
                    } else {
                        // Show "Attach content" button for text-only posts
                        attachContentButton
                    }

                    // Caption input
                    captionInput

                    // Schedule section
                    scheduleSection
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PostEditorToolbar(
                    isProcessing: viewModel.isPosting,
                    canSubmit: !isPostDisabled,
                    submitTitle: viewModel.isScheduled ? "Schedule" : "Post",
                    onCancel: { dismiss() },
                    onSubmit: {
                        HapticManager.shared.tap()
                        Task {
                            if await viewModel.createPost() {
                                didSubmit = true
                                HapticManager.shared.success()
                                dismiss()
                            }
                        }
                    }
                )
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
            .sheet(isPresented: $showingContentPicker) {
                ContentPickerSheet { content in
                    viewModel.setContent(content)
                    showingContentPicker = false
                }
            }
            .onAppear {
                if viewModel.hasDraft && isTextOnlyPost {
                    showDraftRestored = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showDraftRestored = false }
                    }
                }
            }
            .onDisappear {
                if !didSubmit {
                    viewModel.saveDraft()
                }
            }
        }
    }

    // MARK: - Attach Content Button

    private var attachContentButton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("ATTACH CONTENT")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            Button {
                showingContentPicker = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.dominant.opacity(0.1))
                            .frame(width: 48, height: 48)

                        Image(systemName: "plus")
                            .font(.title3.weight(.medium))
                            .foregroundColor(AppColors.dominant)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share a workout or template")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Programs, workouts, completed sessions, PRs...")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.cardPadding)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content Error View

    private func contentErrorView(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.error)

                Text("Unable to create post")
                    .font(.headline)
                    .foregroundColor(AppColors.error)
            }

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.error.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.error.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("SHARING")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)

                Spacer()
            }

            ContentPreviewCard(
                icon: viewModel.contentIcon,
                iconColor: AppColors.dominant,
                title: viewModel.contentPreview,
                subtitle: viewModel.content.contentTypeLabel,
                onRemove: { viewModel.clearContent() }
            )
        }
    }

    // MARK: - Caption Input

    private var captionInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            CaptionInputView(
                caption: $viewModel.caption,
                isFocused: $isCaptionFocused,
                label: isTextOnlyPost ? "WHAT'S ON YOUR MIND?" : "ADD A CAPTION",
                placeholder: isTextOnlyPost ? "Share what's on your mind..." : "Say something about this..."
            )

            if showDraftRestored {
                Text("Draft restored")
                    .caption(color: AppColors.textTertiary)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("SCHEDULE")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            if let scheduledDate = viewModel.scheduledDate {
                // Show scheduled date with option to remove
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppColors.accent2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scheduled for")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text(scheduledDate, style: .date)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        +
                        Text(" at ")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        +
                        Text(scheduledDate, style: .time)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Spacer()

                    Button {
                        withAnimation { viewModel.scheduledDate = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.accent2.opacity(0.3), lineWidth: 1)
                )
            } else {
                Button {
                    showSchedulePicker = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "clock")
                            .foregroundColor(AppColors.textSecondary)
                        Text("Schedule for later")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSchedulePicker) {
            ScheduleDatePickerSheet { date in
                viewModel.scheduledDate = date
            }
        }
    }

    // MARK: - Helpers

    private var isTextOnlyPost: Bool {
        if case .text = viewModel.content {
            return true
        }
        return false
    }

    private var isPostDisabled: Bool {
        if isTextOnlyPost {
            return viewModel.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   viewModel.caption.count > 500
        }
        return viewModel.caption.count > 500
    }
}

// MARK: - Content Picker Types

enum ContentPickerType: Identifiable, CaseIterable {
    case workoutHistory
    case programs
    case workouts
    case modules

    var id: Self { self }

    var title: String {
        switch self {
        case .workoutHistory: return "Workout History"
        case .programs: return "Programs"
        case .workouts: return "Workouts"
        case .modules: return "Modules"
        }
    }

    var subtitle: String {
        switch self {
        case .workoutHistory: return "Share a completed workout, exercise, or PR"
        case .programs: return "Share a training program"
        case .workouts: return "Share a workout template"
        case .modules: return "Share an exercise module"
        }
    }

    var icon: String {
        switch self {
        case .workoutHistory: return "checkmark.circle.fill"
        case .programs: return "doc.text.fill"
        case .workouts: return "figure.run"
        case .modules: return "square.stack.3d.up.fill"
        }
    }

    var color: Color {
        switch self {
        case .workoutHistory: return AppColors.success
        case .programs: return AppColors.dominant
        case .workouts: return AppColors.dominant
        case .modules: return AppColors.accent3
        }
    }
}

// MARK: - Content Picker Sheet

struct ContentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var programViewModel: ProgramViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel

    let onSelect: (any ShareableContent) -> Void

    @State private var selectedType: ContentPickerType?
    @State private var selectedSession: Session?
    @State private var showingHighlightPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if let type = selectedType {
                    contentListView(for: type)
                } else {
                    typePickerView
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(selectedType?.title ?? "Share Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if selectedType != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                selectedType = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.semibold))
                                Text("Back")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHighlightPicker) {
                if let session = selectedSession {
                    HighlightPickerView(session: session) { highlights in
                        // Handle multiple highlights by bundling them together
                        if highlights.count == 1, let single = highlights.first {
                            // Single item - use as-is
                            onSelect(single)
                        } else if highlights.count > 1 {
                            // Multiple items - bundle them together
                            var exercises: [ShareableExercisePerformance] = []
                            var sets: [ShareableSetPerformance] = []

                            for highlight in highlights {
                                if let ex = highlight as? ShareableExercisePerformance {
                                    exercises.append(ex)
                                } else if let s = highlight as? ShareableSetPerformance {
                                    sets.append(s)
                                } else if let sessionWithHighlights = highlight as? ShareableSessionWithHighlights {
                                    // Full workout with user-selected highlights
                                    onSelect(sessionWithHighlights)
                                    dismiss()
                                    return
                                } else if let sess = highlight as? Session {
                                    // If entire session was selected, use it directly
                                    onSelect(sess)
                                    dismiss()
                                    return
                                }
                            }

                            let bundle = ShareableHighlightBundle(
                                workoutName: session.workoutName,
                                date: session.date,
                                exercises: exercises,
                                sets: sets
                            )
                            onSelect(bundle)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Type Picker

    private var typePickerView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                ForEach(ContentPickerType.allCases) { type in
                    Button {
                        withAnimation {
                            selectedType = type
                        }
                    } label: {
                        contentTypeRow(type)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
    }

    private func contentTypeRow(_ type: ContentPickerType) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(type.color.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: type.icon)
                    .font(.title3.weight(.medium))
                    .foregroundColor(type.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(type.subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Content List Views

    @ViewBuilder
    private func contentListView(for type: ContentPickerType) -> some View {
        switch type {
        case .workoutHistory:
            // Use existing HistoryView in selection mode
            HistoryView(
                selectionMode: .forSharing,
                onSelectForShare: { session in
                    // Show highlight picker for this session
                    selectedSession = session
                    showingHighlightPicker = true
                }
            )

        case .programs:
            // Use existing ProgramsListView in selection mode
            ProgramsListView(
                selectionMode: .forSharing,
                onSelectForShare: { program in
                    onSelect(program)
                    dismiss()
                }
            )

        case .workouts:
            // Use existing WorkoutsListView in selection mode
            WorkoutsListView(
                selectionMode: .forSharing,
                onSelectForShare: { workout in
                    onSelect(workout)
                    dismiss()
                }
            )

        case .modules:
            // Use existing ModulesListView in selection mode
            ModulesListView(
                selectionMode: .forSharing,
                onSelectForShare: { module in
                    onSelect(module)
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Schedule Date Picker Sheet

struct ScheduleDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date().addingTimeInterval(3600) // Default: 1 hour from now
    let onSchedule: (Date) -> Void

    private var minimumDate: Date {
        Date().addingTimeInterval(300) // At least 5 minutes in the future
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Text("Choose when to publish this post")
                    .subheadline(color: AppColors.textSecondary)
                    .padding(.top, AppSpacing.md)

                DatePicker(
                    "Schedule Date",
                    selection: $selectedDate,
                    in: minimumDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.accent2)
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer()

                Button {
                    onSchedule(selectedDate)
                    dismiss()
                } label: {
                    Text("Set Schedule")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.accent2)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Schedule Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Text Post") {
    ComposePostSheet()
}

//#Preview("Content Picker") {
//    ContentPickerSheet { _ in }
//        .environmentObject(ModuleViewModel())
//        .environmentObject(WorkoutViewModel())
//        .environmentObject(ProgramViewModel())
//        .environmentObject(SessionViewModel())
//}
