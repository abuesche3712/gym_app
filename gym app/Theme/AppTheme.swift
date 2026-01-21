//
//  AppTheme.swift
//  gym app
//
//  Central theme configuration for consistent styling
//

import SwiftUI

// MARK: - Colors

struct AppColors {
    // Base greyscale palette (warm-tinted blacks for premium feel)
    static let background = Color(hex: "0C0C0B")      // Slightly warm black
    static let cardBackground = Color(hex: "161615")  // Warm dark gray
    static let cardBackgroundLight = Color(hex: "1E1E1C")
    static let surfaceLight = Color(hex: "262624")
    static let border = Color(hex: "2E2E2B")

    // Text colors (refined contrast)
    static let textPrimary = Color(hex: "F5F5F4")     // Soft white, not harsh
    static let textSecondary = Color(hex: "A8A8A4")   // Warm gray
    static let textTertiary = Color(hex: "6B6B67")    // Muted warm gray

    // Refined accent colors (muted, sophisticated)
    static let accentBlue = Color(hex: "5B9BD5")      // Muted slate blue
    static let accentCyan = Color(hex: "6DBFBF")      // Soft teal-cyan
    static let accentTeal = Color(hex: "5AAF9E")      // Muted sage teal
    static let accentMint = Color(hex: "8ED4B8")      // Soft mint
    static let accentSteel = Color(hex: "7A9BB8")     // Refined steel blue
    static let accentPurple = Color(hex: "9B8ABF")    // Soft lavender
    static let accentOrange = Color(hex: "D4956A")    // Warm terracotta

    // Semantic colors (refined)
    static let success = Color(hex: "5AAF9E")         // Matches muted teal
    static let warning = Color(hex: "D4A754")         // Warm amber
    static let error = Color(hex: "C75B5B")           // Muted coral red
    static let rest = Color(hex: "5B9BD5")            // Matches muted blue

    // Module type colors (refined, sophisticated palette)
    static func moduleColor(_ type: ModuleType) -> Color {
        switch type {
        case .warmup: return Color(hex: "D4956A")     // Warm terracotta
        case .prehab: return accentTeal
        case .explosive: return Color(hex: "D4B754")  // Warm gold
        case .strength: return Color(hex: "C75B5B")   // Muted coral
        case .cardioLong: return accentBlue
        case .cardioSpeed: return Color(hex: "9B8ABF") // Soft lavender
        case .recovery: return accentTeal
        }
    }
}

// MARK: - Gradients

struct AppGradients {
    static let cardGradient = LinearGradient(
        colors: [AppColors.cardBackground, AppColors.cardBackground.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Enhanced card gradient with subtle warmth
    static let cardGradientElevated = LinearGradient(
        colors: [
            Color(hex: "1C1C1A"),
            AppColors.cardBackground,
            Color(hex: "121211")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Refined shine effect - more subtle
    static let cardShine = LinearGradient(
        colors: [
            Color.white.opacity(0.05),
            Color.white.opacity(0.015),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .center
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

    static let successGradient = LinearGradient(
        colors: [AppColors.success, AppColors.accentMint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [Color(hex: "FF8C42"), Color(hex: "FFB347")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGradient = LinearGradient(
        colors: [AppColors.cardBackgroundLight, AppColors.cardBackground],
        startPoint: .top,
        endPoint: .bottom
    )

    // Progress bar gradient
    static let progressGradient = LinearGradient(
        colors: [AppColors.accentBlue, AppColors.accentCyan, AppColors.accentTeal],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func moduleGradient(_ type: ModuleType) -> LinearGradient {
        let color = AppColors.moduleColor(type)
        return LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Accent-tinted card background
    static func accentCardGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.15),
                color.opacity(0.05),
                AppColors.cardBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

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
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(AppGradients.cardGradientElevated)

                    // Subtle shine overlay
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(AppGradients.cardShine)

                    // Border
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.border.opacity(0.4), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
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
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }
}

struct GradientCardStyle: ViewModifier {
    var accentColor: Color = AppColors.accentBlue
    var padding: CGFloat = AppSpacing.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(AppGradients.accentCardGradient(accentColor))

                    // Subtle shine overlay
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(AppGradients.cardShine)

                    // Border with accent tint
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), AppColors.border.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: accentColor.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

struct SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [
                            AppColors.cardBackground.opacity(0.8),
                            AppColors.background.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
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

    func gradientCard(accent: Color = AppColors.accentBlue, padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(GradientCardStyle(accentColor: accent, padding: padding))
    }

    func sheetBackground() -> some View {
        modifier(SheetBackgroundModifier())
    }

    func softShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    func glowShadow(_ color: Color = AppColors.accentBlue) -> some View {
        shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 0)
    }

    func formFieldStyle() -> some View {
        modifier(FormFieldModifier())
    }
}

// MARK: - Form Field Modifier

struct FormFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceLight)
            )
    }
}

// MARK: - Styled Form Section

struct FormSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = AppColors.accentBlue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.5)
            }
            .padding(.horizontal, AppSpacing.xs)

            // Content
            VStack(spacing: 1) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Form Row

struct FormRow<Content: View>: View {
    let label: String
    var icon: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
            }

            Text(label)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            content()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Form Text Field

struct FormTextField: View {
    let label: String
    @Binding var text: String
    var icon: String? = nil
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)
            }

