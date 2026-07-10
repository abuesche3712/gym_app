//
//  AppGradients.swift
//  gym app
//
//  Gradient definitions for the app's design system
//

import SwiftUI

// MARK: - Gradients

struct AppGradients {
    // MARK: - Card Gradients (Subtle depth)
    static let cardGradient = LinearGradient(
        colors: [AppColors.surfacePrimary, AppColors.surfacePrimary.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Enhanced card gradient with subtle depth
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

    // MARK: - Success Gradient (PR celebration!)
    static let successGradient = LinearGradient(
        colors: [AppColors.success, AppColors.success.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Reward Gradient (THE ELECTRIC celebration moment!)
    static let rewardGradient = LinearGradient(
        colors: [
            AppColors.reward,
            Color(hex: "00D9FF"),
            Color(hex: "7B61FF")  // Add purple for rainbow effect
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Subtle Gradient
    static let subtleGradient = LinearGradient(
        colors: [AppColors.surfaceSecondary, AppColors.surfacePrimary],
        startPoint: .top,
        endPoint: .bottom
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

    // MARK: - Module Gradient (VIBRANT personality!)
    static func moduleGradient(_ type: ModuleType) -> LinearGradient {
        let color = AppColors.moduleColor(type)
        return LinearGradient(
            colors: [color.opacity(0.4), color.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Social Gradient
    static let socialGradient = LinearGradient(
        colors: [AppColors.dominant, AppColors.dominant.opacity(0.78)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Program Gradient
    static let programGradient = LinearGradient(
        colors: [AppColors.programAccent.opacity(0.32), AppColors.programAccent.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Accent-tinted card background
    static func accentCardGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.06),
                color.opacity(0.02),
                AppColors.surfacePrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
