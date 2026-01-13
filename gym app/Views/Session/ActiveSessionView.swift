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

                                // Exercise Card with sets
                                exerciseCard(currentExercise)

                                // Set Input
                                setInputSection

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

                    // Bottom Action Bar
                    bottomActionBar
                }
            }
            .navigationTitle(sessionViewModel.currentSession?.workoutName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    // MARK: - Progress Header

    private var sessionProgressHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            // Timer
            Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)

            // Progress bar
            if let session = sessionViewModel.currentSession {
                let totalModules = session.completedModules.count
                let progress = Double(sessionViewModel.currentModuleIndex) / Double(max(totalModules, 1))

                ProgressBar(progress: progress, height: 4, color: AppColors.accentTeal)
                    .padding(.horizontal, AppSpacing.xl)

                Text("Module \(sessionViewModel.currentModuleIndex + 1) of \(totalModules)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            AppColors.cardBackground
                .overlay(
                    LinearGradient(
                        colors: [AppColors.accentBlue.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    // MARK: - Module Indicator

    private func moduleIndicator(_ module: CompletedModule) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.moduleColor(module.moduleType).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: module.moduleType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.moduleColor(module.moduleType))
            }

            Text(module.moduleName)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                sessionViewModel.skipModule()
            } label: {
                Text("Skip")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Capsule()
                            .fill(AppColors.warning.opacity(0.15))
                    )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppGradients.moduleGradient(module.moduleType))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.moduleColor(module.moduleType).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(exercise.exerciseName)
                        .font(.title2.bold())
                        .foregroundColor(AppColors.textPrimary)

                    if let setGroup = sessionViewModel.currentSetGroup {
                        Text("Set \(sessionViewModel.currentSetIndex + 1) of \(setGroup.sets.count)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
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

            // Set indicators with per-set timer rings
            if let setGroup = sessionViewModel.currentSetGroup {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(setGroup.sets.enumerated()), id: \.offset) { index, set in
                        SetIndicator(
                            setNumber: index + 1,
                            isCompleted: index < sessionViewModel.currentSetIndex,
                            isCurrent: index == sessionViewModel.currentSetIndex,
                            restTime: set.restAfter ?? appState.defaultRestTime
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

    // MARK: - Set Input Section

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0

    private var setInputSection: some View {
        VStack(spacing: AppSpacing.lg) {
            if let exercise = sessionViewModel.currentExercise {
                switch exercise.exerciseType {
                case .strength:
                    strengthInput
                case .isometric:
                    isometricInput
                case .cardio:
                    cardioInput
                case .mobility, .explosive:
                    simpleRepsInput
                }
            }

            // Log Set Button
            Button {
                logCurrentSet()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: sessionViewModel.isLastSet ? "checkmark.circle.fill" : "checkmark")
                        .font(.system(size: 18, weight: .semibold))

                    Text(sessionViewModel.isLastSet ? "Finish Exercise" : "Log Set")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppGradients.accentGradient)
                )
            }
            .buttonStyle(.plain)
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
        .onAppear { loadSetDefaults() }
        .onChange(of: sessionViewModel.currentSetIndex) { _, _ in loadSetDefaults() }
    }

    private var strengthInput: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                // Weight
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("WEIGHT (\(appState.weightUnit.abbreviation.uppercased()))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.surfaceLight)
                        )
                }

                // Reps
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("REPS")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.surfaceLight)
                        )
                }
            }

            // RPE
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("RPE")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)

                HStack(spacing: AppSpacing.sm) {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { rpe in
                        Button {
                            withAnimation(AppAnimation.quick) {
                                inputRPE = inputRPE == rpe ? 0 : rpe
                            }
                        } label: {
                            Text("\(rpe)")
                                .font(.headline)
                                .foregroundColor(inputRPE == rpe ? .white : AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCorners.small)
                                        .fill(inputRPE == rpe ? AppColors.accentBlue : AppColors.surfaceLight)
                                )
                        }
                    }
                }
            }
        }
    }

    private var isometricInput: some View {
        TimePickerView(totalSeconds: $inputHoldTime, maxMinutes: 5, label: "Hold Time")
    }

    private var cardioInput: some View {
        TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, label: "Duration")
    }

    private var simpleRepsInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("REPS")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)

            TextField("0", text: $inputReps)
                .keyboardType(.numberPad)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceLight)
                )
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

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            ForEach([-10, -5, 5, 10], id: \.self) { delta in
                Button {
                    adjustWeight(by: delta)
                } label: {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(delta > 0 ? AppColors.success : AppColors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.small)
                                .fill(AppColors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCorners.small)
                                        .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
    }

    // MARK: - Workout Complete View

    private var workoutCompleteView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.success)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Workout Complete!")
                    .font(.title.bold())
                    .foregroundColor(AppColors.textPrimary)

                Text("Great job! Tap Finish to save your session.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

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

    private func loadSetDefaults() {
        if let set = sessionViewModel.currentSet {
            inputWeight = set.weight.map { String(format: "%.0f", $0) } ?? ""
            inputReps = set.reps.map { "\($0)" } ?? ""
            inputRPE = set.rpe ?? 0
            inputDuration = set.duration ?? 0
            inputHoldTime = set.holdTime ?? 0
        }
    }

    private func adjustWeight(by delta: Int) {
        let current = Double(inputWeight) ?? 0
        inputWeight = String(format: "%.0f", max(0, current + Double(delta)))
    }

    private func logCurrentSet() {
        let weight = Double(inputWeight)
        let reps = Int(inputReps)

        sessionViewModel.logSet(
            weight: weight,
            reps: reps,
            rpe: inputRPE > 0 ? inputRPE : nil,
            duration: inputDuration > 0 ? inputDuration : nil,
            holdTime: inputHoldTime > 0 ? inputHoldTime : nil,
            completed: true
        )

        // Start rest timer if there are more sets
        if !sessionViewModel.isLastSet, let setGroup = sessionViewModel.currentSetGroup,
           let restPeriod = setGroup.sets.first?.restAfter ?? appState.defaultRestTime as Int? {
            sessionViewModel.startRestTimer(seconds: restPeriod > 0 ? restPeriod : appState.defaultRestTime)
        }

        inputRPE = 0
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

#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
