//
//  AppGradients.swift
//  gym app
//
//  Gradient definitions for the app's design system
//

import SwiftUI

// MARK: - Gradients

struct AppGradients {
    // MARK: - Card Gradients

    // Elevated card treatment for the active-session header.
    static let cardGradientElevated = LinearGradient(
        colors: [
            Color(hex: "1A1A1C"),  // Slightly lighter slate
            AppColors.surfacePrimary,
            Color(hex: "0F0F10")   // Slightly darker
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Refined shine effect - very subtle highlight
    static let cardShine = LinearGradient(
        colors: [
            Color.white.opacity(0.05),
            Color.white.opacity(0.015),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .center
    )

    // MARK: - Dominant gradients
    // Gradients are reserved for focused actions and rewards, never ordinary
    // containers. The second stop stays close to the dominant color so a CTA
    // reads as a control rather than decoration.
    static let dominantGradient = LinearGradient(
        colors: [AppColors.dominant, AppColors.dominant.opacity(0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Progress Bar Gradient
    static let progressGradient = LinearGradient(
        colors: [
            AppColors.dominant,
            AppColors.dominant.opacity(0.82)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Program Gradient
    static let programGradient = LinearGradient(
        colors: [AppColors.dominant.opacity(0.32), AppColors.dominant.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
