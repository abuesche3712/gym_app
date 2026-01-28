//
//  IntervalTimerView.swift
//  gym app
//
//  Full-screen interval timer for timed workout sets
//

import SwiftUI

enum IntervalPhase {
    case getReady
    case work
    case rest
    case complete

    var label: String {
        switch self {
        case .getReady: return "GET READY"
        case .work: return "WORK"
        case .rest: return "REST"
        case .complete: return "DONE"
        }
    }

    var color: Color {
        switch self {
        case .getReady: return .orange
        case .work: return AppColors.accentBlue
        case .rest: return AppColors.accentTeal
        case .complete: return AppColors.accentBlue
        }
    }
}

private let leadInDuration: Int = 10  // seconds

struct IntervalTimerView: View {
    let rounds: Int
    let workDuration: Int  // seconds
    let restDuration: Int  // seconds
    let exerciseName: String
    let onComplete: ([Int]) -> Void  // Returns array of actual work durations per round
    let onCancel: () -> Void

    @State private var currentRound: Int = 1
    @State private var phase: IntervalPhase = .getReady
    @State private var secondsRemaining: Int = leadInDuration
    @State private var isPaused: Bool = false
    @State private var timer: Timer?
    @State private var roundDurations: [Int] = []  // Actual work duration for each round
    @State private var currentWorkElapsed: Int = 0  // Time spent in current work phase

