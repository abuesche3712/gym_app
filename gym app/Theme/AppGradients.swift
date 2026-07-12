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
            AppColors.adaptive(light: "FFFFFF", dark: "1A1A1C"),  // Slightly lighter
            AppColors.surfacePrimary,
            AppColors.adaptive(light: "F3F1F7", dark: "0F0F10")   // Slightly darker
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Refined shine effect - very subtle highlight. Dark cards get a white glare;
    // a white glare would vanish on a light (near-white) card, so light mode uses
    // a soft dark tint at the same opacities to keep the same sense of depth.
    static let cardShine = LinearGradient(
        colors: [
            AppColors.adaptive(light: "1A171F", dark: "FFFFFF").opacity(0.05),
            AppColors.adaptive(light: "1A171F", dark: "FFFFFF").opacity(0.015),
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
