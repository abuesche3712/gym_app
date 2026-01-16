//
//  SocialView.swift
//  gym app
//
//  Social features - coming soon
//

import SwiftUI

struct SocialView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                    }

                    // Title and Description
                    VStack(spacing: 12) {
                        Text("Social")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Connect with friends, share progress, and stay motivated together")
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
                        .background(Color.orange)
                        .cornerRadius(20)

                    // Feature Preview Cards
                    VStack(spacing: 16) {
                        FeaturePreviewCard(
                            icon: "person.badge.plus",
                            title: "Add Friends",
                            description: "Connect with workout partners"
                        )

                        FeaturePreviewCard(
                            icon: "chart.bar.fill",
                            title: "Share Progress",
                            description: "Celebrate achievements together"
                        )

                        FeaturePreviewCard(
                            icon: "flame.fill",
                            title: "Challenges",
                            description: "Compete in fitness challenges"
                        )

                        FeaturePreviewCard(
                            icon: "message.fill",
                            title: "Group Chats",
                            description: "Stay connected with your gym crew"
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("Social")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Feature Preview Card

struct FeaturePreviewCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.15))
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
    SocialView()
}
