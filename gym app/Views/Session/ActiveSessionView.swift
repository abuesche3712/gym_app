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

                                // Previous Performance
                                previousPerformanceSection(exerciseName: currentExercise.exerciseName)
                            }
                            .padding(AppSpacing.screenPadding)
                        }
                    } else {
                        // Workout complete
                        workoutCompleteView
                    }

                    // Rest Timer Overlay
                    if sessionViewModel.isRestTimerRunning {
                        restTimerOverlay
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
                // All sets list
                ForEach(flattenedSets(exercise), id: \.id) { flatSet in
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

    // Uses FlatSet defined below

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

    private var restTimerOverlay: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Text("REST")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(2)

                SetTimerRing(
                    timeRemaining: sessionViewModel.restTimerSeconds,
                    totalTime: sessionViewModel.restTimerTotal,
                    size: 120,
                    isActive: true
                )

                Button {
                    sessionViewModel.stopRestTimer()
                } label: {
                    Text("Skip Rest")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .padding(AppSpacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCorners.xl))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
        .transition(.opacity)
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

// MARK: - Set Indicator

struct SetIndicator: View {
    let setNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    var restTime: Int = 90

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.success)
            } else {
                Text("\(setNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCurrent ? AppColors.accentBlue : AppColors.textTertiary)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent ? AppColors.accentBlue : .clear, lineWidth: 2)
        )
        .animation(AppAnimation.quick, value: isCompleted)
        .animation(AppAnimation.quick, value: isCurrent)
    }

    private var backgroundColor: Color {
        if isCompleted {
            return AppColors.success.opacity(0.15)
        } else if isCurrent {
            return AppColors.accentBlue.opacity(0.15)
        } else {
            return AppColors.surfaceLight
        }
    }
}

// MARK: - End Session Sheet

struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Int?, String?) -> Void

    @State private var feeling: Int = 3
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                // Feeling picker
                VStack(spacing: AppSpacing.md) {
                    Text("How did you feel?")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.md) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                withAnimation(AppAnimation.quick) {
                                    feeling = value
                                }
                            } label: {
                                VStack(spacing: AppSpacing.xs) {
                                    Text(feelingEmoji(value))
                                        .font(.system(size: 36))
                                    Text("\(value)")
                                        .font(.caption)
                                        .foregroundColor(feeling == value ? AppColors.textPrimary : AppColors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCorners.medium)
                                        .fill(feeling == value ? AppColors.accentBlue.opacity(0.2) : AppColors.surfaceLight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                                .stroke(feeling == value ? AppColors.accentBlue : .clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Notes (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextEditor(text: $notes)
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.md)
                        .frame(minHeight: 100)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.surfaceLight)
                        )
                }

                Spacer()
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(feeling, notes.isEmpty ? nil : notes)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "💪"
        default: return "😐"
        }
    }
}

// MARK: - Flat Set (helper struct)

struct FlatSet: Identifiable {
    let id: String
    let setGroupIndex: Int
    let setIndex: Int
    let setNumber: Int
    let setData: SetData
    let targetWeight: Double?
    let targetReps: Int?
    let targetDuration: Int?
    let targetHoldTime: Int?
    let targetDistance: Double?
    let restPeriod: Int?
}

// MARK: - Set Row View (Expandable)

