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

    // MARK: - Dominant Gradients (VIBRANT!)
    static let dominantGradient = LinearGradient(
        colors: [AppColors.dominant, Color(hex: "00FFF0")], // Electric cyan → brighter
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

    // MARK: - Progress Bar Gradient (VIBRANT rainbow!)
    static let progressGradient = LinearGradient(
        colors: [
            AppColors.dominant,
            Color(hex: "00E5CC"),  // Teal
            Color(hex: "7B61FF")   // Purple
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

    // MARK: - Social Gradient (Rose for social features)
    static let socialGradient = LinearGradient(
        colors: [AppColors.accent2, Color(hex: "E879B9")],  // Rose → lighter rose
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Program Gradient (Gold-based)
    static let programGradient = LinearGradient(
        colors: [AppColors.accent2.opacity(0.4), AppColors.accent2.opacity(0.15)],
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
