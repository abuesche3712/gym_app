//
//  AnimatedComponents.swift
//  gym app
//
//  Delightful animated UI components
//

import SwiftUI

// MARK: - Animated Number

/// A number that animates smoothly when changed (slot machine style)
struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var animatedValue: Int = 0

    var body: some View {
        Text("\(animatedValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: Double(animatedValue)))
            .animation(.snappy(duration: 0.3), value: animatedValue)
            .onChange(of: value) { _, newValue in
                animatedValue = newValue
            }
            .onAppear {
                animatedValue = value
            }
    }
}

/// Animated decimal number (for weights like 135.5)
struct AnimatedDecimalNumber: View {
    let value: Double
    let decimals: Int
    let font: Font
    let color: Color

    var body: some View {
        Text(String(format: "%.\(decimals)f", value))
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.3), value: value)
    }
}

// MARK: - Animated Checkmark

/// A checkmark that draws itself with animation
struct AnimatedCheckmark: View {
    let isChecked: Bool
    let size: CGFloat
    let color: Color
    let lineWidth: CGFloat

    @State private var trimEnd: CGFloat = 0

    init(isChecked: Bool, size: CGFloat = 24, color: Color = AppColors.success, lineWidth: CGFloat = 3) {
        self.isChecked = isChecked
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isChecked ? color.opacity(0.15) : Color.clear)
                .frame(width: size, height: size)

            // Checkmark path
            CheckmarkShape()
                .trim(from: 0, to: trimEnd)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .onChange(of: isChecked) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                trimEnd = newValue ? 1 : 0
            }
            if newValue {
                HapticManager.shared.setCompleted()
            }
        }
        .onAppear {
            trimEnd = isChecked ? 1 : 0
        }
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Draw checkmark: start at left, go down to bottom middle, then up to top right
        path.move(to: CGPoint(x: width * 0.1, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.8))
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.2))

        return path
    }
}

// MARK: - Glowing Set Row

/// A view modifier that adds a completion glow effect
struct CompletionGlow: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var glowOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(color.opacity(glowOpacity))
            )
            .onChange(of: isActive) { wasActive, nowActive in
                if !wasActive && nowActive {
                    // Trigger glow animation
                    withAnimation(.easeIn(duration: 0.15)) {
                        glowOpacity = 0.3
                    }
                    withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                        glowOpacity = 0
                    }
                }
            }
    }
}

extension View {
    func completionGlow(isActive: Bool, color: Color = AppColors.success) -> some View {
        modifier(CompletionGlow(isActive: isActive, color: color))
    }
}

// MARK: - Animated Counter Button

/// A stepper-style button with haptic feedback and animated numbers
struct AnimatedStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let label: String
    let unit: String

    init(value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1, label: String, unit: String = "") {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack(spacing: AppSpacing.md) {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                        HapticManager.shared.increment()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value <= range.lowerBound ? AppColors.textTertiary : AppColors.dominant)
                }
                .disabled(value <= range.lowerBound)

                HStack(spacing: 2) {
                    AnimatedNumber(value: value, font: .monoSmall, color: AppColors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .caption2()
                    }
                }
                .frame(minWidth: 50)

                Button {
                    if value + step <= range.upperBound {
                        value += step
                        HapticManager.shared.increment()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value >= range.upperBound ? AppColors.textTertiary : AppColors.dominant)
                }
                .disabled(value >= range.upperBound)
            }
        }
    }
}

// MARK: - Pull to Refresh Dumbbell

/// Custom refresh indicator with a lifting dumbbell
struct DumbbellRefreshView: View {
    let isRefreshing: Bool
    let progress: CGFloat // 0-1 pull progress

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Dumbbell icon
            Image(systemName: "dumbbell.fill")
                .font(.title2.bold())
                .foregroundColor(AppColors.dominant)
                .rotationEffect(.degrees(isRefreshing ? rotation : Double(-45) + Double(progress) * 45.0))
                .scaleEffect(0.8 + (progress * 0.2))
                .opacity(0.3 + (progress * 0.7))
        }
        .onChange(of: isRefreshing) { _, refreshing in
            if refreshing {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

// MARK: - Pulsing Indicator

/// A pulsing dot indicator (for active states)
struct PulsingIndicator: View {
    let color: Color
    let size: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .opacity(isPulsing ? 0 : 0.5)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Bouncy Button Style

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    Task { @MainActor in
                        HapticManager.shared.buttonPress()
                    }
                }
            }
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle { BouncyButtonStyle() }
}

// MARK: - Scale Press Button Style

struct ScalePressButtonStyle: ButtonStyle {
    let scale: CGFloat

    init(scale: CGFloat = 0.97) {
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Animated checkmark demo
        HStack(spacing: 20) {
            AnimatedCheckmark(isChecked: true)
            AnimatedCheckmark(isChecked: false)
        }

        // Animated number demo
        AnimatedNumber(value: 135, font: .largeTitle.bold(), color: AppColors.textPrimary)

        // Pulsing indicator
        PulsingIndicator(color: AppColors.success, size: 12)

        // Dumbbell refresh
        DumbbellRefreshView(isRefreshing: true, progress: 1.0)
    }
    .padding()
}
