//
//  AppAnimations.swift
//  gym app
//
//  Animation definitions for the app's design system
//

import SwiftUI

// MARK: - Animation

struct AppAnimation {
    // Refined, luxurious timing - slower and more deliberate
    static let quick = Animation.easeOut(duration: 0.25)
    static let standard = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let smooth = Animation.easeInOut(duration: 0.4)
    static let bounce = Animation.spring(response: 0.55, dampingFraction: 0.7)

    // Premium feel animations
    static let gentle = Animation.easeInOut(duration: 0.5)
    static let luxurious = Animation.spring(response: 0.6, dampingFraction: 0.85)
    static let entrance = Animation.spring(response: 0.7, dampingFraction: 0.8)
}
