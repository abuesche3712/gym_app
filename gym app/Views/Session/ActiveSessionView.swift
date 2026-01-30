//
//  ActiveSessionView.swift
//  gym app
//
//  Main view for logging an active workout session
//

import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Callback to minimize the session (show mini bar instead)
    var onMinimize: (() -> Void)?

    @State private var showingWorkoutSummary = false
    @State private var showingEndConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var hideToolbarButtons = false
    @State private var showModuleTransition = false
    @State private var completedModuleName = ""
    @State private var nextModuleName = ""
    @State private var showWorkoutComplete = false
    @State private var checkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var statsOpacity: Double = 0
    @State private var showWorkoutOverview = false
    @State private var showEditExercise = false
    @State private var showIntervalTimer = false
    @State private var intervalSetGroupIndex: Int = 0
    @State private var highlightNextSet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Header
                    sessionProgressHeader

                    // Main Content
                    if let currentModule = sessionViewModel.currentModule,
                       let currentExercise = sessionViewModel.currentExercise {

                        GeometryReader { geometry in
                            let contentWidth = geometry.size.width - (AppSpacing.screenPadding * 2)
                            ScrollView {
                                VStack(spacing: AppSpacing.lg) {
                                    // Module indicator
                                    moduleIndicator(currentModule)

                                    // Exercise Card header
                                    exerciseCard(currentExercise)

                                    // All Sets (expandable rows) - pass fixed width to prevent layout shifts
                                    allSetsSection(width: contentWidth)

                                    // Rest Timer (inline)
                                    if sessionViewModel.isRestTimerRunning {
                                        restTimerBar
                                    }

                                    // Previous Performance
                                    previousPerformanceSection(exerciseName: currentExercise.exerciseName)
                                }
                                .padding(AppSpacing.screenPadding)
                                .frame(width: geometry.size.width)
                            }
                        }
                    } else {
                        // Workout complete
                        workoutCompleteView
                    }
                }

                // Module Transition Overlay
                if showModuleTransition {
                    moduleTransitionOverlay
                }

                // Workout Complete Overlay
                if showWorkoutComplete {
                    workoutCompleteOverlay
                }
            }
            .navigationTitle(sessionViewModel.currentSession?.workoutName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Minimize button (leading)
                if onMinimize != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onMinimize?()
                        } label: {
                            Image(systemName: "chevron.down")
                                .body(color: AppColors.textSecondary)
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Show Cancel/Finish buttons for first 30 seconds, then collapse to menu
                if !hideToolbarButtons {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingCancelConfirmation = true
                        }
                        .foregroundColor(AppColors.error)
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button("Finish") {
                            showingWorkoutSummary = true
                        }
                        .foregroundColor(AppColors.dominant)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if onMinimize != nil {
                                Button {
                                    onMinimize?()
                                } label: {
                                    Label("Minimize", systemImage: "chevron.down")
                                }
                            }

                            Button {
                                showWorkoutOverview = true
                            } label: {
                                Label("Overview", systemImage: "list.bullet")
                            }

                            Button {
                                showingWorkoutSummary = true
                            } label: {
                                Label("Finish Workout", systemImage: "checkmark.circle")
                            }

                            Button(role: .destructive) {
                                showingCancelConfirmation = true
                            } label: {
                                Label("Cancel Workout", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .displaySmall(color: AppColors.textSecondary)
                        }
                    }
                }
            }
            .onAppear {
                // Hide toolbar buttons after 30 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hideToolbarButtons = true
                    }
                }
            }
            .onChange(of: sessionViewModel.isRestTimerRunning) { wasRunning, isRunning in
                // Highlight next set when rest timer ends (moved to body level for reliability)
                if wasRunning && !isRunning {
                    highlightNextSet = true
                }
            }
            .confirmationDialog("Cancel Workout", isPresented: $showingCancelConfirmation) {
                Button("Cancel Workout", role: .destructive) {
                    sessionViewModel.cancelSession()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to cancel? Your progress will not be saved.")
            }
            .sheet(isPresented: $showingWorkoutSummary) {
                if let session = sessionViewModel.currentSession {
                    WorkoutSummaryView(
                        session: session,
                        elapsedSeconds: sessionViewModel.sessionElapsedSeconds,
                        onReviewAndSave: {
                            showingWorkoutSummary = false
                            // Small delay to allow sheet dismiss animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingEndConfirmation = true
                            }
                        },
                        onQuickSave: { feeling, notes in
                            workoutViewModel.markScheduledWorkoutsCompleted(
                                workoutId: session.workoutId,
                                sessionId: session.id,
                                sessionDate: session.date
                            )
                            sessionViewModel.endSession(feeling: feeling, notes: notes)
                            showingWorkoutSummary = false
                            dismiss()
                        }
                    )
                    .environmentObject(sessionViewModel)
                }
            }
            .sheet(isPresented: $showingEndConfirmation) {
                EndSessionSheet(session: $sessionViewModel.currentSession) { feeling, notes in
                    // Capture session info before ending
                    if let session = sessionViewModel.currentSession {
                        workoutViewModel.markScheduledWorkoutsCompleted(
                            workoutId: session.workoutId,
                            sessionId: session.id,
                            sessionDate: session.date
                        )
                    }
                    sessionViewModel.endSession(feeling: feeling, notes: notes)
                    dismiss()
                }
            }
            .sheet(isPresented: $showEditExercise) {
                if let exercise = sessionViewModel.currentExercise {
                    EditExerciseSheet(
                        exercise: exercise,
                        moduleIndex: sessionViewModel.currentModuleIndex,
                        exerciseIndex: sessionViewModel.currentExerciseIndex,
                        onSave: { moduleIndex, exerciseIndex, updatedExercise in
                            updateExerciseAt(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, exercise: updatedExercise)
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showIntervalTimer) {
                if let exercise = sessionViewModel.currentExercise,
                   intervalSetGroupIndex < exercise.completedSetGroups.count {
                    let setGroup = exercise.completedSetGroups[intervalSetGroupIndex]
                    IntervalTimerView(
                        rounds: setGroup.rounds,
                        workDuration: setGroup.workDuration ?? 30,
                        restDuration: setGroup.intervalRestDuration ?? 30,
                        exerciseName: exercise.exerciseName,
                        onComplete: { durations in
                            logIntervalCompletion(setGroupIndex: intervalSetGroupIndex, durations: durations)
                        },
                        onCancel: {
                            // Just dismiss, no logging
                        }
                    )
                }
            }
            .sheet(isPresented: $showWorkoutOverview) {
                WorkoutOverviewSheet(
                    session: $sessionViewModel.currentSession,
                    currentModuleIndex: sessionViewModel.currentModuleIndex,
                    currentExerciseIndex: sessionViewModel.currentExerciseIndex,
                    onJumpTo: { moduleIndex, exerciseIndex in
                        sessionViewModel.setPosition(
                            moduleIndex: moduleIndex,
                            exerciseIndex: exerciseIndex,
                            setGroupIndex: 0,
                            setIndex: 0
                        )
                        showWorkoutOverview = false
                    },
                    onUpdateSet: { moduleIndex, exerciseIndex, setGroupIndex, setIndex, weight, reps, rpe, duration, holdTime, distance, completed in
                        updateSetAt(
                            moduleIndex: moduleIndex,
                            exerciseIndex: exerciseIndex,
                            setGroupIndex: setGroupIndex,
                            setIndex: setIndex,
                            weight: weight,
                            reps: reps,
                            rpe: rpe,
                            duration: duration,
                            holdTime: holdTime,
                            distance: distance,
                            completed: completed
                        )
                    },
                    onAddExercise: { moduleIndex, name, type, cardioMetric, distanceUnit in
                        addExerciseToModule(moduleIndex: moduleIndex, name: name, type: type, cardioMetric: cardioMetric, distanceUnit: distanceUnit)
                    },
                    onReorderExercise: { moduleIndex, fromIndex, toIndex in
                        reorderExercise(in: moduleIndex, from: fromIndex, to: toIndex)
                    },
                    onDeleteExercise: { moduleIndex, exerciseIndex in
                        sessionViewModel.deleteExercise(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex)
                    }
                )
            }
        }
    }

    // MARK: - Progress Header (Subtle) - Tap or drag down for overview

    private var sessionProgressHeader: some View {
        VStack(spacing: 0) {
            // Thin progress bar at very top
            if let session = sessionViewModel.currentSession {
                let totalSets = session.completedModules.reduce(0) { moduleSum, module in
                    moduleSum + module.completedExercises.reduce(0) { exerciseSum, exercise in
                        exerciseSum + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
                    }
                }
                let completedSets = countCompletedSets()
                let progress = Double(completedSets) / Double(max(totalSets, 1))

                GeometryReader { geo in
                    Rectangle()
                        .fill(AppColors.accent1)
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(height: 3)
                .background(AppColors.surfaceTertiary.opacity(0.3))
            }

            // Compact info row - tappable for overview
            Button {
                showWorkoutOverview = true
                HapticManager.shared.soft()
            } label: {
                ZStack {
                    // Left and right content in an HStack
                    HStack {
                        // Timer - subtle
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .caption(color: AppColors.textTertiary)
                            Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                                .monoSmall(color: AppColors.textSecondary)
                        }

                        Spacer()

                        // Module progress - subtle
                        if let session = sessionViewModel.currentSession {
                            Text("\(sessionViewModel.currentModuleIndex + 1)/\(session.completedModules.count)")
                                .caption(color: AppColors.textTertiary)
                                .fontWeight(.medium)
                        }
                    }

                    // Centered overview hint
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .caption2(color: AppColors.textTertiary)
                        Text("Overview")
                            .caption2(color: AppColors.textTertiary)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.surfaceTertiary)
                    )
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(AppColors.surfacePrimary.opacity(0.5))
    }

    private func countCompletedSets() -> Int {
        guard let session = sessionViewModel.currentSession else { return 0 }
        var count = 0
        for (moduleIndex, module) in session.completedModules.enumerated() {
            for (exerciseIndex, exercise) in module.completedExercises.enumerated() {
                for (setGroupIndex, setGroup) in exercise.completedSetGroups.enumerated() {
                    for (setIndex, set) in setGroup.sets.enumerated() {
                        if moduleIndex < sessionViewModel.currentModuleIndex ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex < sessionViewModel.currentExerciseIndex) ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex == sessionViewModel.currentExerciseIndex && setGroupIndex < sessionViewModel.currentSetGroupIndex) ||
                           (moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex == sessionViewModel.currentExerciseIndex && setGroupIndex == sessionViewModel.currentSetGroupIndex && setIndex < sessionViewModel.currentSetIndex) {
                            count += 1
                        } else if set.completed {
                            count += 1
                        }
                    }
                }
            }
        }
        return count
    }

    // MARK: - Module Indicator (Compact)

    private func moduleIndicator(_ module: CompletedModule) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: module.moduleType.icon)
                .caption(color: AppColors.moduleColor(module.moduleType))
                .fontWeight(.medium)

            Text(module.moduleName)
                .subheadline(color: AppColors.textSecondary)
                .fontWeight(.medium)

            Spacer()

            Button {
                sessionViewModel.skipModule()
            } label: {
                Text("Skip")
                    .caption2(color: AppColors.textTertiary)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.moduleColor(module.moduleType).opacity(0.08))
        )
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Superset indicator
            if exercise.isInSuperset,
               let position = sessionViewModel.supersetPosition,
               let total = sessionViewModel.supersetTotal {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "link")
                        .caption(color: AppColors.warning)
                    Text("SUPERSET \(position)/\(total)")
                        .caption(color: AppColors.warning)
                        .fontWeight(.semibold)

                    Spacer()

                    // Show next exercise in superset
                    if let supersetExercises = sessionViewModel.currentSupersetExercises,
                       position < total {
                        Text("Next: \(supersetExercises[position].exerciseName)")
                            .caption(color: AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(AppColors.warning.opacity(0.1))
                )
            }

            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(exercise.exerciseName)
                        .headline(color: AppColors.textPrimary)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(exerciseSetsSummary(exercise))
                        .subheadline(color: AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Fixed-width button group to prevent layout shift
                HStack(spacing: AppSpacing.xs) {
                    // Edit button
                    Button {
                        showEditExercise = true
                    } label: {
                        Image(systemName: "pencil")
                            .body(color: AppColors.textTertiary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Edit exercise")

                    // Back button (always reserve space)
                    Button {
                        goToPreviousExerciseSuperset()
                    } label: {
                        Image(systemName: "backward.fill")
                            .body(color: canGoBack ? AppColors.textTertiary : AppColors.textTertiary.opacity(0.3))
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .disabled(!canGoBack)
                    .accessibilityLabel("Previous exercise")

                    // Skip button (superset-aware)
                    Button {
                        skipToNextExerciseSuperset()
                    } label: {
                        Image(systemName: "forward.fill")
                            .body(color: AppColors.textTertiary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Next exercise")
                }
                .fixedSize()
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppGradients.cardGradientElevated)
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppGradients.cardShine)
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.4), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onLongPressGesture {
            showEditExercise = true
        }
    }

    private func exerciseSetsSummary(_ exercise: SessionExercise) -> String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedCount = exercise.completedSetGroups.reduce(0) { groupSum, group in
            groupSum + group.sets.filter { $0.completed }.count
        }
        return "\(completedCount)/\(totalSets) sets completed"
    }

    // MARK: - All Sets Section

    @ViewBuilder
    private func allSetsSection(width: CGFloat) -> some View {
        VStack(spacing: AppSpacing.md) {
            if let exercise = sessionViewModel.currentExercise {
                // Check for interval set groups
                ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.element.id) { groupIndex, setGroup in
                    if setGroup.isInterval {
                        // Interval set group - show special UI
                        intervalSetGroupRow(setGroup: setGroup, groupIndex: groupIndex)
                    } else {
                        // Regular sets
                        let lastSessionExercise = sessionViewModel.getLastSessionData(for: exercise.exerciseName)
                        ForEach(flattenedSetsForGroup(exercise: exercise, groupIndex: groupIndex), id: \.id) { flatSet in
                            let isFirstIncomplete = isFirstIncompleteSet(flatSet, in: exercise)
                            SetRowView(
                                flatSet: flatSet,
                                exercise: exercise,
                                isHighlighted: highlightNextSet && isFirstIncomplete,
                                onLog: { weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues in
                                    logSetAt(flatSet: flatSet, weight: weight, reps: reps, rpe: rpe, duration: duration, holdTime: holdTime, distance: distance, height: height, intensity: intensity, temperature: temperature, bandColor: bandColor, implementMeasurableValues: implementMeasurableValues)
                                    // Clear highlight when logging
                                    highlightNextSet = false
                                    // Start rest timer (skip for recovery activities)
                                    if exercise.exerciseType != .recovery {
                                        let restPeriod = flatSet.restPeriod ?? appState.defaultRestTime
                                        if !allSetsCompleted(exercise) {
                                            sessionViewModel.startRestTimer(seconds: restPeriod)
                                        }
                                    }
                                },
                                onDelete: canDeleteSet(exercise: exercise) ? {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        deleteSetAt(flatSet: flatSet)
                                    }
                                } : nil,
                                onDistanceUnitChange: exercise.exerciseType == .cardio ? { newUnit in
                                    sessionViewModel.updateExerciseDistanceUnit(
                                        moduleIndex: sessionViewModel.currentModuleIndex,
                                        exerciseIndex: sessionViewModel.currentExerciseIndex,
                                        unit: newUnit
                                    )
                                } : nil,
                                onUncheck: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        uncheckSetAt(flatSet: flatSet)
                                    }
                                },
                                lastSessionExercise: lastSessionExercise,
                                contentWidth: width - (AppSpacing.cardPadding * 2)
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if canDeleteSet(exercise: exercise) {
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            deleteSetAt(flatSet: flatSet)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                // Add Set button
                Button {
                    addSetToCurrentExercise()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus")
                            .caption(color: AppColors.textSecondary)
                            .fontWeight(.medium)
                        Text("Add Set")
                            .subheadline(color: AppColors.textSecondary)
                            .fontWeight(.medium)
                    }
                    .frame(width: width - (AppSpacing.cardPadding * 2))
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.small)
                            .stroke(AppColors.surfaceTertiary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(.plain)

                // Progression buttons (show when all sets completed)
                if allSetsCompleted(exercise) && exercise.exerciseType == .strength {
                    progressionButtonsSection(exercise: exercise, width: width)
                }

                // Next Exercise button
                Button {
                    highlightNextSet = true
                    advanceToNextExercise()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: isLastExercise ? "checkmark.circle.fill" : "arrow.right")
                            .body(color: .white)
                            .fontWeight(.semibold)
                        Text(isLastExercise ? "Complete Workout" : "Next Exercise")
                            .headline(color: .white)
                    }
                    .frame(width: width - (AppSpacing.cardPadding * 2))
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(allSetsCompleted(exercise) ? AppGradients.dominantGradient : LinearGradient(colors: [AppColors.textTertiary], startPoint: .leading, endPoint: .trailing))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(width: width)  // Lock width to prevent layout shifts
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
        .clipped()
    }

    // MARK: - Interval Set Group Row

    private func intervalSetGroupRow(setGroup: CompletedSetGroup, groupIndex: Int) -> some View {
        let allCompleted = setGroup.sets.allSatisfy { $0.completed }
        let completedCount = setGroup.sets.filter { $0.completed }.count

        return VStack(spacing: AppSpacing.md) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .body(color: AppColors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interval")
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.semibold)

                    Text("\(setGroup.rounds) rounds: \(formatDuration(setGroup.workDuration ?? 30)) on / \(formatDuration(setGroup.intervalRestDuration ?? 30)) off")
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()

                if allCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .displaySmall(color: AppColors.success)
                } else if completedCount > 0 {
                    Text("\(completedCount)/\(setGroup.rounds)")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.medium)
                }
            }

            // Start button or completion summary
            if allCompleted {
                // Show completed rounds summary
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(setGroup.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Round \(index + 1)")
                                .caption(color: AppColors.textTertiary)

                            Spacer()

                            if let duration = set.duration {
                                Text(formatDuration(duration))
                                    .caption(color: AppColors.textSecondary)
                                    .fontWeight(.medium)
                            }

                            Image(systemName: "checkmark")
                                .caption2(color: AppColors.success)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(AppColors.success.opacity(0.05))
                )
            } else {
                // Start interval button
                Button {
                    startIntervalTimer(setGroupIndex: groupIndex)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.fill")
                            .subheadline(color: .white)
                        Text("Start Interval")
                            .subheadline(color: .white)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(LinearGradient(
                                colors: [AppColors.warning, AppColors.warning.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(allCompleted ? AppColors.success.opacity(0.3) : AppColors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // Uses FlatSet defined in SessionModels

    private func flattenedSetsForGroup(exercise: SessionExercise, groupIndex: Int) -> [FlatSet] {
        guard groupIndex < exercise.completedSetGroups.count else { return [] }
        let setGroup = exercise.completedSetGroups[groupIndex]

        // Calculate running set number by counting sets in previous groups
        var runningSetNumber = 1
        for i in 0..<groupIndex {
            let prevGroup = exercise.completedSetGroups[i]
            // For unilateral exercises, count pairs (2 SetData = 1 logical set)
            if prevGroup.isUnilateral {
                runningSetNumber += prevGroup.sets.count / 2
            } else {
                runningSetNumber += prevGroup.sets.count
            }
        }

        var result: [FlatSet] = []
        for (setIndex, setData) in setGroup.sets.enumerated() {
            result.append(FlatSet(
                id: "\(groupIndex)-\(setIndex)",
                setGroupIndex: groupIndex,
                setIndex: setIndex,
                setNumber: runningSetNumber,
                setData: setData,
                targetWeight: setData.weight,
                targetReps: setData.reps,
                targetDuration: setData.duration,
                targetHoldTime: setData.holdTime,
                targetDistance: setData.distance,
                restPeriod: setGroup.restPeriod,
                isInterval: setGroup.isInterval,
                workDuration: setGroup.workDuration,
                intervalRestDuration: setGroup.intervalRestDuration,
                isAMRAP: setGroup.isAMRAP,
                amrapTimeLimit: setGroup.amrapTimeLimit,
                isUnilateral: setGroup.isUnilateral,
                trackRPE: setGroup.trackRPE,
                implementMeasurables: setGroup.implementMeasurables
            ))

            // For unilateral sets, left and right share the same set number
            // Only increment after completing both sides (right side)
            if setGroup.isUnilateral {
                if setData.side == .right {
                    runningSetNumber += 1
                }
            } else {
                runningSetNumber += 1
            }
        }
        return result
    }

    private func flattenedSets(_ exercise: SessionExercise) -> [FlatSet] {
        var result: [FlatSet] = []
        var runningSetNumber = 1

        for (groupIndex, setGroup) in exercise.completedSetGroups.enumerated() {
            for (setIndex, setData) in setGroup.sets.enumerated() {
                result.append(FlatSet(
                    id: "\(groupIndex)-\(setIndex)",
                    setGroupIndex: groupIndex,
                    setIndex: setIndex,
                    setNumber: runningSetNumber,
                    setData: setData,
                    targetWeight: setData.weight,
                    targetReps: setData.reps,
                    targetDuration: setData.duration,
                    targetHoldTime: setData.holdTime,
                    targetDistance: setData.distance,
                    restPeriod: setGroup.restPeriod,
                    isInterval: setGroup.isInterval,
                    workDuration: setGroup.workDuration,
                    intervalRestDuration: setGroup.intervalRestDuration,
                    isAMRAP: setGroup.isAMRAP,
                    amrapTimeLimit: setGroup.amrapTimeLimit,
                    isUnilateral: setGroup.isUnilateral,
                    trackRPE: setGroup.trackRPE,
                    implementMeasurables: setGroup.implementMeasurables
                ))

                // For unilateral sets, left and right share the same set number
                // Only increment after completing both sides (right side)
                if setGroup.isUnilateral {
                    if setData.side == .right {
                        runningSetNumber += 1
                    }
                } else {
                    runningSetNumber += 1
                }
            }
        }
        return result
    }

    private func allSetsCompleted(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.allSatisfy { group in
            group.sets.allSatisfy { $0.completed }
        }
    }

    // MARK: - Progression Buttons

    private func progressionButtonsSection(exercise: SessionExercise, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Next session:")
                .caption(color: AppColors.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(ProgressionRecommendation.allCases) { recommendation in
                    progressionButton(recommendation, exercise: exercise)
                }
            }
            .frame(width: width - (AppSpacing.cardPadding * 2))
        }
        .padding(.top, AppSpacing.sm)
    }

    private func progressionButton(_ recommendation: ProgressionRecommendation, exercise: SessionExercise) -> some View {
        let isSelected = exercise.progressionRecommendation == recommendation
        let color = recommendation.color

        return Button {
            updateExerciseProgression(exercise: exercise, recommendation: recommendation)
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: recommendation.icon)
                    .caption(color: isSelected ? .white : color)
                Text(recommendation.displayName)
                    .caption(color: isSelected ? .white : color)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private func updateExerciseProgression(exercise: SessionExercise, recommendation: ProgressionRecommendation) {
        sessionViewModel.updateExerciseProgression(
            moduleIndex: sessionViewModel.currentModuleIndex,
            exerciseIndex: sessionViewModel.currentExerciseIndex,
            recommendation: exercise.progressionRecommendation == recommendation ? nil : recommendation
        )
    }

    private func isFirstIncompleteSet(_ flatSet: FlatSet, in exercise: SessionExercise) -> Bool {
        // Find the first incomplete set in the exercise
        for setGroup in exercise.completedSetGroups {
            for set in setGroup.sets {
                if !set.completed {
                    // This is the first incomplete set - check if it matches our flatSet
                    return set.id == flatSet.setData.id
                }
            }
        }
        return false
    }

    private var isLastExercise: Bool {
        guard let session = sessionViewModel.currentSession else { return true }
        let lastModuleIndex = session.completedModules.count - 1
        guard sessionViewModel.currentModuleIndex == lastModuleIndex else { return false }
        guard sessionViewModel.currentModuleIndex < session.completedModules.count else { return true }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]
        return sessionViewModel.currentExerciseIndex == module.completedExercises.count - 1
    }

    private var canGoBack: Bool {
        // Can go back if not at the very first exercise of the first module
        sessionViewModel.currentModuleIndex > 0 || sessionViewModel.currentExerciseIndex > 0
    }

    private func goToPreviousExercise() {
        sessionViewModel.goToPreviousExercise()
    }

    /// Superset-aware navigation to previous exercise
    /// If in superset, goes to previous exercise in superset first
    private func goToPreviousExerciseSuperset() {
        guard let session = sessionViewModel.currentSession else { return }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]

        // Check if in superset
        if let exercise = sessionViewModel.currentExercise,
           let supersetId = exercise.supersetGroupId {
            let supersetIndices = module.completedExercises.enumerated()
                .filter { $0.element.supersetGroupId == supersetId }
                .map { $0.offset }

            if let currentPos = supersetIndices.firstIndex(of: sessionViewModel.currentExerciseIndex),
               currentPos > 0 {
                // Move to previous exercise in superset
                sessionViewModel.moveToExercise(supersetIndices[currentPos - 1])
                return
            }
        }

        // Normal back navigation
        sessionViewModel.goToPreviousExercise()
    }

    /// Superset-aware skip to next exercise
    /// If in superset, goes to next exercise in superset first
    private func skipToNextExerciseSuperset() {
        guard let session = sessionViewModel.currentSession else { return }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]

        // Check if in superset
        if let exercise = sessionViewModel.currentExercise,
           let supersetId = exercise.supersetGroupId {
            let supersetIndices = module.completedExercises.enumerated()
                .filter { $0.element.supersetGroupId == supersetId }
                .map { $0.offset }

            if let currentPos = supersetIndices.firstIndex(of: sessionViewModel.currentExerciseIndex),
               currentPos < supersetIndices.count - 1 {
                // Move to next exercise in superset
                sessionViewModel.moveToExercise(supersetIndices[currentPos + 1])
                return
            }
        }

        // Normal skip (exits superset or moves to next non-superset exercise)
        sessionViewModel.skipExercise()
    }

    // MARK: - Add Set

    private func addSetToCurrentExercise() {
        guard var session = sessionViewModel.currentSession else { return }
        guard sessionViewModel.currentModuleIndex < session.completedModules.count else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        guard sessionViewModel.currentExerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]

        // Find the last set group and its last set to copy targets from
        guard let lastSetGroup = exercise.completedSetGroups.last,
              let lastSet = lastSetGroup.sets.last else { return }

        // Create new set with same targets
        let newSetNumber = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count } + 1
        let newSet = SetData(
            setNumber: newSetNumber,
            weight: lastSet.weight,
            reps: lastSet.reps,
            completed: false,
            duration: lastSet.duration,
            distance: lastSet.distance,
            holdTime: lastSet.holdTime
        )

        // Add to the last set group
        var updatedSetGroup = lastSetGroup
        updatedSetGroup.sets.append(newSet)
        exercise.completedSetGroups[exercise.completedSetGroups.count - 1] = updatedSetGroup

        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session

        // Refresh the navigator so it sees the new set
        sessionViewModel.refreshNavigator()
    }

    // MARK: - Delete Set

    private func canDeleteSet(exercise: SessionExercise) -> Bool {
        // Can delete if there's more than 1 set total in the exercise
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        return totalSets > 1
    }

    private func deleteSetAt(flatSet: FlatSet) {
        guard var session = sessionViewModel.currentSession else { return }
        guard sessionViewModel.currentModuleIndex < session.completedModules.count else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        guard sessionViewModel.currentExerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]

        // Find the set group and remove the set
        guard flatSet.setGroupIndex < exercise.completedSetGroups.count else { return }
        var setGroup = exercise.completedSetGroups[flatSet.setGroupIndex]

        guard flatSet.setIndex < setGroup.sets.count else { return }

        // Remove the set
        setGroup.sets.remove(at: flatSet.setIndex)

        // If the set group is now empty, remove it too
        if setGroup.sets.isEmpty {
            exercise.completedSetGroups.remove(at: flatSet.setGroupIndex)
        } else {
            // Update set numbers for remaining sets
            for i in 0..<setGroup.sets.count {
                setGroup.sets[i].setNumber = i + 1
            }
            exercise.completedSetGroups[flatSet.setGroupIndex] = setGroup
        }

        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session

        // Refresh the navigator so it sees the updated structure
        sessionViewModel.refreshNavigator()
    }

    // MARK: - Update Exercise

    private func updateExerciseAt(moduleIndex: Int, exerciseIndex: Int, exercise: SessionExercise) {
        guard var session = sessionViewModel.currentSession else { return }
        guard moduleIndex < session.completedModules.count else { return }
        guard exerciseIndex < session.completedModules[moduleIndex].completedExercises.count else { return }

        session.completedModules[moduleIndex].completedExercises[exerciseIndex] = exercise
        sessionViewModel.currentSession = session

        // Reset set indices if we're on the current exercise
        if moduleIndex == sessionViewModel.currentModuleIndex && exerciseIndex == sessionViewModel.currentExerciseIndex {
            // Find first incomplete set
            for (groupIndex, setGroup) in exercise.completedSetGroups.enumerated() {
                for (setIndex, set) in setGroup.sets.enumerated() {
                    if !set.completed {
                        sessionViewModel.jumpToSet(setGroupIndex: groupIndex, setIndex: setIndex)
                        return
                    }
                }
            }
            // If all sets complete, jump to first set
            sessionViewModel.jumpToSet(setGroupIndex: 0, setIndex: 0)
        }
    }

    // MARK: - Add Exercise to Module

    private func addExerciseToModule(moduleIndex: Int, name: String, type: ExerciseType, cardioMetric: CardioMetric, distanceUnit: DistanceUnit) {
        guard var session = sessionViewModel.currentSession else { return }
        guard moduleIndex < session.completedModules.count else { return }

        // Create a new ad-hoc exercise with one set group (1 set)
        let newExercise = SessionExercise(
            exerciseId: UUID(),
            exerciseName: name,
            exerciseType: type,
            cardioMetric: cardioMetric,
            distanceUnit: distanceUnit,
            completedSetGroups: [
                CompletedSetGroup(
                    setGroupId: UUID(),
                    sets: [
                        SetData(setNumber: 1, completed: false)
                    ]
                )
            ],
            isSubstitution: false,
            originalExerciseName: nil,
            isAdHoc: true
        )

        // Add to the specified module
        session.completedModules[moduleIndex].completedExercises.append(newExercise)
        sessionViewModel.currentSession = session
    }

    // MARK: - Reorder Exercise

    private func reorderExercise(in moduleIndex: Int, from: Int, to: Int) {
        guard var session = sessionViewModel.currentSession else { return }
        guard moduleIndex < session.completedModules.count else { return }

        var module = session.completedModules[moduleIndex]
        guard from < module.completedExercises.count && to < module.completedExercises.count else { return }

        // Move the exercise
        let exercise = module.completedExercises.remove(at: from)
        module.completedExercises.insert(exercise, at: to)

        session.completedModules[moduleIndex] = module
        sessionViewModel.currentSession = session

        // Update current exercise index if needed
        if moduleIndex == sessionViewModel.currentModuleIndex {
            var newExerciseIndex = sessionViewModel.currentExerciseIndex
            if sessionViewModel.currentExerciseIndex == from {
                // We moved the current exercise
                newExerciseIndex = to
            } else if from < sessionViewModel.currentExerciseIndex && to >= sessionViewModel.currentExerciseIndex {
                // Moved an exercise from before to after current
                newExerciseIndex = sessionViewModel.currentExerciseIndex - 1
            } else if from > sessionViewModel.currentExerciseIndex && to <= sessionViewModel.currentExerciseIndex {
                // Moved an exercise from after to before current
                newExerciseIndex = sessionViewModel.currentExerciseIndex + 1
            }
            sessionViewModel.setPosition(exerciseIndex: newExerciseIndex)
        }
    }

    private func updateSetAt(moduleIndex: Int, exerciseIndex: Int, setGroupIndex: Int, setIndex: Int, weight: Double?, reps: Int?, rpe: Int?, duration: Int?, holdTime: Int?, distance: Double?, completed: Bool? = nil) {
        guard var session = sessionViewModel.currentSession else { return }
        guard moduleIndex < session.completedModules.count else { return }

        var module = session.completedModules[moduleIndex]
        guard exerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[exerciseIndex]
        guard setGroupIndex < exercise.completedSetGroups.count else { return }
        var setGroup = exercise.completedSetGroups[setGroupIndex]
        guard setIndex < setGroup.sets.count else { return }
        var setData = setGroup.sets[setIndex]

        setData.weight = weight ?? setData.weight
        setData.reps = reps ?? setData.reps
        setData.rpe = rpe
        setData.duration = duration ?? setData.duration
        setData.holdTime = holdTime ?? setData.holdTime
        setData.distance = distance ?? setData.distance
        if let completed = completed {
            setData.completed = completed
        }

        setGroup.sets[setIndex] = setData
        exercise.completedSetGroups[setGroupIndex] = setGroup
        module.completedExercises[exerciseIndex] = exercise
        session.completedModules[moduleIndex] = module

        sessionViewModel.currentSession = session
    }

    private func logSetAt(flatSet: FlatSet, weight: Double?, reps: Int?, rpe: Int?, duration: Int?, holdTime: Int?, distance: Double?, height: Double? = nil, intensity: Int? = nil, temperature: Int? = nil, bandColor: String? = nil, implementMeasurableValues: [String: String]? = nil) {
        guard var session = sessionViewModel.currentSession else { return }
        guard sessionViewModel.currentModuleIndex < session.completedModules.count else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        guard sessionViewModel.currentExerciseIndex < module.completedExercises.count else { return }
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]
        guard flatSet.setGroupIndex < exercise.completedSetGroups.count else { return }
        var setGroup = exercise.completedSetGroups[flatSet.setGroupIndex]
        guard flatSet.setIndex < setGroup.sets.count else { return }
        var setData = setGroup.sets[flatSet.setIndex]

        setData.weight = weight ?? setData.weight
        setData.reps = reps ?? setData.reps
        setData.rpe = rpe
        setData.duration = duration ?? setData.duration
        setData.holdTime = holdTime ?? setData.holdTime
        setData.distance = distance ?? setData.distance
        setData.height = height ?? setData.height
        setData.intensity = intensity
        setData.temperature = temperature
        setData.bandColor = bandColor ?? setData.bandColor

        // Convert string dictionary to MeasurableValue dictionary
        if let stringValues = implementMeasurableValues, !stringValues.isEmpty {
            var measurableDict: [String: MeasurableValue] = [:]
            for (key, stringValue) in stringValues where !stringValue.isEmpty {
                // Try to parse as number, otherwise store as string
                if let numericValue = Double(stringValue) {
                    measurableDict[key] = MeasurableValue(numericValue: numericValue, stringValue: nil)
                } else {
                    measurableDict[key] = MeasurableValue(numericValue: nil, stringValue: stringValue)
                }
            }
            if !measurableDict.isEmpty {
                setData.implementMeasurableValues = measurableDict
            }
        }

        setData.completed = true

        setGroup.sets[flatSet.setIndex] = setData
        exercise.completedSetGroups[flatSet.setGroupIndex] = setGroup
        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session
    }

    /// Uncheck a completed set to allow editing
    private func uncheckSetAt(flatSet: FlatSet) {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]
        var setGroup = exercise.completedSetGroups[flatSet.setGroupIndex]
        var setData = setGroup.sets[flatSet.setIndex]

        // Mark as incomplete so user can edit
        setData.completed = false

        setGroup.sets[flatSet.setIndex] = setData
        exercise.completedSetGroups[flatSet.setGroupIndex] = setGroup
        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session
    }

    // MARK: - Interval Logging

    private func logIntervalCompletion(setGroupIndex: Int, durations: [Int]) {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]
        var setGroup = exercise.completedSetGroups[setGroupIndex]

        // Mark each round as completed with its duration
        for (index, duration) in durations.enumerated() {
            if index < setGroup.sets.count {
                setGroup.sets[index].duration = duration
                setGroup.sets[index].completed = true
            }
        }

        exercise.completedSetGroups[setGroupIndex] = setGroup
        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session

        // If all sets in this exercise are complete, start rest timer
        if allSetsCompleted(exercise), let restPeriod = setGroup.restPeriod {
            sessionViewModel.startRestTimer(seconds: restPeriod)
        }
    }

    private func startIntervalTimer(setGroupIndex: Int) {
        intervalSetGroupIndex = setGroupIndex
        showIntervalTimer = true
    }

    private func advanceToNextExercise() {
        guard let session = sessionViewModel.currentSession else { return }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]

        // Check if in superset
        if let exercise = sessionViewModel.currentExercise,
           let supersetId = exercise.supersetGroupId {
            let supersetIndices = module.completedExercises.enumerated()
                .filter { $0.element.supersetGroupId == supersetId }
                .map { $0.offset }

            if let currentPos = supersetIndices.firstIndex(of: sessionViewModel.currentExerciseIndex),
               currentPos < supersetIndices.count - 1 {
                // Move to next exercise in superset
                sessionViewModel.moveToExercise(supersetIndices[currentPos + 1])
                return
            }
        }

        // Normal advance
        if sessionViewModel.currentExerciseIndex < module.completedExercises.count - 1 {
            // Next exercise in same module
            sessionViewModel.goToNextExercise()
        } else if sessionViewModel.currentModuleIndex < session.completedModules.count - 1 {
            // Moving to next module - show transition
            let currentModuleName = module.moduleName
            let nextModule = session.completedModules[sessionViewModel.currentModuleIndex + 1]
            showModuleTransitionAnimation(from: currentModuleName, to: nextModule.moduleName) {
                sessionViewModel.goToNextModule()
            }
        } else {
            // Workout complete - show animation
            showWorkoutCompleteAnimation()
        }
    }

    private func showModuleTransitionAnimation(from: String, to: String, completion: @escaping () -> Void) {
        completedModuleName = from
        nextModuleName = to
        withAnimation(.easeOut(duration: 0.3)) {
            showModuleTransition = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.3)) {
                showModuleTransition = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }

    private func showWorkoutCompleteAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showWorkoutComplete = true
        }
    }

    // MARK: - Previous Performance

    private func previousPerformanceSection(exerciseName: String) -> some View {
        Group {
            if let lastData = sessionViewModel.getLastSessionData(for: exerciseName) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .subheadline(color: AppColors.textTertiary)
                        Text("Last Session")
                            .subheadline(color: AppColors.textSecondary)
                            .fontWeight(.semibold)

                        Spacer()

                        // Show progression recommendation if set
                        if let progression = lastData.progressionRecommendation {
                            HStack(spacing: 4) {
                                Image(systemName: progression.icon)
                                    .caption(color: progression.color)
                                Text(progression.displayName)
                                    .caption(color: progression.color)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(progression.color.opacity(0.15))
                            )
                        }
                    }

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(lastData.completedSetGroups) { setGroup in
                            if setGroup.isInterval {
                                // Show intervals as summary: "x rounds (y on/z off)"
                                previousIntervalRow(setGroup: setGroup, exercise: lastData)
                            } else {
                                ForEach(setGroup.sets) { set in
                                    previousSetRow(set: set, exercise: lastData)
                                }
                            }
                        }
                    }

                    // Show notes from last session if present
                    if let notes = lastData.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .caption(color: AppColors.textTertiary)
                                Text("Notes")
                                    .caption(color: AppColors.textTertiary)
                                    .fontWeight(.semibold)
                            }

                            Text(notes)
                                .caption(color: AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceTertiary.opacity(0.5))
                )
            }
        }
    }

    @ViewBuilder
    private func previousSetRow(set: SetData, exercise: SessionExercise) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Set number badge
            Text("\(set.setNumber)")
                .caption(color: AppColors.textTertiary)
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppColors.surfaceTertiary))

            // Metrics based on exercise type
            HStack(spacing: AppSpacing.sm) {
                switch exercise.exerciseType {
                case .strength:
                    // Check for string-based implement measurable (e.g., band color)
                    if let stringMeasurable = exercise.implementStringMeasurable {
                        if let bandColor = set.bandColor, !bandColor.isEmpty {
                            metricPill(value: bandColor, label: stringMeasurable.implementName.lowercased(), color: AppColors.accent3)
                        }
                        if let reps = set.reps {
                            metricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
                        }
                    } else if exercise.isBodyweight {
                        if let reps = set.reps {
                            if let weight = set.weight, weight > 0 {
                                metricPill(value: "BW+\(formatWeight(weight))", label: nil, color: AppColors.dominant)
                            } else {
                                metricPill(value: "BW", label: nil, color: AppColors.dominant)
                            }
                            metricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
                        }
                    } else {
                        if let weight = set.weight {
                            metricPill(value: formatWeight(weight), label: "lbs", color: AppColors.dominant)
                        }
                        if let reps = set.reps {
                            metricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
                        }
                    }
                    if let rpe = set.rpe {
                        metricPill(value: "\(rpe)", label: "RPE", color: AppColors.warning)
                    }

                case .isometric:
                    if let holdTime = set.holdTime {
                        metricPill(value: formatDuration(holdTime), label: "hold", color: AppColors.dominant)
                    }
                    if let intensity = set.intensity {
                        metricPill(value: "\(intensity)/10", label: nil, color: AppColors.warning)
                    }

                case .cardio:
                    if let duration = set.duration, duration > 0 {
                        metricPill(value: formatDuration(duration), label: "time", color: AppColors.dominant)
                    }
                    if let distance = set.distance, distance > 0 {
                        metricPill(value: formatDistanceValue(distance), label: exercise.distanceUnit.abbreviation, color: AppColors.accent1)
                    }

                case .explosive:
                    if let reps = set.reps {
                        metricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
                    }
                    if let height = set.height {
                        metricPill(value: formatHeight(height), label: nil, color: AppColors.dominant)
                    }

                case .mobility:
                    if let reps = set.reps {
                        metricPill(value: "\(reps)", label: "reps", color: AppColors.accent1)
                    }
                    if let duration = set.duration, duration > 0 {
                        metricPill(value: formatDuration(duration), label: nil, color: AppColors.dominant)
                    }

                case .recovery:
                    if let duration = set.duration {
                        metricPill(value: formatDuration(duration), label: nil, color: AppColors.dominant)
                    }
                    if let temp = set.temperature {
                        metricPill(value: "\(temp)°F", label: nil, color: AppColors.warning)
                    }
                }

                // Equipment measurables (e.g., box height, band weight, etc.)
                equipmentMeasurablesPills(set: set, exercise: exercise)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func formatMeasurableValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    @ViewBuilder
    private func equipmentMeasurablesPills(set: SetData, exercise: SessionExercise) -> some View {
        if !set.implementMeasurableValues.isEmpty {
            ForEach(Array(set.implementMeasurableValues.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                if let numericValue = value.numericValue {
                    metricPill(
                        value: formatMeasurableValue(numericValue),
                        label: key,
                        color: AppColors.accent3
                    )
                } else if let stringValue = value.stringValue {
                    metricPill(value: stringValue, label: key, color: AppColors.accent3)
                }
            }
        }
    }

    @ViewBuilder
    private func previousIntervalRow(setGroup: CompletedSetGroup, exercise: SessionExercise) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Interval icon
            Image(systemName: "timer")
                .caption(color: AppColors.warning)
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppColors.surfaceTertiary))

            // Interval summary: "x rounds (y on / z off)"
            HStack(spacing: AppSpacing.sm) {
                metricPill(
                    value: "\(setGroup.rounds)",
                    label: "rounds",
                    color: AppColors.warning
                )

                Text("(\(formatDuration(setGroup.workDuration ?? 0)) on / \(formatDuration(setGroup.intervalRestDuration ?? 0)) off)")
                    .caption(color: AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func metricPill(value: String, label: String?, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .subheadline(color: color)
                .fontWeight(.semibold)
            if let label = label {
                Text(label)
                    .caption2(color: AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Rest Timer Overlay

    // Long rest threshold (3 minutes) - show browse option
    private var isLongRest: Bool {
        sessionViewModel.restTimerTotal >= 180
    }

    private var restTimerBar: some View {
        let isUrgent = sessionViewModel.restTimerSeconds <= 10
        let isLongTimer = sessionViewModel.restTimerTotal >= 60
        let timeDisplay = isLongTimer ? formatTime(sessionViewModel.restTimerSeconds) : "\(sessionViewModel.restTimerSeconds)"
        let ringSize: CGFloat = isLongTimer ? 44 : 36
        let fontSize: CGFloat = isLongTimer ? 11 : 12

        return VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.surfaceTertiary, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: CGFloat(sessionViewModel.restTimerSeconds) / CGFloat(max(sessionViewModel.restTimerTotal, 1)))
                        .stroke(isUrgent ? AppColors.warning : AppColors.accent1, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: sessionViewModel.restTimerSeconds)

                    Text(timeDisplay)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppColors.textPrimary)
                        .minimumScaleFactor(0.7)
                }

                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest")
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.medium)
                    Text("\(timeDisplay) remaining")
                        .caption(color: AppColors.textTertiary)
                        .monospacedDigit()
                }

                Spacer()

                // X button (for long rests 3+ min)
                if isLongRest {
                    Button {
                        openTwitter()
                    } label: {
                        Text("𝕏")
                            .body(color: AppColors.textSecondary)
                            .fontWeight(.bold)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Browse X during rest")
                }

                // Skip button
                Button {
                    sessionViewModel.stopRestTimer()
                    highlightNextSet = true
                } label: {
                    Text("Skip")
                        .subheadline(color: AppColors.dominant)
                        .fontWeight(.semibold)
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(
                            Capsule()
                                .fill(AppColors.dominant.opacity(0.1))
                        )
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel("Skip rest timer")
            }

        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(
                            isUrgent ? AppColors.warning.opacity(0.4) : AppColors.accent1.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: isUrgent ? AppColors.warning.opacity(0.15) : .clear,
            radius: isUrgent ? 12 : 0,
            x: 0,
            y: 4
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: sessionViewModel.isRestTimerRunning)
    }

    // MARK: - Module Transition Overlay

    private var moduleTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                // Completed module
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .displayMedium(color: AppColors.success)

                    Text(completedModuleName)
                        .headline(color: AppColors.textSecondary)
                }
                .opacity(0.6)

                // Arrow
                Image(systemName: "arrow.down")
                    .displaySmall(color: AppColors.textTertiary)
                    .fontWeight(.light)

                // Next module
                VStack(spacing: AppSpacing.sm) {
                    Text(nextModuleName)
                        .displayMedium(color: AppColors.textPrimary)
                }
            }
            .padding(AppSpacing.xl)
        }
        .transition(.opacity)
    }

    // MARK: - Workout Complete Overlay

    private var workoutCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Animated checkmark
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(AppColors.success.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)

                    // Inner fill
                    Circle()
                        .fill(AppColors.success.opacity(0.15))
                        .frame(width: 120, height: 120)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .displayLarge(color: AppColors.success)
                        .scaleEffect(checkScale)
                }

                // Stats summary
                if let session = sessionViewModel.currentSession {
                    VStack(spacing: AppSpacing.lg) {
                        Text(session.workoutName)
                            .displayMedium(color: AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xl) {
                            statItem(value: formatTime(sessionViewModel.sessionElapsedSeconds), label: "Time")
                            statItem(value: "\(session.totalSetsCompleted)", label: "Sets")
                            statItem(value: "\(session.totalExercisesCompleted)", label: "Exercises")
                        }
                    }
                    .opacity(statsOpacity)
                }

                Spacer()

                // Finish button
                Button {
                    showingWorkoutSummary = true
                } label: {
                    Text("Finish")
                        .headline(color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppGradients.dominantGradient)
                        )
                }
                .padding(.horizontal, AppSpacing.xl)
                .opacity(statsOpacity)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .onAppear {
            // Animate in sequence
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                checkScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                ringScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                statsOpacity = 1.0
            }
        }
        .transition(.opacity)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .displayMedium(color: AppColors.textPrimary)
            Text(label)
                .caption(color: AppColors.textTertiary)
        }
    }

    // MARK: - External App Links

    private func openTwitter() {
        // Try to open X/Twitter app first, fall back to web
        guard let twitterAppURL = URL(string: "twitter://"),
              let twitterWebURL = URL(string: "https://x.com") else { return }

        if UIApplication.shared.canOpenURL(twitterAppURL) {
            UIApplication.shared.open(twitterAppURL)
        } else {
            UIApplication.shared.open(twitterWebURL)
        }
    }

    // MARK: - Workout Complete View (fallback)

    private var workoutCompleteView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .displayLarge(color: AppColors.success)
            }

            Text("Done")
                .displayMedium(color: AppColors.textPrimary)

            Spacer()
        }
        .padding(AppSpacing.xl)
    }
}


#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
