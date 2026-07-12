//
//  SessionCompleteOverlay.swift
//  gym app
//
//  Workout complete animation overlay
//

import SwiftUI

// MARK: - Module Transition Overlay

struct ModuleTransitionOverlay: View {
    let completedModuleName: String
    let nextModuleName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                // Completed module
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .displayMedium(color: AppColors.success)

                    Text(completedModuleName)
                        .headline(color: AppColors.textSecondary)
                }
                .opacity(0.6)

                // Arrow
                Image(systemName: "arrow.down")
                    .displaySmall(color: AppColors.textTertiary)
                    .fontWeight(.light)

                // Next module
                VStack(spacing: AppSpacing.sm) {
                    Text(nextModuleName)
                        .displayMedium(color: AppColors.textPrimary)
                }
            }
            .padding(AppSpacing.xl)
        }
        .transition(.opacity)
        // This transition always reads as a dark, dramatic scrim (Color.black
        // above) regardless of the app's light/dark appearance setting, so the
        // adaptive AppColors text tokens must resolve dark here too or they'd
        // render near-illegible dark-on-black in light mode.
        .colorScheme(.dark)
    }
}

// MARK: - Workout Complete Overlay

struct WorkoutCompleteOverlay: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Binding var showingWorkoutSummary: Bool

    @State private var checkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var statsOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Animated checkmark
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(AppColors.success.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)

                    // Inner fill
                    Circle()
                        .fill(AppColors.success.opacity(0.15))
                        .frame(width: 120, height: 120)

                    // Checkmark
                    Image(systemName: "checkmark")
                        .displayLarge(color: AppColors.success)
                        .scaleEffect(checkScale)
                }

                // Stats summary
                if let session = sessionViewModel.currentSession {
                    VStack(spacing: AppSpacing.lg) {
                        Text(session.workoutName)
                            .displayMedium(color: AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xl) {
                            statItem(value: formatTime(sessionViewModel.sessionElapsedSeconds), label: "Time")
                            statItem(value: "\(session.totalSetsCompleted)", label: "Sets")
                            statItem(value: "\(session.totalExercisesCompleted)", label: "Exercises")
                        }
                    }
                    .opacity(statsOpacity)
                }

                Spacer()

                // Finish button
                Button {
                    showingWorkoutSummary = true
                } label: {
                    Text("Finish")
                        .headline(color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppGradients.dominantGradient)
                        )
                }
                .padding(.horizontal, AppSpacing.xl)
                .opacity(statsOpacity)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        // Same reasoning as ModuleTransitionOverlay: keep this celebratory
        // full-bleed scrim dark regardless of the app's appearance setting so
        // the adaptive text/success tokens stay legible against the black backdrop.
        .colorScheme(.dark)
        .onAppear {
            // One short reward sequence; this is a rare completion moment.
            withAnimation(reduceMotion ? nil : AppMotion.celebration.delay(0.05)) {
                checkScale = 1.0
            }
            withAnimation(reduceMotion ? nil : AppMotion.reveal.delay(0.05)) {
                ringScale = 1.0
            }
            withAnimation(reduceMotion ? nil : AppMotion.reveal.delay(0.18)) {
                statsOpacity = 1.0
            }
        }
        .transition(.opacity)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .displayMedium(color: AppColors.textPrimary)
            Text(label)
                .caption(color: AppColors.textTertiary)
        }
    }
}

// MARK: - Workout Complete View (fallback)

struct WorkoutCompleteView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .displayLarge(color: AppColors.success)
            }

            Text("Done")
                .displayMedium(color: AppColors.textPrimary)

            Spacer()
        }
        .padding(AppSpacing.xl)
    }
}
