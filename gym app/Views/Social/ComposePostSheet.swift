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
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.body)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.shared.tap()
                        Task {
                            if await viewModel.createPost() {
                                HapticManager.shared.success()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isPosting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Post")
                                .font(.headline.weight(.semibold))
                        }
                    }
                    .disabled(viewModel.isPosting || isPostDisabled)
                    .foregroundColor(isPostDisabled ? AppColors.textTertiary : AppColors.dominant)
                }
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

                // Remove button
                Button {
                    viewModel.clearContent()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.dominant.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: viewModel.contentIcon)
                        .font(.title3.weight(.medium))
                        .foregroundColor(AppColors.dominant)
                }

                // Content info
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.contentPreview)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    if let type = viewModel.content.contentTypeLabel {
                        Text(type)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Caption Input

    private var captionInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(isTextOnlyPost ? "WHAT'S ON YOUR MIND?" : "ADD A CAPTION")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            ZStack(alignment: .topLeading) {
                // Text editor
                TextEditor(text: $viewModel.caption)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 120)
                    .focused($isCaptionFocused)

                // Placeholder
                if viewModel.caption.isEmpty {
                    Text(isTextOnlyPost ? "Share what's on your mind..." : "Say something about this...")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        isCaptionFocused ? AppColors.dominant.opacity(0.5) : AppColors.surfaceTertiary.opacity(0.3),
                        lineWidth: isCaptionFocused ? 1.5 : 1
                    )
            )

            // Character count
            HStack {
                Spacer()
                Text("\(viewModel.caption.count)/500")
                    .font(.caption)
                    .foregroundColor(
                        viewModel.caption.count > 500 ? AppColors.error :
                        viewModel.caption.count > 400 ? AppColors.warning :
                        AppColors.textTertiary
                    )
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
    let onSelect: (any ShareableContent) -> Void

    @State private var selectedType: ContentPickerType?

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
            SessionPickerView(onSelect: onSelect)
        case .programs:
            ProgramPickerView(onSelect: onSelect)
        case .workouts:
            WorkoutPickerView(onSelect: onSelect)
        case .modules:
            ModulePickerView(onSelect: onSelect)
        }
    }
}

// MARK: - Session Picker (Workout History)

private struct SessionPickerView: View {
    let onSelect: (any ShareableContent) -> Void

    @State private var sessions: [Session] = []
    @State private var selectedSession: Session?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                emptyState
            } else if let session = selectedSession {
                SessionContentPicker(session: session, onSelect: onSelect, onBack: {
                    selectedSession = nil
                })
            } else {
                sessionList
            }
        }
        .onAppear {
            loadSessions()
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No Workouts Yet")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("Complete a workout to share it here")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(sessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.success)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.xs) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    if let duration = session.duration {
                        Text("·")
                        Text("\(duration) min")
                    }
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
    }

    private func loadSessions() {
        sessions = DataRepository.shared.sessions.sorted { $0.date > $1.date }
        isLoading = false
    }
}

// MARK: - Session Content Picker (drill into a session)

private struct SessionContentPicker: View {
    let session: Session
    let onSelect: (any ShareableContent) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Share whole workout
                Button {
                    onSelect(session)
                } label: {
                    shareOptionRow(
                        icon: "checkmark.circle.fill",
                        color: AppColors.success,
                        title: "Share Entire Workout",
                        subtitle: "\(session.workoutName) · \(session.totalSetsCompleted) sets"
                    )
                }
                .buttonStyle(.plain)

