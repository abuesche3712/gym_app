//
//  FriendsListView.swift
//  gym app
//
//  Main friends management view
//

import SwiftUI

struct FriendsListView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showingSearch = false
    @State private var showingRequests = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Pending Requests Section (if any)
                if !viewModel.incomingRequests.isEmpty {
                    pendingRequestsSection
                }

                // Outgoing Requests Section (if any)
                if !viewModel.outgoingRequests.isEmpty {
                    outgoingRequestsSection
                }

                // Suggested Friends Section (if any)
                if !viewModel.suggestedFriends.isEmpty {
                    suggestedFriendsSection
                }

                // Friends Section
                friendsSection

                // Blocked Users Section (if any)
                if !viewModel.blockedUsers.isEmpty {
                    blockedSection
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingSearch) {
            UserSearchView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingRequests) {
            FriendRequestsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.loadFriendships()
            viewModel.loadSuggestedFriends()
        }
        .refreshable {
            viewModel.loadFriendships()
        }
    }

    // MARK: - Pending Requests Section

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Friend Requests")
                    .headline(color: AppColors.textPrimary)

                Spacer()

                if viewModel.incomingRequests.count > 2 {
                    Button {
                        showingRequests = true
                    } label: {
                        Text("See All (\(viewModel.incomingRequests.count))")
                            .subheadline(color: AppColors.dominant)
                    }
                }
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.incomingRequests.prefix(2)) { request in
                    FriendRequestRow(
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
        }
        .padding(AppSpacing.md)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(AppCorners.large)
    }

    // MARK: - Outgoing Requests Section

    private var outgoingRequestsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Sent Requests")
                    .headline(color: AppColors.textPrimary)

                Spacer()

                Text("(\(viewModel.outgoingRequests.count))")
                    .subheadline(color: AppColors.textSecondary)
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.outgoingRequests) { request in
                    OutgoingRequestRow(
                        friendWithProfile: request,
                        onCancel: {
                            cancelRequest(request.friendship)
                        }
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(AppCorners.large)
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Friends")
                    .headline(color: AppColors.textPrimary)

                if !viewModel.friends.isEmpty {
                    Text("(\(viewModel.friends.count))")
                        .subheadline(color: AppColors.textSecondary)
                }

                Spacer()
            }

            if viewModel.isLoading && viewModel.friends.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xl)
            } else if viewModel.friends.isEmpty {
                emptyFriendsView
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.friends) { friend in
                        FriendRow(
                            friendWithProfile: friend,
                            onRemove: {
                                removeFriend(friend.friendship)
                            },
                            onBlock: {
                                blockUser(friend.friendship.otherUserId(from: viewModel.currentUserId ?? "") ?? "")
                            }
                        )

                        if friend.id != viewModel.friends.last?.id {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.large)
            }
        }
    }

    private var emptyFriendsView: some View {
        EmptyStateView(
            icon: "person.2",
            title: "No friends yet",
            subtitle: "Search for friends to connect with",
            buttonTitle: "Find Friends",
            buttonIcon: "magnifyingglass",
            onButtonTap: { showingSearch = true }
        )
    }

    // MARK: - Suggested Friends Section

    private var suggestedFriendsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Suggested Friends")
                    .headline(color: AppColors.textPrimary)

                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(viewModel.suggestedFriends) { suggestion in
                    SuggestedFriendRow(
                        searchResult: suggestion,
                        onAdd: {
                            addSuggestedFriend(suggestion.firebaseUserId)
                        }
                    )

                    if suggestion.id != viewModel.suggestedFriends.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(AppColors.surfaceSecondary)
            .cornerRadius(AppCorners.large)
        }
    }

    // MARK: - Blocked Section

    private var blockedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Blocked Users")
                .headline(color: AppColors.textPrimary)

            VStack(spacing: 0) {
                ForEach(viewModel.blockedUsers) { blocked in
                    BlockedUserRow(
                        friendWithProfile: blocked,
                        onUnblock: {
                            unblockUser(blocked.friendship)
                        }
                    )

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

    private func cancelRequest(_ friendship: Friendship) {
        Task {
            do {
                try await viewModel.removeFriend(friendship)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func removeFriend(_ friendship: Friendship) {
        Task {
            do {
                try await viewModel.removeFriend(friendship)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func blockUser(_ userId: String) {
        Task {
            do {
                try await viewModel.blockUser(userId)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func addSuggestedFriend(_ userId: String) {
        Task {
            do {
                try await viewModel.sendRequest(to: userId)
                // Remove from suggestions after sending request
                viewModel.suggestedFriends.removeAll { $0.firebaseUserId == userId }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
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

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let friendWithProfile: FriendWithProfile
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        UserRowView(profile: friendWithProfile.profile, avatarSize: 44) {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(AppColors.textSecondary)

                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.dominant)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.medium)
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow: View {
    let friendWithProfile: FriendWithProfile
    let onCancel: () -> Void

    var body: some View {
        UserRowView(
            profile: friendWithProfile.profile,
            avatarSize: 44,
            avatarColor: AppColors.textTertiary,
            subtitle: "Pending"
        ) {
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.medium)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friendWithProfile: FriendWithProfile
    let onRemove: () -> Void
    let onBlock: () -> Void

    var body: some View {
        UserRowView(profile: friendWithProfile.profile, avatarSize: 48) {
            Menu {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove Friend", systemImage: "person.badge.minus")
                }

                Button(role: .destructive) {
                    onBlock()
                } label: {
                    Label("Block User", systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.sm)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Blocked User Row

struct BlockedUserRow: View {
    let friendWithProfile: FriendWithProfile
    let onUnblock: () -> Void

    var body: some View {
        UserRowView(
            profile: friendWithProfile.profile,
            avatarSize: 48,
            avatarColor: AppColors.error
        ) {
            Button {
                onUnblock()
            } label: {
                Text("Unblock")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Suggested Friend Row

struct SuggestedFriendRow: View {
    let searchResult: UserSearchResult
    let onAdd: () -> Void

    var body: some View {
        UserRowView(profile: searchResult.profile, avatarSize: 48) {
            Button {
                onAdd()
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

#Preview {
    NavigationStack {
        FriendsListView()
    }
}
