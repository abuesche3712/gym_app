//
//  AnalyticsView.swift
//  gym app
//
//  Analytics and insights - coming soon
//

import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Custom header
                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Spacer()

                            // Settings button
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                            }
                        }

                        // Bottom border
                        Rectangle()
                            .fill(AppColors.surfaceTertiary)
                            .frame(height: 1)
                    }

                    // Coming soon content
                    VStack(spacing: AppSpacing.xl) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppColors.dominant.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.dominant)
                        }

                        // Description
                        VStack(spacing: AppSpacing.sm) {
                            Text("Track your progress, analyze trends, and optimize your training")
                                .body(color: AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Coming Soon Badge
                        Text("COMING SOON")
                            .caption(color: .white)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.dominant)
                            .cornerRadius(20)
                    }
                    .padding(.top, AppSpacing.xl)

                    // Feature Preview Cards
                    VStack(spacing: AppSpacing.md) {
                        AnalyticsPreviewCard(
                            icon: "chart.bar.fill",
                            title: "Volume Tracking",
                            description: "Monitor sets, reps, and tonnage over time"
                        )

                        AnalyticsPreviewCard(
                            icon: "arrow.up.right.circle.fill",
                            title: "Strength Progress",
                            description: "See your PR history and progression"
                        )

                        AnalyticsPreviewCard(
                            icon: "calendar.circle.fill",
                            title: "Consistency Metrics",
                            description: "Track workout frequency and streaks"
                        )

                        AnalyticsPreviewCard(
                            icon: "figure.walk.circle.fill",
                            title: "Body Metrics",
                            description: "Log and visualize body measurements"
                        )

                        AnalyticsPreviewCard(
                            icon: "brain.head.profile",
                            title: "AI Insights",
                            description: "Personalized recommendations"
                        )
                    }
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, 56)  // Account for custom tab bar height
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Analytics Preview Card

struct AnalyticsPreviewCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.dominant)
                .frame(width: 44, height: 44)
                .background(AppColors.dominant.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .headline(color: AppColors.textPrimary)

                Text(description)
                    .subheadline(color: AppColors.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    AnalyticsView()
}
