//
//  RestTimerBar.swift
//  gym app
//
//  Rest timer inline view for active session
//

import SwiftUI

struct RestTimerBar: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Binding var highlightNextSet: Bool

    private var isUrgent: Bool {
        sessionViewModel.restTimerSeconds <= 10
    }

    private var isLongTimer: Bool {
        sessionViewModel.restTimerTotal >= 60
    }

    private var isLongRest: Bool {
        sessionViewModel.restTimerTotal >= 180
    }

    private var timeDisplay: String {
        isLongTimer ? formatTime(sessionViewModel.restTimerSeconds) : "\(sessionViewModel.restTimerSeconds)"
    }

    private var ringSize: CGFloat {
        isLongTimer ? 44 : 36
    }

    private var fontSize: CGFloat {
        isLongTimer ? 11 : 12
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.surfaceTertiary, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: CGFloat(sessionViewModel.restTimerSeconds) / CGFloat(max(sessionViewModel.restTimerTotal, 1)))
                        .stroke(isUrgent ? AppColors.warning : AppColors.accent1, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: sessionViewModel.restTimerSeconds)

                    Text(timeDisplay)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppColors.textPrimary)
                        .minimumScaleFactor(0.7)
                }

                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest")
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.medium)
                    Text("\(timeDisplay) remaining")
                        .caption(color: AppColors.textTertiary)
                        .monospacedDigit()
                }

                Spacer()

                // X button (for long rests 3+ min)
                if isLongRest {
                    Button {
                        openTwitter()
                    } label: {
                        Text("𝕏")
                            .body(color: AppColors.textSecondary)
                            .fontWeight(.bold)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            .background(
                                Circle()
                                    .fill(AppColors.surfaceTertiary)
                            )
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel("Browse X during rest")
                }

                // Skip button
                Button {
                    sessionViewModel.stopRestTimer()
                    highlightNextSet = true
                } label: {
                    Text("Skip")
                        .subheadline(color: AppColors.dominant)
                        .fontWeight(.semibold)
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(
                            Capsule()
                                .fill(AppColors.dominant.opacity(0.1))
                        )
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel("Skip rest timer")
            }

        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(
                            isUrgent ? AppColors.warning.opacity(0.4) : AppColors.accent1.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: isUrgent ? AppColors.warning.opacity(0.15) : .clear,
            radius: isUrgent ? 12 : 0,
            x: 0,
            y: 4
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: sessionViewModel.isRestTimerRunning)
    }

    private func openTwitter() {
        // Try to open X/Twitter app first, fall back to web
        guard let twitterAppURL = URL(string: "twitter://"),
              let twitterWebURL = URL(string: "https://x.com") else { return }

        if UIApplication.shared.canOpenURL(twitterAppURL) {
            UIApplication.shared.open(twitterAppURL)
        } else {
            UIApplication.shared.open(twitterWebURL)
        }
    }
}
