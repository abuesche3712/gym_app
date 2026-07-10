//
//  AppAnimations.swift
//  gym app
//
//  Animation definitions for the app's design system
//

import SwiftUI

// MARK: - Motion

/// Motion is feedback, not decoration. Common interactions complete quickly;
/// springs are limited to interruptible gestures and rare reward moments.
struct AppMotion {
    /// Immediate acknowledgement for a button press.
    static let press = Animation.easeOut(duration: 0.14)
    /// Small state changes such as selection, disclosure, and filtering.
    static let stateChange = Animation.easeOut(duration: 0.2)
    /// A short transition for a sheet-local content change.
    static let reveal = Animation.easeOut(duration: 0.24)
    /// Interruptible movement such as drag/reorder or a user-driven expansion.
    static let interactiveSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Reserved for a completed workout or a personal record.
    static let celebration = Animation.spring(response: 0.42, dampingFraction: 0.78)
}

/// Backwards-compatible names while feature views migrate to purpose-named
/// motion. Keeping the aliases avoids changing behavior piecemeal.
struct AppAnimation {
    static let quick = AppMotion.press
    static let standard = AppMotion.interactiveSpring
    static let smooth = AppMotion.stateChange
    static let bounce = AppMotion.celebration
    static let gentle = AppMotion.reveal
    static let luxurious = AppMotion.interactiveSpring
    static let entrance = AppMotion.reveal
}
