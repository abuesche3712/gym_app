//
//  IntervalTimerView.swift
//  gym app
//
//  Full-screen interval timer for timed workout sets
//

import SwiftUI
import UIKit
import UserNotifications

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
        case .getReady: return AppColors.warning
        case .work: return AppColors.dominant
        case .rest: return AppColors.accent1
        case .complete: return AppColors.dominant
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

    // Timeline-based tracking survives background/foreground transitions.
    @State private var timelineAnchorTime: Date?
    @State private var elapsedBeforeAnchor: TimeInterval = 0

    // Local notification while app is backgrounded during work phase.
    @State private var workEndNotificationId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background - changes based on phase
            phase.color.opacity(0.12)
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
                            .displaySmall(color: AppColors.textSecondary)
                            .fontWeight(.medium)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(exerciseName)
                        .headline(color: AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)

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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            scheduleBackgroundWorkEndNotificationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            cancelWorkEndNotification()
            updateFromTimeline()
        }
    }

    // MARK: - Timer View

    private var timerView: some View {
        VStack(spacing: AppSpacing.xl) {
            // Phase indicator
            Text(phase.label)
                .displayMedium(color: phase.color)
                .animation(.easeInOut(duration: 0.2), value: phase)

            // Big countdown
            Text(formatTime(secondsRemaining))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.1), value: secondsRemaining)

            if phase == .getReady {
                // Show what's coming up
                Text("\(rounds) rounds of \(formatTime(workDuration)) work / \(formatTime(restDuration)) rest")
                    .displaySmall(color: AppColors.textSecondary)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, AppSpacing.lg)
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
                    .displaySmall(color: AppColors.textSecondary)
                    .fontWeight(.medium)

                // Progress info
                VStack(spacing: 4) {
                    let totalTime = totalTimelineDuration()
                    let elapsed = elapsedTime()
                    Text("Total: \(formatTime(max(0, totalTime - elapsed))) remaining")
                        .subheadline(color: AppColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: AppSpacing.xl) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .displayLarge(color: AppColors.success)
            }

            Text("Interval Complete!")
                .displayMedium(color: AppColors.textPrimary)

            Text("\(rounds) rounds completed")
                .displaySmall(color: AppColors.textSecondary)

            Button {
                onComplete(completedWorkDurations())
                dismiss()
            } label: {
                Text("Done")
                    .headline(color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppGradients.dominantGradient)
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
                onComplete(loggedWorkDurationsForStop())
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .displaySmall(color: AppColors.error)
                    Text("Stop")
                        .caption(color: AppColors.error)
                        .fontWeight(.medium)
                }
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
                let buttonColor = isPaused ? AppColors.accent1 : AppColors.dominant
                VStack(spacing: 4) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .displayMedium(color: buttonColor)
                    Text(isPaused ? "Resume" : "Pause")
                        .caption(color: buttonColor)
                        .fontWeight(.medium)
                }
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(buttonColor.opacity(0.12))
                )
            }

            // Skip phase button
            Button {
                skipPhase()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .displaySmall(color: AppColors.textSecondary)
                    Text("Skip")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                }
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(AppColors.surfaceTertiary)
                )
            }
        }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timelineAnchorTime = Date()
        elapsedBeforeAnchor = 0
        isPaused = false

        updateFromTimeline()

        // Create timer with faster interval for smooth visual updates.
        let newTimer = Timer(timeInterval: 0.25, repeats: true) { [self] _ in
            guard !self.isPaused else { return }
            self.updateFromTimeline()
        }
        newTimer.tolerance = 0.02  // 20ms tolerance
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer

        scheduleBackgroundWorkEndNotificationIfNeeded()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        cancelWorkEndNotification()
    }

    private func togglePause() {
        if isPaused {
            timelineAnchorTime = Date()
            isPaused = false
            scheduleBackgroundWorkEndNotificationIfNeeded()
        } else if let anchor = timelineAnchorTime {
            elapsedBeforeAnchor += Date().timeIntervalSince(anchor)
            timelineAnchorTime = nil
            isPaused = true
            cancelWorkEndNotification()
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        updateFromTimeline()
    }

    private func updateFromTimeline() {
        let previousPhase = phase
        let previousRound = currentRound
        let previousSecondsRemaining = secondsRemaining

        let elapsed = currentElapsedSeconds()
        let totalDuration = totalTimelineDuration()

        if elapsed >= totalDuration {
            phase = .complete
            currentRound = rounds
            secondsRemaining = 0
        } else if elapsed < leadInDuration {
            phase = .getReady
            currentRound = 1
            secondsRemaining = max(0, leadInDuration - elapsed)
        } else {
            let workoutElapsed = elapsed - leadInDuration
            let cycleDuration = workDuration + restDuration
            let zeroBasedRound = min(workoutElapsed / cycleDuration, rounds - 1)
            let elapsedInRound = workoutElapsed - (zeroBasedRound * cycleDuration)

            currentRound = zeroBasedRound + 1
            if elapsedInRound < workDuration {
                phase = .work
                secondsRemaining = max(0, workDuration - elapsedInRound)
            } else {
                phase = .rest
                secondsRemaining = max(0, restDuration - (elapsedInRound - workDuration))
            }
        }

        // Countdown beeps for last 3 seconds (except get ready).
        if phase != .getReady && phase != .complete && secondsRemaining <= 3 && previousSecondsRemaining != secondsRemaining {
            HapticManager.shared.countdownBeep()
        }

        guard phase != previousPhase || currentRound != previousRound else { return }

        switch phase {
        case .work:
            HapticManager.shared.phaseTransition(isWorkPhase: true)
            scheduleBackgroundWorkEndNotificationIfNeeded()

        case .rest:
            HapticManager.shared.phaseTransition(isWorkPhase: false)
            cancelWorkEndNotification()

        case .complete:
            HapticManager.shared.timerComplete()
            stopTimer()

        case .getReady:
            cancelWorkEndNotification()
        }
    }

    private func skipPhase() {
        guard phase != .complete else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        let elapsed = currentElapsedSeconds()
        let targetElapsed: Int

        switch phase {
        case .getReady:
            targetElapsed = leadInDuration
        case .work:
            targetElapsed = workEndElapsed(for: currentRound)
        case .rest:
            targetElapsed = restEndElapsed(for: currentRound)
        case .complete:
            targetElapsed = elapsed
        }

        if targetElapsed > elapsed {
            seekToElapsedSeconds(targetElapsed)
        }
        updateFromTimeline()
    }

    // MARK: - Timing Helpers

    private func currentElapsedSeconds() -> Int {
        if isPaused || timelineAnchorTime == nil {
            return max(0, Int(elapsedBeforeAnchor))
        }

        guard let anchor = timelineAnchorTime else {
            return max(0, Int(elapsedBeforeAnchor))
        }

        return max(0, Int(elapsedBeforeAnchor + Date().timeIntervalSince(anchor)))
    }

    private func seekToElapsedSeconds(_ elapsed: Int) {
        elapsedBeforeAnchor = TimeInterval(max(0, elapsed))
        if !isPaused {
            timelineAnchorTime = Date()
        }
        scheduleBackgroundWorkEndNotificationIfNeeded()
    }

    private func totalTimelineDuration() -> Int {
        leadInDuration + (workDuration * rounds) + (restDuration * max(0, rounds - 1))
    }

    private func workStartElapsed(for round: Int) -> Int {
        leadInDuration + ((round - 1) * (workDuration + restDuration))
    }

    private func workEndElapsed(for round: Int) -> Int {
        workStartElapsed(for: round) + workDuration
    }

    private func restEndElapsed(for round: Int) -> Int {
        workStartElapsed(for: round) + workDuration + restDuration
    }

    private func completedWorkDurations() -> [Int] {
        Array(repeating: workDuration, count: rounds)
    }

    private func loggedWorkDurationsForStop() -> [Int] {
        let elapsed = currentElapsedSeconds()
        var durations: [Int] = []

        for round in 1...rounds {
            let start = workStartElapsed(for: round)
            let end = workEndElapsed(for: round)

            if elapsed >= end {
                durations.append(workDuration)
                continue
            }

            if elapsed > start {
                durations.append(elapsed - start)
            }
            break
        }

        return durations
    }

    // MARK: - Background Notification

    private func scheduleBackgroundWorkEndNotificationIfNeeded() {
        guard UIApplication.shared.applicationState != .active else {
            cancelWorkEndNotification()
            return
        }
        guard !isPaused, phase == .work, secondsRemaining > 0 else {
            cancelWorkEndNotification()
            return
        }

        cancelWorkEndNotification()

        let content = UNMutableNotificationContent()
        content.title = "Work Interval Complete"
        content.body = "\(exerciseName): Round \(currentRound) work finished."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(secondsRemaining),
            repeats: false
        )
        let identifier = "interval-work-end-\(UUID().uuidString)"
        workEndNotificationId = identifier

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.error(error, context: "Failed to schedule interval work-end notification")
            }
        }
    }

    private func cancelWorkEndNotification() {
        guard let identifier = workEndNotificationId else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        workEndNotificationId = nil
    }

    // MARK: - Helpers

    private func roundColor(for round: Int) -> Color {
        if round < currentRound {
            return AppColors.success
        } else if round == currentRound {
            return phase.color
        } else {
            return AppColors.surfaceTertiary
        }
    }

    private func elapsedTime() -> Int {
        min(totalTimelineDuration(), currentElapsedSeconds())
    }
}

#Preview {
    IntervalTimerView(
        rounds: 5,
        workDuration: 30,
        restDuration: 30,
        exerciseName: "Jump Rope",
        onComplete: { durations in
            Logger.debug("Completed with durations: \(durations)")
        },
        onCancel: {
            Logger.debug("Cancelled")
        }
    )
}
