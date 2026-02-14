//
//  ActiveSessionView.swift
//  gym app
//
//  Main view for logging an active workout session
//
//  This file has been refactored to use extracted components:
//  - SessionHeaderView.swift - Header with progress ring
//  - SetListSection.swift - All sets display
//  - PreviousPerformanceSection.swift - Previous workout data
//  - RestTimerBar.swift - Rest timer inline view
//  - SessionCompleteOverlay.swift - Workout complete animation
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
    @State private var showWorkoutOverview = false
    @State private var showEditExercise = false
    @State private var showIntervalTimer = false
    @State private var intervalSetGroupIndex: Int = 0
    @State private var highlightNextSet = false

    // Structural change review state
    @State private var pendingStructuralChanges: [StructuralChange] = []
    @State private var showingReviewChanges = false
    @State private var pendingFeeling: Int?
    @State private var pendingNotes: String?

    // Freestyle mode state
    @State private var showFreestyleAddExercise = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Header
                    SessionProgressHeader(showWorkoutOverview: $showWorkoutOverview)

                    // Main Content
                    if let currentModule = sessionViewModel.currentModule,
                       let currentExercise = sessionViewModel.currentExercise {

                        GeometryReader { geometry in
                            let contentWidth = geometry.size.width - (AppSpacing.screenPadding * 2)
                            ScrollView {
                                VStack(spacing: AppSpacing.lg) {
                                    // Module indicator
                                    ModuleIndicator(module: currentModule, onSkip: {
                                        sessionViewModel.skipModule()
                                    })

                                    // Exercise Card header
                                    ExerciseCard(
                                        exercise: currentExercise,
                                        supersetPosition: sessionViewModel.supersetPosition,
                                        supersetTotal: sessionViewModel.supersetTotal,
                                        supersetExercises: sessionViewModel.currentSupersetExercises,
                                        canGoBack: canGoBack,
                                        onEdit: { showEditExercise = true },
                                        onBack: { goToPreviousExerciseSuperset() },
                                        onSkip: { skipToNextExerciseSuperset() },
                                        onNotesChange: { notes in
                                            sessionViewModel.updateExerciseNotes(
                                                moduleIndex: sessionViewModel.currentModuleIndex,
                                                exerciseIndex: sessionViewModel.currentExerciseIndex,
                                                notes: notes
                                            )
                                        }
                                    )

                                    // All Sets (expandable rows) - pass fixed width to prevent layout shifts
                                    AllSetsSection(
                                        exercise: currentExercise,
                                        width: contentWidth,
                                        highlightNextSet: highlightNextSet,
                                        isLastExercise: isLastExercise,
                                        onLogSet: { flatSet, weight, reps, rpe, duration, holdTime, distance, height, intensity, temperature, bandColor, implementMeasurableValues in
                                            logSetAt(flatSet: flatSet, weight: weight, reps: reps, rpe: rpe, duration: duration, holdTime: holdTime, distance: distance, height: height, intensity: intensity, temperature: temperature, bandColor: bandColor, implementMeasurableValues: implementMeasurableValues)
                                        },
                                        onDeleteSet: { flatSet in deleteSetAt(flatSet: flatSet) },
                                        onUncheckSet: { flatSet in uncheckSetAt(flatSet: flatSet) },
                                        onAddSet: { addSetToCurrentExercise() },
                                        onAdvanceToNextExercise: {
                                            highlightNextSet = true
                                            advanceToNextExercise()
                                        },
                                        onStartIntervalTimer: { groupIndex in
                                            startIntervalTimer(setGroupIndex: groupIndex)
                                        },
                                        onDistanceUnitChange: { newUnit in
                                            sessionViewModel.updateExerciseDistanceUnit(
                                                moduleIndex: sessionViewModel.currentModuleIndex,
                                                exerciseIndex: sessionViewModel.currentExerciseIndex,
                                                unit: newUnit
                                            )
                                        },
                                        onProgressionUpdate: { exercise, recommendation in
                                            updateExerciseProgression(exercise: exercise, recommendation: recommendation)
                                        },
                                        onHighlightClear: { highlightNextSet = false }
                                    )

                                    // Rest Timer (inline)
                                    if sessionViewModel.isRestTimerRunning {
                                        RestTimerBar(highlightNextSet: $highlightNextSet)
                                    }

                                    // Previous Performance
                                    PreviousPerformanceSection(
                                        exerciseName: currentExercise.exerciseName,
                                        lastData: sessionViewModel.getLastSessionData(for: currentExercise.exerciseName),
                                        fromSameWorkout: sessionViewModel.isLastSessionDataFromSameWorkout(for: currentExercise.exerciseName)
                                    )
                                }
                                .padding(AppSpacing.screenPadding)
                                .frame(width: geometry.size.width)
                            }
                        }
                    } else if sessionViewModel.currentSession?.isFreestyle == true &&
                              sessionViewModel.currentSession?.completedModules.isEmpty == true {
                        // Freestyle empty state
                        freestyleEmptyState
                    } else {
                        // Workout complete
                        WorkoutCompleteView()
                    }
                }

                // Module Transition Overlay
                if showModuleTransition {
                    ModuleTransitionOverlay(
                        completedModuleName: completedModuleName,
                        nextModuleName: nextModuleName
                    )
                }

                // Workout Complete Overlay
                if showWorkoutComplete {
                    WorkoutCompleteOverlay(showingWorkoutSummary: $showingWorkoutSummary)
                }

                // Freestyle FAB - floating action button to add exercises
                if sessionViewModel.currentSession?.isFreestyle == true {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                HapticManager.shared.tap()
                                showFreestyleAddExercise = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(AppGradients.dominantGradient)
                                            .shadow(color: AppColors.dominant.opacity(0.3), radius: 8, y: 4)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(AppSpacing.lg)
                            .padding(.bottom, AppSpacing.xxl) // Clear bottom toolbar
                        }
                    }
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
                if sessionViewModel.shouldAutoShowWorkoutOverview() {
                    sessionViewModel.markWorkoutOverviewShown()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showWorkoutOverview = true
                    }
                }

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
                            showingWorkoutSummary = false
                            // Check for structural changes before finalizing
                            checkAndHandleStructuralChanges(feeling: feeling, notes: notes)
                        }
                    )
                    .environmentObject(sessionViewModel)
                }
            }
            .sheet(isPresented: $showingEndConfirmation) {
                EndSessionSheet(session: $sessionViewModel.currentSession) { feeling, notes in
                    showingEndConfirmation = false
                    // Check for structural changes before finalizing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        checkAndHandleStructuralChanges(feeling: feeling, notes: notes)
                    }
                }
            }
            .sheet(isPresented: $showingReviewChanges) {
                ReviewChangesView(
                    changes: pendingStructuralChanges,
                    onCommit: { selectedChanges in
                        // Commit selected changes to module templates
                        sessionViewModel.commitStructuralChanges(selectedChanges)
                        // Now finalize the session
                        finalizeSession()
                    },
                    onDiscard: {
                        // User chose to discard all changes - just save the session
                        finalizeSession()
                    }
                )
            }
            .sheet(isPresented: $showEditExercise) {
                if let exercise = sessionViewModel.currentExercise {
                    NavigationStack {
                        ExerciseFormView(
                            instance: nil,
                            moduleId: UUID(),
                            sessionExercise: exercise,
                            sessionModuleIndex: sessionViewModel.currentModuleIndex,
                            sessionExerciseIndex: sessionViewModel.currentExerciseIndex,
                            onSessionSave: { moduleIndex, exerciseIndex, updatedExercise in
                                updateExerciseAt(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, exercise: updatedExercise)
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $showFreestyleAddExercise) {
                FreestyleAddExerciseSheet()
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

    // MARK: - Navigation Helpers

    private var isLastExercise: Bool {
        guard let session = sessionViewModel.currentSession else { return true }
        let lastModuleIndex = session.completedModules.count - 1
        guard sessionViewModel.currentModuleIndex == lastModuleIndex else { return false }
        guard sessionViewModel.currentModuleIndex < session.completedModules.count else { return true }
        let module = session.completedModules[sessionViewModel.currentModuleIndex]
        return sessionViewModel.currentExerciseIndex == module.completedExercises.count - 1
    }

    // MARK: - Freestyle Empty State

    private var freestyleEmptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("Add your first exercise")
                .headline(color: AppColors.textSecondary)

            Text("Tap + to start building your workout")
                .caption(color: AppColors.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var canGoBack: Bool {
        // Can go back if not at the very first exercise of the first module
        sessionViewModel.currentModuleIndex > 0 || sessionViewModel.currentExerciseIndex > 0
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

        // Check if there's an existing set group with sets to copy from
        if let lastSetGroup = exercise.completedSetGroups.last,
           !lastSetGroup.sets.isEmpty {

            var updatedSetGroup = lastSetGroup

            if lastSetGroup.isUnilateral {
                // For unilateral: logical set count is half the SetData count
                let newSetNumber = (lastSetGroup.sets.count / 2) + 1

                // Find last left and right sets to copy targets from
                let lastLeftSet = lastSetGroup.sets.last(where: { $0.side == .left })
                let lastRightSet = lastSetGroup.sets.last(where: { $0.side == .right })

                let newLeftSet = SetData(
                    setNumber: newSetNumber,
                    weight: lastLeftSet?.weight,
                    reps: lastLeftSet?.reps,
                    completed: false,
                    duration: lastLeftSet?.duration,
                    distance: lastLeftSet?.distance,
                    holdTime: lastLeftSet?.holdTime,
                    side: .left
                )
                let newRightSet = SetData(
                    setNumber: newSetNumber,
                    weight: lastRightSet?.weight,
                    reps: lastRightSet?.reps,
                    completed: false,
                    duration: lastRightSet?.duration,
                    distance: lastRightSet?.distance,
                    holdTime: lastRightSet?.holdTime,
                    side: .right
                )

                updatedSetGroup.sets.append(newLeftSet)
                updatedSetGroup.sets.append(newRightSet)
            } else {
                let newSetNumber = lastSetGroup.sets.count + 1
                let lastSet = lastSetGroup.sets.last!

                let newSet = SetData(
                    setNumber: newSetNumber,
                    weight: lastSet.weight,
                    reps: lastSet.reps,
                    completed: false,
                    duration: lastSet.duration,
                    distance: lastSet.distance,
                    holdTime: lastSet.holdTime
                )
                updatedSetGroup.sets.append(newSet)
            }

            exercise.completedSetGroups[exercise.completedSetGroups.count - 1] = updatedSetGroup
        } else {
            // No existing sets - create a new set group with default values
            let newSet = SetData(
                setNumber: 1,
                completed: false
            )
            let newSetGroup = CompletedSetGroup(
                setGroupId: UUID(),
                sets: [newSet]
            )
            exercise.completedSetGroups.append(newSetGroup)
        }

        module.completedExercises[sessionViewModel.currentExerciseIndex] = exercise
        session.completedModules[sessionViewModel.currentModuleIndex] = module

        sessionViewModel.currentSession = session

        // Refresh the navigator so it sees the new set
        sessionViewModel.refreshNavigator()
    }

    // MARK: - Delete Set

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

        // Remove the set (for unilateral, remove the entire L/R pair)
        if setGroup.isUnilateral {
            let targetSetNumber = setGroup.sets[flatSet.setIndex].setNumber
            setGroup.sets.removeAll { $0.setNumber == targetSetNumber }
        } else {
            setGroup.sets.remove(at: flatSet.setIndex)
        }

        // If the set group is now empty, remove it too
        if setGroup.sets.isEmpty {
            exercise.completedSetGroups.remove(at: flatSet.setGroupIndex)
        } else {
            // Update set numbers for remaining sets
            if setGroup.isUnilateral {
                // Assign paired numbers for unilateral sets
                var pairNumber = 1
                for i in stride(from: 0, to: setGroup.sets.count, by: 2) {
                    setGroup.sets[i].setNumber = pairNumber
                    if i + 1 < setGroup.sets.count {
                        setGroup.sets[i + 1].setNumber = pairNumber
                    }
                    pairNumber += 1
                }
            } else {
                for i in 0..<setGroup.sets.count {
                    setGroup.sets[i].setNumber = i + 1
                }
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

        // Trigger auto-save to persist the changes
        sessionViewModel.triggerAutoSave()

        // Refresh the navigator so it sees the updated structure
        sessionViewModel.refreshNavigator()

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

    // MARK: - Structural Change Review

    /// Check for structural changes and either show review sheet or finalize directly
    private func checkAndHandleStructuralChanges(feeling: Int?, notes: String?) {
        // Store pending session data
        pendingFeeling = feeling
        pendingNotes = notes

        // Detect structural changes
        let changes = sessionViewModel.detectStructuralChanges()

        if changes.isEmpty {
            // No changes, finalize directly
            finalizeSession()
        } else {
            // Show review sheet for user to select which changes to commit
            pendingStructuralChanges = changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingReviewChanges = true
            }
        }
    }

    /// Finalize the session (save and dismiss)
    private func finalizeSession() {
        if let session = sessionViewModel.currentSession {
            workoutViewModel.markScheduledWorkoutsCompleted(
                workoutId: session.workoutId,
                sessionId: session.id,
                sessionDate: session.date
            )
        }
        sessionViewModel.endSession(feeling: pendingFeeling, notes: pendingNotes)

        // Clear pending state
        pendingFeeling = nil
        pendingNotes = nil
        pendingStructuralChanges = []

        dismiss()
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

        // Refresh the navigator so it sees the new exercise
        sessionViewModel.refreshNavigator()
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

    private func allSetsCompleted(_ exercise: SessionExercise) -> Bool {
        exercise.completedSetGroups.allSatisfy { group in
            group.sets.allSatisfy { $0.completed }
        }
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

    private func updateExerciseProgression(exercise: SessionExercise, recommendation: ProgressionRecommendation) {
        sessionViewModel.updateExerciseProgression(
            moduleIndex: sessionViewModel.currentModuleIndex,
            exerciseIndex: sessionViewModel.currentExerciseIndex,
            recommendation: exercise.progressionRecommendation == recommendation ? nil : recommendation
        )
    }
}


#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
