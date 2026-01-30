//
//  AppSpacing.swift
//  gym app
//
//  Spacing constants for the app's design system
//

import SwiftUI

// MARK: - Spacing & Layout

struct AppSpacing {
    // Refined spacing scale - more generous for premium feel
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40

    static let cardPadding: CGFloat = 20      // More breathing room
    static let screenPadding: CGFloat = 20    // Generous edge margins
    static let stackSpacing: CGFloat = 14

    // Minimum touch target size per Apple HIG (44x44 points)
    static let minTouchTarget: CGFloat = 44
}
