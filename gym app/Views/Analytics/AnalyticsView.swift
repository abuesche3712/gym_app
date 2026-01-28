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
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.dominant.opacity(0.15))
                            .frame(width: 120, height: 120)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.dominant)
                    }

                    // Title and Description
                    VStack(spacing: 12) {
                        Text("Analytics")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Track your progress, analyze trends, and optimize your training")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Coming Soon Badge
                    Text("COMING SOON")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.dominant)
                        .cornerRadius(20)

                    // Feature Preview Cards
                    VStack(spacing: 16) {
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
                    .padding(.horizontal)
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("Analytics")
            .background(Color(.systemGroupedBackground))
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
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
