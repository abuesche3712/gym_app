//
//  AppTheme.swift
//  gym app
//
//  Central theme configuration for consistent styling
//

import SwiftUI

// MARK: - Colors

struct AppColors {
    // Base greyscale palette
    static let background = Color(hex: "0D0D0D")
    static let cardBackground = Color(hex: "1A1A1A")
    static let cardBackgroundLight = Color(hex: "242424")
    static let surfaceLight = Color(hex: "2A2A2A")
    static let border = Color(hex: "333333")

    // Text colors
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "A0A0A0")
    static let textTertiary = Color(hex: "666666")

    // Cool accent colors
    static let accentBlue = Color(hex: "00A3FF")
    static let accentCyan = Color(hex: "00D4E5")
    static let accentTeal = Color(hex: "00C9A7")
    static let accentMint = Color(hex: "4FFFB0")
    static let accentSteel = Color(hex: "6B8CAE")

    // Semantic colors
    static let success = Color(hex: "00C9A7")
    static let warning = Color(hex: "FFB800")
    static let error = Color(hex: "FF4757")
    static let rest = Color(hex: "00A3FF")

    // Module type colors
    static func moduleColor(_ type: ModuleType) -> Color {
        switch type {
        case .warmup: return Color(hex: "FF8C42")
        case .prehab: return accentTeal
        case .explosive: return Color(hex: "FFD93D")
        case .strength: return Color(hex: "FF4757")
        case .cardioLong: return accentBlue
        case .cardioSpeed: return Color(hex: "A855F7")
        case .recovery: return Color.teal
        }
    }
}

// MARK: - Gradients

struct AppGradients {
    static let cardGradient = LinearGradient(
        colors: [AppColors.cardBackground, AppColors.cardBackground.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [AppColors.accentBlue, AppColors.accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tealGradient = LinearGradient(
        colors: [AppColors.accentTeal, AppColors.accentMint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGradient = LinearGradient(
        colors: [AppColors.cardBackgroundLight, AppColors.cardBackground],
        startPoint: .top,
        endPoint: .bottom
    )

    static func moduleGradient(_ type: ModuleType) -> LinearGradient {
        let color = AppColors.moduleColor(type)
        return LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Spacing & Layout

struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 12
}

struct AppCorners {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Shadows

struct AppShadows {
    static let soft = ShadowStyle(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    static let medium = ShadowStyle(color: .black.opacity(0.4), radius: 15, x: 0, y: 6)
    static let glow = ShadowStyle(color: AppColors.accentBlue.opacity(0.3), radius: 10, x: 0, y: 0)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Animation

struct AppAnimation {
    static let quick = Animation.easeOut(duration: 0.2)
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.6)
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

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

struct GlassCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct AccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isDestructive ? AppColors.error : AppColors.accentBlue)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.cardBackgroundLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func glassCard(padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(GlassCardStyle(padding: padding))
    }

    func softShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    func glowShadow(_ color: Color = AppColors.accentBlue) -> some View {
        shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 0)
    }
}
