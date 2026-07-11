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
//  - AppAnimations.swift  (animation definitions)
//  - Font+Extensions.swift (typography system)
//

import SwiftUI

struct SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                AppColors.surfaceSecondary
                .ignoresSafeArea()
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Compatibility name for Program cards. The old implementation did not use its
    /// accent parameter, so these cards now share the canonical card treatment.
    func gradientCard(accent _: Color = AppColors.dominant, padding: CGFloat = AppSpacing.cardPadding) -> some View {
        unifiedCard(padding: padding)
    }

    func sheetBackground() -> some View {
        modifier(SheetBackgroundModifier())
    }

    func glowShadow(_ color: Color = AppColors.dominant) -> some View {
        shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 0)
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
        .buttonStyle(.pressable)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppColors.surfaceTertiary)

                // Progress fill. Motion communicates a changed value; it does
                // not shimmer continuously while the user is reading it.
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(gradient)
                    .frame(width: max(0, geometry.size.width * animatedProgress))
                    .shadow(color: showGlow ? AppColors.dominant.opacity(0.2) : .clear, radius: 3, x: 0, y: 0)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : AppMotion.reveal) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(reduceMotion ? nil : AppMotion.stateChange) {
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
    /// Applies a short, quiet reveal for newly loaded content. Repeated lists
    /// should never make people wait through a staged entrance.
    func listItemAnimation(index: Int, total: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                AppMotion.reveal.delay(min(Double(index), 3) * 0.02),
                value: total
            )
    }
}
