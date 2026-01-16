//
//  HapticManager.swift
//  gym app
//
//  Centralized haptic feedback for delightful interactions
//

import UIKit
import SwiftUI

final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        // Pre-warm the generators for faster response
        prepareAll()
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

    /// Timer finished
    func timerComplete() {
        notification.notificationOccurred(.success)
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
