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
    }
}

// MARK: - Workout Complete Overlay

struct WorkoutCompleteOverlay: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Binding var showingWorkoutSummary: Bool

    @State private var checkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var statsOpacity: Double = 0

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
        .onAppear {
            // Animate in sequence
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                checkScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                ringScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
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
