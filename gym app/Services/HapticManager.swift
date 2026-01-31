//
//  HapticManager.swift
//  gym app
//
//  Centralized haptic feedback and sound for delightful interactions
//

import UIKit
import SwiftUI
import AVFoundation
import AudioToolbox

final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    // Audio players for timer sounds
    private var timerCompletePlayer: AVAudioPlayer?
    private var countdownBeepPlayer: AVAudioPlayer?
    private var phaseTransitionPlayer: AVAudioPlayer?

    private init() {
        // Pre-warm the generators for faster response
        prepareAll()
        // Configure audio session for playback even on silent mode
        configureAudioSession()
        // Pre-load sound files
        prepareSounds()
    }

    private func configureAudioSession() {
        do {
            // Use playback category with duckOthers to:
            // 1. Play sounds even when silent switch is on
            // 2. Temporarily lower music volume when playing alerts
            // 3. Mix with other audio so music resumes after
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.error(error, context: "Failed to configure audio session")
        }
    }

    /// Re-activate audio session before playing sounds (needed after other apps take over audio)
    private func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.debug("Audio session activation failed: \(error.localizedDescription)")
        }
    }

    private func prepareSounds() {
        // Timer complete sound - use system sound file
        if let soundURL = Bundle.main.url(forResource: "timer_complete", withExtension: "wav") {
            timerCompletePlayer = try? AVAudioPlayer(contentsOf: soundURL)
            timerCompletePlayer?.prepareToPlay()
        }

        // Countdown beep - use system sound file
        if let soundURL = Bundle.main.url(forResource: "countdown_beep", withExtension: "wav") {
            countdownBeepPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            countdownBeepPlayer?.prepareToPlay()
        }

        // Phase transition sound
        if let soundURL = Bundle.main.url(forResource: "phase_transition", withExtension: "wav") {
            phaseTransitionPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            phaseTransitionPlayer?.prepareToPlay()
        }
    }

    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Basic Haptics

    /// Light tap - for minor interactions (increment buttons, selections)
    func tap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap - for completing actions (set complete, adding items)
    func impact() {
        mediumImpact.impactOccurred()
    }

    /// Heavy thunk - for major completions (workout done, PR)
    func heavy() {
        heavyImpact.impactOccurred()
    }

    /// Soft subtle feedback
    func soft() {
        softImpact.impactOccurred()
    }

    /// Selection change feedback
    func selectionChanged() {
        selection.selectionChanged()
    }

    // MARK: - Semantic Haptics

    /// Set completed - satisfying confirmation
    func setCompleted() {
        mediumImpact.impactOccurred(intensity: 0.8)
    }

    /// Exercise completed - all sets done
    func exerciseCompleted() {
        // Double tap pattern
        mediumImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred(intensity: 0.6)
        }
    }

    /// Workout completed - big accomplishment
    func workoutCompleted() {
        // Triple heavy pattern
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.4)
        }
    }

    /// Personal Record achieved!
    func personalRecord() {
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 1.0)
        }
    }

    /// Timer finished (with sound)
    func timerComplete() {
        notification.notificationOccurred(.success)
        playTimerCompleteSound()
    }

    /// Rest timer finished (with sound)
    func restTimerComplete() {
        notification.notificationOccurred(.success)
        playTimerCompleteSound()
    }

    /// Countdown beep for last 3 seconds
    func countdownBeep() {
        tap()
        playCountdownBeepSound()
    }

    /// Phase transition (work -> rest, rest -> work in interval timer)
    func phaseTransition(isWorkPhase: Bool) {
        if isWorkPhase {
            notification.notificationOccurred(.warning)
        } else {
            notification.notificationOccurred(.success)
        }
        playPhaseTransitionSound()
    }

    /// Play timer completion sound
    private func playTimerCompleteSound() {
        ensureAudioSessionActive()

        // Try custom sound first, fall back to system sound
        if let player = timerCompletePlayer {
            player.volume = 1.0
            player.currentTime = 0
            player.play()
        } else {
            // Fallback: Use system sound
            // Note: AudioServicesPlaySystemSound ignores silent switch when audio session is .playback
            AudioServicesPlaySystemSound(SystemSoundID(1304))
        }
    }

    /// Play countdown beep sound
    private func playCountdownBeepSound() {
        ensureAudioSessionActive()

        if let player = countdownBeepPlayer {
            player.volume = 0.7
            player.currentTime = 0
            player.play()
        } else {
            // Fallback: Short click sound
            AudioServicesPlaySystemSound(SystemSoundID(1057))
        }
    }

    /// Play phase transition sound
    private func playPhaseTransitionSound() {
        ensureAudioSessionActive()

        if let player = phaseTransitionPlayer {
            player.volume = 1.0
            player.currentTime = 0
            player.play()
        } else {
            // Fallback: Alert tone
            AudioServicesPlaySystemSound(SystemSoundID(1322))
        }
    }

    /// Error or warning
    func error() {
        notification.notificationOccurred(.error)
    }

    /// Warning feedback
    func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Success feedback
    func success() {
        notification.notificationOccurred(.success)
    }

    /// Increment/decrement value (like stepper)
    func increment() {
        rigidImpact.impactOccurred(intensity: 0.5)
    }

    /// Button press feedback
    func buttonPress() {
        lightImpact.impactOccurred(intensity: 0.6)
    }

    /// Swipe action feedback
    func swipe() {
        softImpact.impactOccurred(intensity: 0.7)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add haptic feedback to a tap gesture
    func hapticTap(_ style: HapticStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                switch style {
                case .light:
                    HapticManager.shared.tap()
                case .medium:
                    HapticManager.shared.impact()
                case .heavy:
                    HapticManager.shared.heavy()
                case .selection:
                    HapticManager.shared.selectionChanged()
                case .success:
                    HapticManager.shared.success()
                }
            }
        )
    }
}

enum HapticStyle {
    case light, medium, heavy, selection, success
}
