//
//  ActivityFeedView.swift
//  gym app
//
//  Activity/notification feed view
//

import SwiftUI

struct ActivityFeedView: View {
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.activities.isEmpty {
                VStack {
                    Spacer().frame(height: 100)
                    ProgressView()
                    Text("Loading notifications...")
                        .caption(color: AppColors.textSecondary)
                        .padding(.top, AppSpacing.sm)
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.activities.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.activities) { activity in
                        ActivityRow(activity: activity)
                            .onAppear {
                                if !activity.activity.isRead {
                                    viewModel.markAsRead(activity)
                                }
                            }

                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .refreshable { viewModel.loadActivities() }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.activities.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.markAllAsRead()
                    } label: {
                        Text("Read All")
                            .font(.subheadline)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadActivities()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: "No Notifications",
            subtitle: "When friends interact with your posts, you'll see it here"
        )
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityWithActor

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Actor avatar
            ProfilePhotoView(
                profile: activity.actor,
                size: 40,
                borderWidth: 0
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.activity.descriptionText(
                    actorName: activity.actor.displayName ?? activity.actor.username
                ))
                .font(.subheadline)
                .foregroundColor(activity.activity.isRead ? AppColors.textSecondary : AppColors.textPrimary)

                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Activity type icon
            Image(systemName: activity.activity.icon)
                .font(.caption)
                .foregroundColor(iconColor)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.md)
        .background(activity.activity.isRead ? AppColors.background : AppColors.dominant.opacity(0.05))
    }

    private var iconColor: Color {
        switch activity.activity.type {
        case .like: return AppColors.error
        case .comment: return AppColors.dominant
        case .friendRequest: return AppColors.accent2
        case .friendAccepted: return AppColors.success
        }
    }

    private var relativeTime: String {
        let now = Date()
        let seconds = now.timeIntervalSince(activity.activity.createdAt)

        if seconds < 60 { return "now" }
        else if seconds < 3600 { return "\(Int(seconds / 60))m" }
        else if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        else if seconds < 604800 { return "\(Int(seconds / 86400))d" }
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: activity.activity.createdAt)
        }
    }
}