                // Modules section
                if !session.completedModules.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("MODULES")
                            .font(.caption.weight(.bold))
                            .tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        ForEach(session.completedModules) { module in
                            Button {
                                let wrapper = ShareableModulePerformance(
                                    module: module,
                                    workoutName: session.workoutName,
                                    date: session.date
                                )
                                onSelect(wrapper)
                            } label: {
                                moduleRow(module)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Top exercises section
                let topExercises = getTopExercises()
                if !topExercises.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("TOP EXERCISES")
                            .font(.caption.weight(.bold))
                            .tracking(0.5)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        ForEach(topExercises, id: \.exercise.id) { item in
                            Button {
                                let wrapper = ShareableExercisePerformance(
                                    exercise: item.exercise,
                                    workoutName: session.workoutName,
                                    date: session.date
                                )
                                onSelect(wrapper)
                            } label: {
                                exerciseRow(item.exercise, module: item.module)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle(session.workoutName)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
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

    private func shareOptionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3.weight(.medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitle)
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
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private func moduleRow(_ module: CompletedModule) -> some View {
        let moduleColor = AppColors.moduleColor(module.moduleType)
        let exerciseCount = module.completedExercises.count

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: module.moduleType.icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(moduleColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.moduleName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(exerciseCount) exercises")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private func exerciseRow(_ exercise: SessionExercise, module: CompletedModule) -> some View {
        let topSet = exercise.topSet

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: "dumbbell.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.dominant)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                if let topSet = topSet, let weight = topSet.weight, let reps = topSet.reps {
                    Text("Top: \(Int(weight)) × \(reps)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private func getTopExercises() -> [(exercise: SessionExercise, module: CompletedModule)] {
        var results: [(SessionExercise, CompletedModule)] = []

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises {
                guard exercise.exerciseType == .strength,
                      let topSet = exercise.topSet,
                      let weight = topSet.weight, weight > 0 else { continue }
                results.append((exercise, module))
            }
        }

        return Array(results.sorted { ($0.0.topSet?.weight ?? 0) > ($1.0.topSet?.weight ?? 0) }.prefix(5))
    }
}

// MARK: - Program Picker

private struct ProgramPickerView: View {
    let onSelect: (any ShareableContent) -> Void

    @State private var programs: [Program] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if programs.isEmpty {
                emptyState("No Programs", "Create a program to share it")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(programs) { program in
                            Button {
                                onSelect(program)
                            } label: {
                                templateRow(
                                    icon: "doc.text.fill",
                                    color: AppColors.dominant,
                                    title: program.name,
                                    subtitle: "\(program.durationWeeks) weeks"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
        }
        .onAppear {
            programs = DataRepository.shared.programs
            isLoading = false
        }
    }
}

// MARK: - Workout Picker

private struct WorkoutPickerView: View {
    let onSelect: (any ShareableContent) -> Void

    @State private var workouts: [Workout] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workouts.isEmpty {
                emptyState("No Workouts", "Create a workout to share it")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(workouts) { workout in
                            Button {
                                onSelect(workout)
                            } label: {
                                templateRow(
                                    icon: "figure.run",
                                    color: AppColors.dominant,
                                    title: workout.name,
                                    subtitle: "\(workout.moduleReferences.count) modules"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
        }
        .onAppear {
            workouts = DataRepository.shared.workouts
            isLoading = false
        }
    }
}

// MARK: - Module Picker

private struct ModulePickerView: View {
    let onSelect: (any ShareableContent) -> Void

    @State private var modules: [Module] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if modules.isEmpty {
                emptyState("No Modules", "Create a module to share it")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(modules) { module in
                            Button {
                                onSelect(module)
                            } label: {
                                templateRow(
                                    icon: module.type.icon,
                                    color: module.type.color,
                                    title: module.name,
                                    subtitle: "\(module.exercises.count) exercises"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
        }
        .onAppear {
            modules = DataRepository.shared.modules
            isLoading = false
        }
    }
}

// MARK: - Shared Components

private func emptyState(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: AppSpacing.md) {
        Image(systemName: "tray")
            .font(.largeTitle)
            .foregroundColor(AppColors.textTertiary)

        Text(title)
            .font(.headline)
            .foregroundColor(AppColors.textPrimary)

        Text(subtitle)
            .font(.subheadline)
            .foregroundColor(AppColors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private func templateRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
    HStack(spacing: AppSpacing.md) {
        ZStack {
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(color.opacity(0.1))
                .frame(width: 40, height: 40)

            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(color)
        }

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.textTertiary)
    }
    .padding(AppSpacing.md)
    .background(AppColors.surfacePrimary)
    .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
}

// MARK: - Preview

#Preview("Text Post") {
    ComposePostSheet()
}

#Preview("Content Picker") {
    ContentPickerSheet { _ in }
}