struct SetRowView: View {
    let flatSet: FlatSet
    let exercise: SessionExercise
    let isExpanded: Bool
    let onTap: () -> Void
    let onLog: (Double?, Int?, Int?, Int?, Int?, Double?) -> Void

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed row - always visible
            Button(action: onTap) {
                HStack(spacing: AppSpacing.md) {
                    // Set number indicator
                    ZStack {
                        Circle()
                            .fill(flatSet.setData.completed ? AppColors.success.opacity(0.15) : AppColors.surfaceLight)
                            .frame(width: 36, height: 36)

                        if flatSet.setData.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.success)
                        } else {
                            Text("\(flatSet.setNumber)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Set info
                    VStack(alignment: .leading, spacing: 2) {
                        if flatSet.setData.completed {
                            Text(completedSummary)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                        } else {
                            Text(targetSummary)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Expand indicator
                    if !flatSet.setData.completed {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(flatSet.setData.completed ? AppColors.success.opacity(0.05) : (isExpanded ? AppColors.accentBlue.opacity(0.05) : AppColors.surfaceLight))
                )
            }
            .buttonStyle(.plain)
            .disabled(flatSet.setData.completed)

            // Expanded input section
            if isExpanded && !flatSet.setData.completed {
                VStack(spacing: AppSpacing.md) {
                    inputFields

                    // Log button
                    Button {
                        isInputFocused = false
                        onLog(
                            Double(inputWeight),
                            Int(inputReps),
                            inputRPE > 0 ? inputRPE : nil,
                            inputDuration > 0 ? inputDuration : nil,
                            inputHoldTime > 0 ? inputHoldTime : nil,
                            Double(inputDistance)
                        )
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Log Set \(flatSet.setNumber)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppGradients.accentGradient)
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
                                .stroke(AppColors.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .onAppear { loadDefaults() }
    }

    private var targetSummary: String {
        switch exercise.exerciseType {
        case .strength:
            let weight = flatSet.targetWeight.map { formatWeight($0) + " lbs" } ?? ""
            let reps = flatSet.targetReps.map { "\($0) reps" } ?? ""
            if !weight.isEmpty && !reps.isEmpty {
                return "\(weight) × \(reps)"
            }
            return weight.isEmpty ? reps : weight
        case .isometric:
            return flatSet.targetHoldTime.map { "\($0)s hold" } ?? "Hold"
        case .cardio:
            if exercise.isDistanceBased {
                return flatSet.targetDistance.map { "\(formatDistance($0)) \(exercise.distanceUnit.abbreviation)" } ?? "Distance"
            }
            return flatSet.targetDuration.map { formatDuration($0) } ?? "Duration"
        case .mobility, .explosive:
            return flatSet.targetReps.map { "\($0) reps" } ?? "Reps"
        }
    }

    private var completedSummary: String {
        let set = flatSet.setData
        switch exercise.exerciseType {
        case .strength:
            return set.formattedStrength ?? "Completed"
        case .isometric:
            return set.formattedIsometric ?? "Completed"
        case .cardio:
            return set.formattedCardio ?? "Completed"
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "Completed"
        }
    }

    @ViewBuilder
    private var inputFields: some View {
        switch exercise.exerciseType {
        case .strength:
            HStack(spacing: AppSpacing.md) {
                // Weight
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEIGHT")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }

                // Reps
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }

                // RPE
                VStack(alignment: .leading, spacing: 4) {
                    Text("RPE")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    Picker("RPE", selection: $inputRPE) {
                        Text("--").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 60)
                    .clipped()
                }
            }

        case .isometric:
            TimePickerView(totalSeconds: $inputHoldTime, maxMinutes: 5, label: "Hold Time")

        case .cardio:
            if exercise.isDistanceBased {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE (\(exercise.distanceUnit.abbreviation.uppercased()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                        .focused($isInputFocused)
                }
            } else {
                TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, label: "Duration")
            }

        case .mobility, .explosive:
            VStack(alignment: .leading, spacing: 4) {
                Text("REPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfaceLight))
                    .focused($isInputFocused)
            }
        }
    }

    private func loadDefaults() {
        inputWeight = flatSet.targetWeight.map { formatWeight($0) } ?? ""
        inputReps = flatSet.targetReps.map { "\($0)" } ?? ""
        inputDuration = flatSet.targetDuration ?? 0
        inputHoldTime = flatSet.targetHoldTime ?? 0
        inputDistance = flatSet.targetDistance.map { formatDistance($0) } ?? ""
        inputRPE = 0
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) { return "\(Int(weight))" }
        return String(format: "%.1f", weight)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) { return "\(Int(distance))" }
        return String(format: "%.2f", distance)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)s"
    }
}

#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
