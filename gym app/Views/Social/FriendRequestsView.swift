//
//  FriendRequestsView.swift
//  gym app
//
//  Dedicated view for managing incoming friend requests
//

import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.incomingRequests.isEmpty {
                    emptyView
                } else {
                    requestsList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        EmptyStateView(
            icon: "person.badge.clock",
            title: "No pending requests",
            subtitle: "When someone sends you a friend request, it will appear here"
        )
    }

    // MARK: - Requests List

    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(viewModel.incomingRequests) { request in
                    FriendRequestCard(
                        friendWithProfile: request,
                        onAccept: {
                            acceptRequest(request.friendship)
                        },
                        onDecline: {
                            declineRequest(request.friendship)
                        }
                    )
                }
            }
            .padding(AppSpacing.screenPadding)
        }
    }

    // MARK: - Actions

    private func acceptRequest(_ friendship: Friendship) {
        Task {
            do {
                try await viewModel.acceptRequest(friendship)
                HapticManager.shared.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func declineRequest(_ friendship: Friendship) {
        Task {
            do {
                try await viewModel.declineRequest(friendship)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Friend Request Card

struct FriendRequestCard: View {
    let friendWithProfile: FriendWithProfile
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var profile: UserProfile { friendWithProfile.profile }

    var body: some View {
        UserRowView(
            profile: profile,
            avatarSize: 56,
            bio: profile.bio
        ) {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.textSecondary)

                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.medium))
                        .frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.dominant)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
    }
}

#Preview {
    FriendRequestsView(viewModel: FriendsViewModel())
}
