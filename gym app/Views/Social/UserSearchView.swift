//
//  UserSearchView.swift
//  gym app
//
//  Search for users by username
//

import SwiftUI

struct UserSearchView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Results
                if viewModel.isSearching {
                    loadingView
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    emptyView
                } else {
                    resultsList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)

            TextField("Search by username", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, newValue in
                    viewModel.search(query: newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.medium)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .caption(color: AppColors.textSecondary)
                .padding(.top, AppSpacing.sm)
            Spacer()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "person.slash")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No users found")
                .headline(color: AppColors.textSecondary)

            Text("Try searching for a different username")
                .caption(color: AppColors.textTertiary)
            Spacer()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    UserSearchRow(
                        profile: result.profile,
                        status: viewModel.friendshipStatus(with: result.firebaseUserId),
                        onAddFriend: {
                            Task {
                                try? await viewModel.sendRequest(to: result.firebaseUserId)
                            }
                        },
                        onAcceptRequest: { friendship in
                            Task {
                                try? await viewModel.acceptRequest(friendship)
                            }
                        }
                    )

                    Divider()
                        .padding(.leading, 76)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let profile: UserProfile
    let status: FriendshipStatusCheck
    let onAddFriend: () -> Void
    let onAcceptRequest: (Friendship) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.dominant.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay {
                    Text(avatarInitials)
                        .headline(color: AppColors.dominant)
                        .fontWeight(.semibold)
                }

            // User info
            VStack(alignment: .leading, spacing: 2) {
                if let displayName = profile.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .headline(color: AppColors.textPrimary)
                }

                Text("@\(profile.username)")
                    .subheadline(color: AppColors.textSecondary)
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(.vertical, AppSpacing.md)
    }

    private var avatarInitials: String {
        if let displayName = profile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(2)).uppercased()
        }
        return String(profile.username.prefix(2)).uppercased()
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .none:
            Button {
                onAddFriend()
            } label: {
                Label("Add", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppColors.dominant)

        case .friends:
            Label("Friends", systemImage: "checkmark")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.success)

        case .outgoingRequest:
            Text("Requested")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textSecondary)

        case .incomingRequest(let friendship):
            Button {
                onAcceptRequest(friendship)
            } label: {
                Text("Accept")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)

        case .blockedByMe, .blockedByThem:
            EmptyView()
        }
    }
}

#Preview {
    UserSearchView(viewModel: FriendsViewModel())
}
