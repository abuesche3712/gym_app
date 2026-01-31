//
//  NewConversationSheet.swift
//  gym app
//
//  Sheet for starting a new conversation with a friend
//

import SwiftUI

struct NewConversationSheet: View {
    @ObservedObject var viewModel: ConversationsViewModel
    let onSelect: (ConversationWithProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if friendsViewModel.isLoading && friendsViewModel.friends.isEmpty {
                    loadingView
                } else if friendsViewModel.friends.isEmpty {
                    emptyView
                } else {
                    friendsList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                friendsViewModel.loadFriendships()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Spacer()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No friends yet")
                .headline(color: AppColors.textSecondary)

            Text("Add friends to start messaging")
                .caption(color: AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Friends List

    private var friendsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(friendsViewModel.friends) { friend in
                    friendRow(friend)

                    if friend.id != friendsViewModel.friends.last?.id {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(AppColors.surfaceSecondary)
            .cornerRadius(AppCorners.large)
            .padding(AppSpacing.screenPadding)
        }
    }

    private func friendRow(_ friend: FriendWithProfile) -> some View {
        Button {
            startConversation(with: friend)
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Avatar
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(avatarInitials(for: friend.profile))
                            .headline(color: AppColors.dominant)
                            .fontWeight(.semibold)
                    }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.profile.displayName ?? friend.profile.username)
                        .headline(color: AppColors.textPrimary)

                    Text("@\(friend.profile.username)")
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func avatarInitials(for profile: UserProfile) -> String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }

    private func startConversation(with friend: FriendWithProfile) {
        // Get the friend's Firebase UID
        guard let friendFirebaseId = friend.friendship.otherUserId(from: viewModel.currentUserId ?? "") else {
            errorMessage = "Could not find user"
            showError = true
            return
        }

        isLoading = true

        Task {
            do {
                let conversation = try await viewModel.startConversation(with: friendFirebaseId)

                // Create the ConversationWithProfile to pass back
                let conversationWithProfile = ConversationWithProfile(
                    conversation: conversation,
                    otherParticipant: friend.profile,
                    otherParticipantFirebaseId: friendFirebaseId
                )

                dismiss()
                onSelect(conversationWithProfile)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

#Preview {
    NewConversationSheet(viewModel: ConversationsViewModel()) { _ in }
}
