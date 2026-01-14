//
//  ActiveSessionView.swift
//  gym app
//
//  Main view for logging an active workout session
//

import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

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
    @State private var showRecentSets = false
    @State private var showWorkoutOverview = false
    @State private var showSubstituteExercise = false
    @State private var showIntervalTimer = false
    @State private var intervalSetGroupIndex: Int = 0

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

                        ScrollView {
                            VStack(spacing: AppSpacing.lg) {
                                // Module indicator
                                moduleIndicator(currentModule)

                                // Exercise Card header
                                exerciseCard(currentExercise)

                                // All Sets (expandable rows)
                                allSetsSection

                                // Rest Timer (inline)
                                if sessionViewModel.isRestTimerRunning {
                                    restTimerBar
                                }

                                // Previous Performance
                                previousPerformanceSection(exerciseName: currentExercise.exerciseName)
                            }
                            .padding(AppSpacing.screenPadding)
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
                            showingEndConfirmation = true
                        }
                        .foregroundColor(AppColors.accentBlue)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showWorkoutOverview = true
                            } label: {
                                Label("Overview", systemImage: "list.bullet")
                            }

                            Button {
                                showingEndConfirmation = true
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
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary)
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
            .confirmationDialog("Cancel Workout", isPresented: $showingCancelConfirmation) {
                Button("Cancel Workout", role: .destructive) {
                    sessionViewModel.cancelSession()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to cancel? Your progress will not be saved.")
            }
            .sheet(isPresented: $showingEndConfirmation) {
                EndSessionSheet { feeling, notes in
                    sessionViewModel.endSession(feeling: feeling, notes: notes)
                    dismiss()
                }
            }
            .sheet(isPresented: $showRecentSets) {
                RecentSetsSheet(
                    recentSets: getRecentSets(limit: 5),
                    onUpdate: { recentSet, weight, reps, rpe, duration, holdTime, distance in
                        updateRecentSet(recentSet, weight: weight, reps: reps, rpe: rpe, duration: duration, holdTime: holdTime, distance: distance)
                    }
                )
            }
            .sheet(isPresented: $showSubstituteExercise) {
                SubstituteExerciseSheet(
                    currentExercise: sessionViewModel.currentExercise,
                    onSubstitute: { name, type, cardioMetric, distanceUnit in
                        substituteCurrentExercise(name: name, type: type, cardioMetric: cardioMetric, distanceUnit: distanceUnit)
                        showSubstituteExercise = false
                    }
                )
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
                    session: sessionViewModel.currentSession,
                    currentModuleIndex: sessionViewModel.currentModuleIndex,
                    currentExerciseIndex: sessionViewModel.currentExerciseIndex,
                    onJumpTo: { moduleIndex, exerciseIndex in
                        sessionViewModel.currentModuleIndex = moduleIndex
                        sessionViewModel.currentExerciseIndex = exerciseIndex
                        sessionViewModel.currentSetGroupIndex = 0
                        sessionViewModel.currentSetIndex = 0
                        showWorkoutOverview = false
                    },
                    onUpdateSet: { moduleIndex, exerciseIndex, setGroupIndex, setIndex, weight, reps, rpe, duration, holdTime, distance in
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
                            distance: distance
                        )
                    },
                    onAddExercise: { moduleIndex, name, type, cardioMetric, distanceUnit in
                        addExerciseToModule(moduleIndex: moduleIndex, name: name, type: type, cardioMetric: cardioMetric, distanceUnit: distanceUnit)
                    }
                )
            }
        }
    }

    // MARK: - Progress Header (Subtle)

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
                        .fill(AppColors.accentTeal)
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(height: 3)
                .background(AppColors.border.opacity(0.3))
            }

            // Compact info row
            HStack {
                // Timer - subtle
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Module progress - subtle
                if let session = sessionViewModel.currentSession {
                    Text("\(sessionViewModel.currentModuleIndex + 1)/\(session.completedModules.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.cardBackground.opacity(0.5))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.moduleColor(module.moduleType))

            Text(module.moduleName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button {
                sessionViewModel.skipModule()
            } label: {
                Text("Skip")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
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
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("SUPERSET \(position)/\(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)

                    Spacer()

                    // Show next exercise in superset
                    if let supersetExercises = sessionViewModel.currentSupersetExercises,
                       position < total {
                        Text("Next: \(supersetExercises[position].exerciseName)")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(exercise.exerciseName)
                        .font(.title2.bold())
                        .foregroundColor(AppColors.textPrimary)

                    Text(exerciseSetsSummary(exercise))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                HStack(spacing: AppSpacing.sm) {
                    // Substitute button
                    Button {
                        showSubstituteExercise = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceLight)
                            )
                    }

                    // Back button (if not first exercise)
                    if canGoBack {
                        Button {
                            goToPreviousExercise()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(AppColors.surfaceLight)
                                )
                        }
                    }

                    // Skip button
                    Button {
                        sessionViewModel.skipExercise()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceLight)
                            )
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
        )
    }

    private func exerciseSetsSummary(_ exercise: SessionExercise) -> String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedCount = exercise.completedSetGroups.reduce(0) { groupSum, group in
            groupSum + group.sets.filter { $0.completed }.count
        }
        return "\(completedCount)/\(totalSets) sets completed"
    }

    // MARK: - All Sets Section

    @State private var expandedSetId: String? = nil

    private var allSetsSection: some View {
        VStack(spacing: AppSpacing.md) {
            if let exercise = sessionViewModel.currentExercise {
                // Recent sets button (if any completed sets exist)
                if hasRecentSets {
                    HStack {
                        Spacer()
                        Button {
                            showRecentSets = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("Recent")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppColors.surfaceLight)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Check for interval set groups
                ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.element.id) { groupIndex, setGroup in
                    if setGroup.isInterval {
                        // Interval set group - show special UI
                        intervalSetGroupRow(setGroup: setGroup, groupIndex: groupIndex)
                    } else {
                        // Regular sets
                        ForEach(flattenedSetsForGroup(exercise: exercise, groupIndex: groupIndex), id: \.id) { flatSet in
                            SetRowView(
                                flatSet: flatSet,
                                exercise: exercise,
                                isExpanded: expandedSetId == flatSet.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedSetId == flatSet.id {
                                            expandedSetId = nil
                                        } else {
                                            expandedSetId = flatSet.id
                                        }
                                    }
                                },
                                onLog: { weight, reps, rpe, duration, holdTime, distance in
                                    logSetAt(flatSet: flatSet, weight: weight, reps: reps, rpe: rpe, duration: duration, holdTime: holdTime, distance: distance)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedSetId = nil
                                    }
                                    // Start rest timer
                                    let restPeriod = flatSet.restPeriod ?? appState.defaultRestTime
                                    if !allSetsCompleted(exercise) {
                                        sessionViewModel.startRestTimer(seconds: restPeriod)
                                    }
                                }
                            )
                        }
                    }
                }

                // Add Set button
                Button {
                    addSetToCurrentExercise()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add Set")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.small)
                            .stroke(AppColors.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(.plain)

                // Next Exercise button
                Button {
                    advanceToNextExercise()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: isLastExercise ? "checkmark.circle.fill" : "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isLastExercise ? "Complete Workout" : "Next Exercise")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(allSetsCompleted(exercise) ? AppGradients.accentGradient : LinearGradient(colors: [AppColors.textTertiary], startPoint: .leading, endPoint: .trailing))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Interval Set Group Row

    private func intervalSetGroupRow(setGroup: CompletedSetGroup, groupIndex: Int) -> some View {
        let allCompleted = setGroup.sets.allSatisfy { $0.completed }
        let completedCount = setGroup.sets.filter { $0.completed }.count

        return VStack(spacing: AppSpacing.md) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interval")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(setGroup.rounds) rounds: \(formatDuration(setGroup.workDuration ?? 30)) on / \(formatDuration(setGroup.intervalRestDuration ?? 30)) off")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if allCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.success)
                } else if completedCount > 0 {
                    Text("\(completedCount)/\(setGroup.rounds)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // Start button or completion summary
            if allCompleted {
                // Show completed rounds summary
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(setGroup.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Round \(index + 1)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)

                            Spacer()

                            if let duration = set.duration {
                                Text(formatDuration(duration))
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.success)
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
                            .font(.system(size: 14))
                        Text("Start Interval")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
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
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(allCompleted ? AppColors.success.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }

    // Uses FlatSet defined in SessionModels

    private func flattenedSetsForGroup(exercise: SessionExercise, groupIndex: Int) -> [FlatSet] {
        guard groupIndex < exercise.completedSetGroups.count else { return [] }
        let setGroup = exercise.completedSetGroups[groupIndex]

        // Calculate running set number by counting sets in previous groups
        var runningSetNumber = 1
        for i in 0..<groupIndex {
            runningSetNumber += exercise.completedSetGroups[i].sets.count
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
                restPeriod: setGroup.restPeriod
            ))
            runningSetNumber += 1
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
                    restPeriod: setGroup.restPeriod
                ))
                runningSetNumber += 1
            }
        }
        return result
    }

    private func allSetsCompleted(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.allSatisfy { group in
            group.sets.allSatisfy { $0.completed }
        }
    }

    private var isLastExercise: Bool {
        guard let session = sessionViewModel.currentSession else { return true }
        let lastModuleIndex = session.completedModules.count - 1
        guard sessionViewModel.currentModuleIndex == lastModuleIndex else { return false }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]
        return sessionViewModel.currentExerciseIndex == module.completedExercises.count - 1
    }

    private var canGoBack: Bool {
        // Can go back if not at the very first exercise of the first module
        sessionViewModel.currentModuleIndex > 0 || sessionViewModel.currentExerciseIndex > 0
    }

    private func goToPreviousExercise() {
        if sessionViewModel.currentExerciseIndex > 0 {
            // Go to previous exercise in same module
            sessionViewModel.currentExerciseIndex -= 1
            sessionViewModel.currentSetGroupIndex = 0
            sessionViewModel.currentSetIndex = 0
        } else if sessionViewModel.currentModuleIndex > 0 {
            // Go to last exercise of previous module
            sessionViewModel.currentModuleIndex -= 1
            if let session = sessionViewModel.currentSession {
                let previousModule = session.completedModules[sessionViewModel.currentModuleIndex]
                sessionViewModel.currentExerciseIndex = previousModule.completedExercises.count - 1
                sessionViewModel.currentSetGroupIndex = 0
                sessionViewModel.currentSetIndex = 0
            }
        }
    }

    // MARK: - Add Set

    private func addSetToCurrentExercise() {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
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
    }

    // MARK: - Substitute Exercise

    private func substituteCurrentExercise(name: String, type: ExerciseType, cardioMetric: CardioMetric, distanceUnit: DistanceUnit) {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]

        // Store original name if not already a substitution
        let originalName = exercise.isSubstitution ? exercise.originalExerciseName : exercise.exerciseName

        // Update exercise with new info
        exercise.originalExerciseName = originalName
        exercise.isSubstitution = true
        exercise.exerciseName = name
        exercise.exerciseType = type
        exercise.cardioMetric = cardioMetric
        exercise.distanceUnit = distanceUnit

        // If exercise type changed, we may need to adjust set data structure
        // For now, keep the same sets but they'll need different inputs

        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session
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

    // MARK: - Recent Sets

    private var hasRecentSets: Bool {
        !getRecentSets(limit: 1).isEmpty
    }

    private func getRecentSets(limit: Int = 5) -> [RecentSet] {
        guard let session = sessionViewModel.currentSession else { return [] }
        var recentSets: [RecentSet] = []

        // Iterate through all completed sets in reverse order (most recent first)
        for (moduleIndex, module) in session.completedModules.enumerated().reversed() {
            for (exerciseIndex, exercise) in module.completedExercises.enumerated().reversed() {
                for (setGroupIndex, setGroup) in exercise.completedSetGroups.enumerated().reversed() {
                    for (setIndex, setData) in setGroup.sets.enumerated().reversed() {
                        if setData.completed {
                            recentSets.append(RecentSet(
                                moduleIndex: moduleIndex,
                                exerciseIndex: exerciseIndex,
                                setGroupIndex: setGroupIndex,
                                setIndex: setIndex,
                                exerciseName: exercise.exerciseName,
                                exerciseType: exercise.exerciseType,
                                setData: setData
                            ))
                            if recentSets.count >= limit {
                                return recentSets
                            }
                        }
                    }
                }
            }
        }
        return recentSets
    }

    private func updateRecentSet(_ recentSet: RecentSet, weight: Double?, reps: Int?, rpe: Int?, duration: Int?, holdTime: Int?, distance: Double?) {
        updateSetAt(
            moduleIndex: recentSet.moduleIndex,
            exerciseIndex: recentSet.exerciseIndex,
            setGroupIndex: recentSet.setGroupIndex,
            setIndex: recentSet.setIndex,
            weight: weight,
            reps: reps,
            rpe: rpe,
            duration: duration,
            holdTime: holdTime,
            distance: distance
        )
    }

    private func updateSetAt(moduleIndex: Int, exerciseIndex: Int, setGroupIndex: Int, setIndex: Int, weight: Double?, reps: Int?, rpe: Int?, duration: Int?, holdTime: Int?, distance: Double?, completed: Bool? = nil) {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[moduleIndex]
        var exercise = module.completedExercises[exerciseIndex]
        var setGroup = exercise.completedSetGroups[setGroupIndex]
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

    private func logSetAt(flatSet: FlatSet, weight: Double?, reps: Int?, rpe: Int?, duration: Int?, holdTime: Int?, distance: Double?) {
        guard var session = sessionViewModel.currentSession else { return }

        var module = session.completedModules[sessionViewModel.currentModuleIndex]
        var exercise = module.completedExercises[sessionViewModel.currentExerciseIndex]
        var setGroup = exercise.completedSetGroups[flatSet.setGroupIndex]
        var setData = setGroup.sets[flatSet.setIndex]

        setData.weight = weight ?? setData.weight
        setData.reps = reps ?? setData.reps
        setData.rpe = rpe
        setData.duration = duration ?? setData.duration
        setData.holdTime = holdTime ?? setData.holdTime
        setData.distance = distance ?? setData.distance
        setData.completed = true

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
                sessionViewModel.currentExerciseIndex = supersetIndices[currentPos + 1]
                sessionViewModel.currentSetGroupIndex = 0
                sessionViewModel.currentSetIndex = 0
                return
            }
        }

        // Normal advance
        if sessionViewModel.currentExerciseIndex < module.completedExercises.count - 1 {
            // Next exercise in same module
            sessionViewModel.currentExerciseIndex += 1
            sessionViewModel.currentSetGroupIndex = 0
            sessionViewModel.currentSetIndex = 0
        } else if sessionViewModel.currentModuleIndex < session.completedModules.count - 1 {
            // Moving to next module - show transition
            let currentModuleName = module.moduleName
            let nextModule = session.completedModules[sessionViewModel.currentModuleIndex + 1]
            showModuleTransitionAnimation(from: currentModuleName, to: nextModule.moduleName) {
                sessionViewModel.currentModuleIndex += 1
                sessionViewModel.currentExerciseIndex = 0
                sessionViewModel.currentSetGroupIndex = 0
                sessionViewModel.currentSetIndex = 0
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
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Last Session")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(lastData.completedSetGroups) { setGroup in
                            ForEach(setGroup.sets) { set in
                                if let formatted = set.formattedStrength ?? set.formattedIsometric ?? set.formattedCardio {
                                    HStack {
                                        Text("Set \(set.setNumber)")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary)
                                            .frame(width: 50, alignment: .leading)

                                        Text(formatted)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppColors.textSecondary)

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceLight.opacity(0.5))
                )
            }
        }
    }

    // MARK: - Rest Timer Overlay

    private var restTimerBar: some View {
        HStack(spacing: AppSpacing.md) {
            // Progress ring (small)
            ZStack {
                Circle()
                    .stroke(AppColors.surfaceLight, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(sessionViewModel.restTimerSeconds) / CGFloat(max(sessionViewModel.restTimerTotal, 1)))
                    .stroke(AppColors.accentTeal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(sessionViewModel.restTimerSeconds)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(sessionViewModel.restTimerSeconds)s remaining")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Skip button
            Button {
                sessionViewModel.stopRestTimer()
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.accentBlue)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(AppColors.accentBlue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.accentTeal.opacity(0.3), lineWidth: 1)
                )
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
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.success)

                    Text(completedModuleName)
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .opacity(0.6)

                // Arrow
                Image(systemName: "arrow.down")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(AppColors.textTertiary)

                // Next module
                VStack(spacing: AppSpacing.sm) {
                    Text(nextModuleName)
                        .font(.title2.bold())
                        .foregroundColor(AppColors.textPrimary)
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
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(AppColors.success)
                        .scaleEffect(checkScale)
                }

                // Stats summary
                if let session = sessionViewModel.currentSession {
                    VStack(spacing: AppSpacing.lg) {
                        Text(session.workoutName)
                            .font(.title2.bold())
                            .foregroundColor(AppColors.textPrimary)

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
                    showingEndConfirmation = true
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppGradients.accentGradient)
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
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
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
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppColors.success)
            }

            Text("Done")
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    // MARK: - Helper Functions

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}


#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
