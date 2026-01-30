//
//  AppShadows.swift
//  gym app
//
//  Shadow definitions for the app's design system
//

import SwiftUI

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Shadows

struct AppShadows {
    static let soft = ShadowStyle(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    static let medium = ShadowStyle(color: .black.opacity(0.4), radius: 15, x: 0, y: 6)
    static let glow = ShadowStyle(color: AppColors.dominant.opacity(0.3), radius: 10, x: 0, y: 0)
    static let rewardGlow = ShadowStyle(color: AppColors.reward.opacity(0.5), radius: 20, x: 0, y: 0)
}
