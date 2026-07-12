//
//  BlockedUsersView.swift
//  gym app
//
//  Lists blocked users with the ability to unblock them
//

import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, AppSpacing.xl)
                } else if viewModel.blockedUsers.isEmpty {
                    EmptyStateView(
                        icon: "hand.raised",
                        title: "No Blocked Users",
                        subtitle: "Users you block won't be able to see your posts or message you."
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.blockedUsers) { blocked in
                            UserRowView(
                                profile: blocked.profile,
                                avatarSize: 48,
                                avatarColor: AppColors.error
                            ) {
                                Button {
                                    unblockUser(blocked.friendship)
                                } label: {
                                    Text("Unblock")
                                        .font(.subheadline.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                                .tint(AppColors.textSecondary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)

                            if blocked.id != viewModel.blockedUsers.last?.id {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                    .background(AppColors.surfaceSecondary)
                    .cornerRadius(AppCorners.large)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadFriendships()
        }
        .refreshable {
            viewModel.loadFriendships()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func unblockUser(_ friendship: Friendship) {
        Task {
            do {
                try await viewModel.unblockUser(friendship)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}