            Text(label)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Form Button Row

struct FormButtonRow: View {
    let label: String
    var icon: String? = nil
    var value: String = ""
    var valueColor: Color = AppColors.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24)
                }

                Text(label)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if !value.isEmpty {
                    Text(value)
                        .foregroundColor(valueColor)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Divider

struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.border.opacity(0.3))
            .frame(height: 0.5)
            .padding(.leading, AppSpacing.cardPadding + 24 + AppSpacing.md)
    }
}

// MARK: - Animated Progress Bar

struct AnimatedProgressBar: View {
    let progress: Double
    var gradient: LinearGradient = AppGradients.progressGradient
    var height: CGFloat = 8
    var showGlow: Bool = true

    @State private var animatedProgress: Double = 0
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppColors.surfaceLight)

                // Progress fill with gradient
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(gradient)
                    .frame(width: max(0, geometry.size.width * animatedProgress))
                    .overlay(
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset * geometry.size.width * animatedProgress)
                            .mask(
                                RoundedRectangle(cornerRadius: height / 2)
                                    .frame(width: max(0, geometry.size.width * animatedProgress))
                            )
                    )
                    .shadow(color: showGlow ? AppColors.accentBlue.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = min(max(progress, 0), 1)
            }
            // Start shimmer animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

// MARK: - Circular Progress Indicator

struct AnimatedCircularProgress: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 60
    var gradient: LinearGradient = AppGradients.progressGradient
    var showLabel: Bool = true

    @State private var animatedProgress: Double = 0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(AppColors.surfaceLight, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.accentBlue.opacity(0.4), radius: 4, x: 0, y: 0)

            // Percentage label
            if showLabel {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

// MARK: - Icon Button Style (Minimum Touch Target)

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = AppSpacing.minTouchTarget
    var iconSize: CGFloat = 16
    var foregroundColor: Color = AppColors.textPrimary
    var backgroundColor: Color = AppColors.surfaceLight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Dynamic Type Support

extension View {
    /// Applies scaled font that respects Dynamic Type settings
    func scaledFont(_ style: Font.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(style, design: design, weight: weight))
    }

    /// Ensures minimum touch target size (44x44 per Apple HIG)
    func minTouchTarget() -> some View {
        self.frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
    }

    /// Elegant uppercase label styling with refined letter-spacing
    func elegantLabel() -> some View {
        self
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundColor(AppColors.textSecondary)
    }

    /// Stat label style for numeric displays
    func statLabel() -> some View {
        self
            .font(.caption2.weight(.medium))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(AppColors.textTertiary)
    }
}

// MARK: - List Animation Modifier

extension View {
    /// Applies staggered entrance animation to list items - slower, more elegant
    func listItemAnimation(index: Int, total: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.85)
                .delay(Double(index) * 0.05),
                value: total
            )
    }
}

// MARK: - Skeleton Loading View

struct SkeletonView: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = AppCorners.small

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.surfaceLight)
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 2
                }
            }
    }
}