    // Background-safe timing
    @State private var phaseStartTime: Date?
    @State private var pausedTimeAccumulated: TimeInterval = 0
    @State private var pauseStartTime: Date?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background - changes based on phase
            phase.color.opacity(0.15)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: phase)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        stopTimer()
                        onCancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(exerciseName)
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

                Spacer()

                // Main content
                if phase == .complete {
                    completeView
                } else {
                    timerView
                }

                Spacer()

                // Controls
                if phase != .complete {
                    controlButtons
                        .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .onAppear {
            secondsRemaining = leadInDuration
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Timer View

    private var timerView: some View {
        VStack(spacing: AppSpacing.xl) {
            // Phase indicator
            Text(phase.label)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(phase.color)
                .animation(.easeInOut(duration: 0.2), value: phase)

            // Big countdown
            Text(formatTime(secondsRemaining))
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.1), value: secondsRemaining)

            if phase == .getReady {
                // Show what's coming up
                Text("\(rounds) rounds of \(formatTime(workDuration)) work / \(formatTime(restDuration)) rest")
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Round indicator
                HStack(spacing: AppSpacing.sm) {
                    ForEach(1...rounds, id: \.self) { round in
                        Circle()
                            .fill(roundColor(for: round))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.2), value: currentRound)
                    }
                }

                Text("Round \(currentRound) of \(rounds)")
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)

                // Progress info
                VStack(spacing: 4) {
                    let totalTime = (workDuration + restDuration) * rounds - restDuration
                    let elapsed = elapsedTime()
                    Text("Total: \(formatTime(totalTime - elapsed)) remaining")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: AppSpacing.xl) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(AppColors.success)
            }

            Text("Interval Complete!")
                .font(.title.bold())
                .foregroundColor(AppColors.textPrimary)

            Text("\(rounds) rounds completed")
                .font(.title3)
                .foregroundColor(AppColors.textSecondary)

            Button {
                onComplete(roundDurations)
                dismiss()
            } label: {
                Text("Done")
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
            .padding(.top, AppSpacing.lg)
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: AppSpacing.xl) {
            // Stop button
            Button {
                stopTimer()
                // Log partial progress
                if phase == .work && currentWorkElapsed > 0 {
                    roundDurations.append(currentWorkElapsed)
                }
                onComplete(roundDurations)
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                    Text("Stop")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(AppColors.error)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(AppColors.error.opacity(0.1))
                )
            }

            // Pause/Resume button
            Button {
                togglePause()
            } label: {
                let buttonColor = isPaused ? AppColors.accentTeal : AppColors.accentBlue
                VStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 32))
                    Text(isPaused ? "Resume" : "Pause")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(buttonColor)
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(buttonColor.opacity(0.15))
                )
            }

            // Skip phase button
            Button {
                skipPhase()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                    Text("Skip")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(AppColors.surfaceLight)
                )
            }
        }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        phaseStartTime = Date()
        pausedTimeAccumulated = 0

        updateFromStartTime()

        // Create timer with proper configuration for accurate timing
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [self] _ in
            guard !self.isPaused else { return }
            self.updateFromStartTime()
        }
        // Set tolerance for balance between accuracy and battery life
        newTimer.tolerance = 0.05  // 50ms tolerance
        // Add to common mode so timer continues during UI interactions
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer

        // Listen for foreground to update timer
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateFromStartTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func togglePause() {
        if isPaused {
            // Resuming - add paused time to accumulated
            if let pauseStart = pauseStartTime {
                pausedTimeAccumulated += Date().timeIntervalSince(pauseStart)
            }
            pauseStartTime = nil
        } else {
            // Pausing - record when pause started
            pauseStartTime = Date()
        }
        isPaused.toggle()

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func updateFromStartTime() {
        guard let startTime = phaseStartTime else { return }

        // Calculate total paused time including current pause
        var totalPaused = pausedTimeAccumulated
        if isPaused, let pauseStart = pauseStartTime {
            totalPaused += Date().timeIntervalSince(pauseStart)
        }

        let elapsed = Int(Date().timeIntervalSince(startTime) - totalPaused)
        let phaseDuration: Int
        switch phase {
        case .getReady:
            phaseDuration = leadInDuration
        case .work:
            phaseDuration = workDuration
        case .rest:
            phaseDuration = restDuration
        case .complete:
            phaseDuration = 0
        }
        let remaining = phaseDuration - elapsed

        if phase == .work {
            currentWorkElapsed = elapsed
        }

        if remaining > 0 {
            secondsRemaining = remaining
        } else {
            transitionPhase()
        }
    }

    private func transitionPhase() {
        // Haptic on transition
        let generator = UINotificationFeedbackGenerator()

        switch phase {
        case .getReady:
            // Lead-in complete, start first work interval
            phase = .work
            secondsRemaining = workDuration
            phaseStartTime = Date()
            pausedTimeAccumulated = 0
            generator.notificationOccurred(.warning)

        case .work:
            // Save work duration for this round
            roundDurations.append(currentWorkElapsed)
            currentWorkElapsed = 0

            if currentRound < rounds {
                // Go to rest
                phase = .rest
                secondsRemaining = restDuration
                // Reset timing for new phase
                phaseStartTime = Date()
                pausedTimeAccumulated = 0
                generator.notificationOccurred(.success)
            } else {
                // Last round complete
                phase = .complete
                generator.notificationOccurred(.success)
                stopTimer()
            }

        case .rest:
            // Go to next work round
            currentRound += 1
            phase = .work
            secondsRemaining = workDuration
            // Reset timing for new phase
            phaseStartTime = Date()
            pausedTimeAccumulated = 0
            generator.notificationOccurred(.warning)

        case .complete:
            break
        }
    }

    private func skipPhase() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if phase == .work {
            // Log partial work time
            roundDurations.append(currentWorkElapsed)
            currentWorkElapsed = 0
        }
        // For getReady phase, just skip to work without logging anything

        secondsRemaining = 0
        transitionPhase()
    }

    // MARK: - Helpers

    private func roundColor(for round: Int) -> Color {
        if round < currentRound {
            return AppColors.success
        } else if round == currentRound {
            return phase.color
        } else {
            return AppColors.surfaceLight
        }
    }

    private func elapsedTime() -> Int {
        // Calculate total elapsed time
        var elapsed = 0

        // Completed rounds
        for _ in 0..<(currentRound - 1) {
            elapsed += workDuration + restDuration
        }

        // Current round progress
        if phase == .work {
            elapsed += workDuration - secondsRemaining
        } else if phase == .rest {
            elapsed += workDuration + (restDuration - secondsRemaining)
        }

        return elapsed
    }
}

#Preview {
    IntervalTimerView(
        rounds: 5,
        workDuration: 30,
        restDuration: 30,
        exerciseName: "Jump Rope",
        onComplete: { durations in
            print("Completed with durations: \(durations)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
