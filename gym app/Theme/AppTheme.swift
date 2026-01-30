//
//  AppTheme.swift
//  gym app
//
//  View modifiers and reusable styled components
//
//  Theme definitions are split into focused files:
//  - AppColors.swift      (color definitions, module colors)
//  - AppGradients.swift   (gradient definitions)
//  - AppSpacing.swift     (spacing constants)
//  - AppCorners.swift     (corner radius constants)
//  - AppShadows.swift     (shadow definitions)
//  - AppAnimations.swift  (animation definitions)
//  - Font+Extensions.swift (typography system)
//

import SwiftUI

// MARK: - Card View Modifiers

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
                        .stroke(AppColors.surfaceTertiary.opacity(0.4), lineWidth: 0.5)
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
    var accentColor: Color = AppColors.dominant
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
                                colors: [accentColor.opacity(0.12), AppColors.surfaceTertiary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: accentColor.opacity(0.06), radius: 12, x: 0, y: 6)
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
                            AppColors.surfacePrimary.opacity(0.8),
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

// MARK: - Button Styles

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
                    .fill(isDestructive ? AppColors.error : AppColors.dominant)
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
                    .fill(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(AppColors.surfaceTertiary, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = AppSpacing.minTouchTarget
    var iconSize: CGFloat = 16
    var foregroundColor: Color = AppColors.textPrimary
    var backgroundColor: Color = AppColors.surfaceTertiary

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

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func glassCard(padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(GlassCardStyle(padding: padding))
    }

    func gradientCard(accent: Color = AppColors.dominant, padding: CGFloat = AppSpacing.cardPadding) -> some View {
        modifier(GradientCardStyle(accentColor: accent, padding: padding))
    }

    func sheetBackground() -> some View {
        modifier(SheetBackgroundModifier())
    }

    func softShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    func glowShadow(_ color: Color = AppColors.dominant) -> some View {
        shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 0)
    }

    func rewardGlow() -> some View {
        shadow(color: AppColors.reward.opacity(0.5), radius: 20, x: 0, y: 0)
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
                    .fill(AppColors.surfaceTertiary)
            )
    }
}

// MARK: - Styled Form Section

struct FormSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = AppColors.dominant
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
                    .fill(AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
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
        .background(AppColors.surfacePrimary)
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
        .background(AppColors.surfacePrimary)
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
            .background(AppColors.surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Divider

struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.surfaceTertiary.opacity(0.3))
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
                    .fill(AppColors.surfaceTertiary)

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
                    .shadow(color: showGlow ? AppColors.dominant.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
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
                .stroke(AppColors.surfaceTertiary, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.dominant.opacity(0.4), radius: 4, x: 0, y: 0)

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
            .fill(AppColors.surfaceTertiary)
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

// MARK: - Screen Header

struct ScreenHeader: View {
    let label: String
    let title: String
    var subtitle: String? = nil
    var trailingText: String? = nil
    var trailingIcon: String? = nil
    var accentColor: Color = AppColors.dominant
    var showAccentLine: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Top row: Label + Trailing content
            HStack(alignment: .center) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer()

                if let trailingText = trailingText {
                    HStack(spacing: AppSpacing.xs) {
                        if let icon = trailingIcon {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        Text(trailingText)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            // Main title
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.5)

            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Accent line
            if showAccentLine {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.6), accentColor.opacity(0.1), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(.bottom, AppSpacing.sm)
    }
}

// MARK: - Screen Header with Badge

struct ScreenHeaderWithBadge: View {
    let label: String
    let title: String
    var badgeText: String? = nil
    var badgeIcon: String? = nil
    var badgeColor: Color = AppColors.warning
    var trailingText: String? = nil
    var accentColor: Color = AppColors.dominant

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Top row: Label + Badge + Trailing
            HStack(alignment: .center) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer()

                // Badge on the right
                if let badgeText = badgeText {
                    HStack(spacing: 4) {
                        if let icon = badgeIcon {
                            Text(icon)
                                .font(.system(size: 12))
                        }
                        Text(badgeText)
                            .font(.caption.weight(.bold))
                            .foregroundColor(badgeColor)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(badgeColor.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }

                if let trailingText = trailingText {
                    Text(trailingText)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Title row
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.5)

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.6), accentColor.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.top, AppSpacing.xs)
        }
        .padding(.bottom, AppSpacing.sm)
    }
}
