//
//  AnimatedComponents.swift
//  gym app
//
//  Delightful animated UI components
//

import SwiftUI

// MARK: - Animated Checkmark

/// A checkmark that draws itself with animation
struct AnimatedCheckmark: View {
    let isChecked: Bool
    let size: CGFloat
    let color: Color
    let lineWidth: CGFloat

    @State private var trimEnd: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            withAnimation(reduceMotion ? nil : AppMotion.celebration) {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(color.opacity(glowOpacity))
            )
            .onChange(of: isActive) { wasActive, nowActive in
                if !wasActive && nowActive {
                    // Trigger glow animation
                    withAnimation(reduceMotion ? nil : AppMotion.press) {
                        glowOpacity = 0.3
                    }
                    withAnimation(reduceMotion ? nil : AppMotion.reveal.delay(0.08)) {
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

/// The default tactile response for custom buttons. Unlike `.plain`, this
/// maintains a quiet press acknowledgement without competing with the content.
struct PressableButtonStyle: ButtonStyle {
    private let sendsHapticFeedback: Bool
    private let dimsWhenPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(sendsHapticFeedback: Bool = false, dimsWhenPressed: Bool = true) {
        self.sendsHapticFeedback = sendsHapticFeedback
        self.dimsWhenPressed = dimsWhenPressed
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && dimsWhenPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard sendsHapticFeedback, isPressed else { return }
                Task { @MainActor in
                    HapticManager.shared.buttonPress()
                }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static var bouncy: PressableButtonStyle {
        PressableButtonStyle(sendsHapticFeedback: true, dimsWhenPressed: false)
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

    }
    .padding()
}
