//
//  AppColors.swift
//  gym app
//
//  Color definitions for the app's design system
//

import SwiftUI

// MARK: - Colors

struct AppColors {
    // MARK: - Base Neutrals (Near-black with subtle purple tint)
    static let background = Color(hex: "0A0A0B")       // Near-black (no purple, pure dark)
    static let surfacePrimary = Color(hex: "161419")   // Dark slate with purple tint (cards)
    static let surfaceSecondary = Color(hex: "1D1B21") // Elevated slate with purple (sheets, overlays)
    static let surfaceTertiary = Color(hex: "2D2A33")  // Medium slate with more purple (borders, dividers)

    // MARK: - Text Hierarchy (Warm off-white + purple-grays)
    static let textPrimary = Color(hex: "FFFCF9")      // Warm off-white
    static let textSecondary = Color(hex: "A09CA6")    // Medium purple-gray
    static let textTertiary = Color(hex: "5A5662")     // Dark purple-gray

    // MARK: - Dominant Color (THE hero color - use sparingly!)
    static let dominant = Color(hex: "00D9FF")         // VIBRANT electric cyan
    static let dominantMuted = dominant.opacity(0.20)  // Subtle backgrounds (increased visibility)
    static let dominantSubtle = dominant.opacity(0.12) // Very subtle highlights

    // MARK: - Accent Colors (More vibrant for personality!)
    static let accent1 = Color(hex: "00E5CC")          // Vibrant teal (recovery/prehab)
    static let accent2 = Color(hex: "FFB800")          // Bright gold (explosive)
    static let accent3 = Color(hex: "7B61FF")          // Vibrant purple (cardio)
    static let accent4 = Color(hex: "FF6B9D")          // Hot pink (programs!)
    static let accent5 = Color(hex: "FF5757")          // Bright red-orange (warmup)

    // MARK: - Semantic Colors (More vibrant functional meaning!)
    static let success = Color(hex: "00E676")          // Bright emerald green (PRs, completed)
    static let warning = Color(hex: "FFB800")          // Bright amber (urgent, attention)
    static let error = Color(hex: "FF5252")            // Bright red (delete, errors)

    // MARK: - Special (Reward moments!)
    static let reward = Color(hex: "00FFF0")           // ELECTRIC bright cyan (PR celebration!)

    // MARK: - Program Color
    static let programAccent = accent4                 // Hot pink for programs

    // MARK: - Module Type Colors (More vibrant with personality!)
    static func moduleColor(_ type: ModuleType) -> Color {
        // Vibrant module colors - symbol-first but with more color personality
        switch type {
        case .warmup: return accent5                   // Bright red-orange warmth
        case .prehab: return accent1                   // Vibrant teal
        case .explosive: return accent2                // Bright gold energy
        case .strength: return dominant                // Electric cyan (primary type)
        case .cardioLong: return accent3.opacity(0.8)  // Vibrant purple
        case .cardioSpeed: return accent3              // Full vibrant purple
        case .recovery: return accent1.opacity(0.7)    // Softer teal
        }
    }

    // Module symbol color (for icon/symbol itself)
    static func moduleSymbolColor(_ type: ModuleType) -> Color {
        return moduleColor(type) // Use the module's color for consistency
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
