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
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No friends yet")
                .headline(color: AppColors.textSecondary)

            Text("Search for friends to connect with")
                .caption(color: AppColors.textTertiary)

            Button {
                showingSearch = true
            } label: {
                Label("Find Friends", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
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

    private var profile: UserProfile { friendWithProfile.profile }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.dominant.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(avatarInitials)
                        .subheadline(color: AppColors.dominant)
                        .fontWeight(.semibold)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .headline(color: AppColors.textPrimary)

                Text("@\(profile.username)")
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()

            // Actions
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

    private var avatarInitials: String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow: View {
    let friendWithProfile: FriendWithProfile
    let onCancel: () -> Void

    private var profile: UserProfile { friendWithProfile.profile }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.textTertiary.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(avatarInitials)
                        .subheadline(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .headline(color: AppColors.textPrimary)

                Text("@\(profile.username)")
                    .caption(color: AppColors.textSecondary)

                Text("Pending")
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()

            // Cancel button
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

    private var avatarInitials: String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friendWithProfile: FriendWithProfile
    let onRemove: () -> Void
    let onBlock: () -> Void

    @State private var showingOptions = false

    private var profile: UserProfile { friendWithProfile.profile }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.dominant.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(avatarInitials)
                        .headline(color: AppColors.dominant)
                        .fontWeight(.semibold)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .headline(color: AppColors.textPrimary)

                Text("@\(profile.username)")
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()

            // Options menu
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

    private var avatarInitials: String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }
}

// MARK: - Blocked User Row

struct BlockedUserRow: View {
    let friendWithProfile: FriendWithProfile
    let onUnblock: () -> Void

    private var profile: UserProfile { friendWithProfile.profile }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.error.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "hand.raised.slash")
                        .foregroundColor(AppColors.error)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .headline(color: AppColors.textSecondary)

                Text("@\(profile.username)")
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()

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

#Preview {
    NavigationStack {
        FriendsListView()
    }
}
