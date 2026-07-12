//
//  AppColors.swift
//  gym app
//
//  Color definitions for the app's design system
//

import SwiftUI

// MARK: - Colors

struct AppColors {
    // MARK: - Adaptive helper
    /// Builds a `Color` that resolves to a different hex depending on the
    /// active `UIUserInterfaceStyle`, independent of the SwiftUI environment's
    /// `colorScheme` (so it works correctly even inside overlays/previews that
    /// don't propagate `colorScheme` the same way `UITraitCollection` does).
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    /// Adaptive black shadow tint. Elevation shadows tuned for a near-black
    /// background read as heavy smudges on a bright surface, so light mode
    /// gets a lower alpha for the same visual weight.
    static func adaptiveShadow(light: Double, dark: Double) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(dark) : UIColor.black.withAlphaComponent(light)
        })
    }

    // MARK: - Base Neutrals (Near-black with subtle purple tint / light purple-tinted neutrals)
    static let background = adaptive(light: "F7F6FA", dark: "0A0A0B")       // App background
    static let surfacePrimary = adaptive(light: "FFFFFF", dark: "161419")   // Cards
    static let surfaceSecondary = adaptive(light: "F0EEF4", dark: "1D1B21") // Sheets, inputs
    static let surfaceTertiary = adaptive(light: "DCD8E2", dark: "2D2A33") // Borders, dividers

    // MARK: - Text Hierarchy (Warm off-white + purple-grays / dark ink + purple-grays)
    static let textPrimary = adaptive(light: "1A171F", dark: "FFFCF9")
    static let textSecondary = adaptive(light: "6A6572", dark: "A09CA6")
    static let textTertiary = adaptive(light: "9B96A4", dark: "5A5662")

    // MARK: - Dominant Color (THE hero color - use sparingly!)
    // Darker cyan in light mode so glyphs/borders keep contrast on a white surface.
    static let dominant = adaptive(light: "0F93BD", dark: "33C4E8")
    static let dominantMuted = dominant.opacity(0.20)  // Subtle backgrounds (increased visibility)

    // MARK: - Contextual accents
    // These identify module types only. They are not UI chrome: screens, cards,
    // navigation, and primary actions use `dominant` so the interface retains a
    // calm, predictable hierarchy.
    static let accent1 = adaptive(light: "00A392", dark: "00E5CC")          // Teal (recovery/prehab)
    static let accent2 = adaptive(light: "C08A00", dark: "FFB800")          // Gold (explosive)
    static let accent3 = adaptive(light: "5F45E6", dark: "7B61FF")          // Purple (cardio)
    static let accent4 = adaptive(light: "D9457C", dark: "FF6B9D")          // Pink (programs!)
    static let accent5 = adaptive(light: "D93A3A", dark: "FF5757")          // Red-orange (warmup)

    // MARK: - Semantic Colors
    static let success = adaptive(light: "00994D", dark: "00E676")         // PRs, completed
    static let warning = adaptive(light: "C08A00", dark: "FFB800")         // Urgent, attention (mirrors accent2)
    static let error = adaptive(light: "D32F2F", dark: "FF5252")           // Delete, errors

    // MARK: - Module Type Colors (More vibrant with personality!)
    static func moduleColor(_ type: ModuleType) -> Color {
        // Vibrant module colors - symbol-first but with more color personality
        switch type {
        case .warmup: return accent5                   // Red-orange warmth
        case .prehab: return accent1                   // Teal
        case .explosive: return accent2                // Gold energy
        case .strength: return dominant                // Primary type
        case .mobility: return accent4                 // Pink for flexibility work
        case .cardioLong: return accent3.opacity(0.8)  // Purple
        case .cardioSpeed: return accent3              // Full purple
        case .recovery: return accent1.opacity(0.7)    // Softer teal
        }
    }

}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
