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
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Image(systemName: "person.badge.clock")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No pending requests")
                .headline(color: AppColors.textSecondary)

            Text("When someone sends you a friend request, it will appear here")
                .caption(color: AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer()
        }
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
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                // Avatar
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(avatarInitials)
                            .headline(color: AppColors.dominant)
                            .fontWeight(.bold)
                    }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = profile.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .headline(color: AppColors.textPrimary)
                    }

                    Text("@\(profile.username)")
                        .subheadline(color: AppColors.textSecondary)

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .caption(color: AppColors.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // Actions
            HStack(spacing: AppSpacing.md) {
                Button {
                    onDecline()
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.textSecondary)

                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.dominant)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
    }

    private var avatarInitials: String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }
}

#Preview {
    FriendRequestsView(viewModel: FriendsViewModel())
}
