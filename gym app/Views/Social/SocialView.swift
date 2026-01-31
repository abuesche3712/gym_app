//
//  SocialView.swift
//  gym app
//
//  Social tab - friends, profile, and social features
//

import SwiftUI

struct SocialView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var dataRepository = DataRepository.shared
    @StateObject private var friendsViewModel = FriendsViewModel()
    @StateObject private var conversationsViewModel = ConversationsViewModel()

    @State private var showingSignIn = false

    private var profileRepo: ProfileRepository {
        dataRepository.profileRepo
    }

    var body: some View {
        NavigationStack {
            if authService.isAuthenticated {
                authenticatedView
            } else {
                signInPromptView
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .onAppear {
            if authService.isAuthenticated {
                friendsViewModel.loadFriendships()
                conversationsViewModel.loadConversations()
            }
        }
    }

    // MARK: - Authenticated View

    private var authenticatedView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // My Profile Section
                myProfileSection

                // Messages Section
                messagesSection

                // Friends Section
                friendsSection

                // Search for Friends
                searchSection
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Social")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AccountProfileView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable {
            friendsViewModel.loadFriendships()
            conversationsViewModel.loadConversations()
        }
    }

    // MARK: - My Profile Section

    private var myProfileSection: some View {
        NavigationLink {
            AccountProfileView()
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Avatar
                Circle()
                    .fill(AppColors.dominant.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(avatarInitials)
                            .displaySmall(color: AppColors.dominant)
                            .fontWeight(.semibold)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    if let profile = profileRepo.currentProfile {
                        if let displayName = profile.displayName, !displayName.isEmpty {
                            Text(displayName)
                                .headline(color: AppColors.textPrimary)
                        }

                        if !profile.username.isEmpty {
                            Text("@\(profile.username)")
                                .subheadline(color: AppColors.textSecondary)
                        } else {
                            Text("Set up your profile")
                                .subheadline(color: AppColors.dominant)
                        }
                    } else {
                        Text("Set up your profile")
                            .headline(color: AppColors.textPrimary)
                        Text("Add a username and bio")
                            .subheadline(color: AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfaceSecondary)
            .cornerRadius(AppCorners.large)
        }
        .buttonStyle(.plain)
    }

    private var avatarInitials: String {
        if let profile = profileRepo.currentProfile {
            if let displayName = profile.displayName, !displayName.isEmpty {
                return String(displayName.prefix(2)).uppercased()
            }
            if !profile.username.isEmpty {
                return String(profile.username.prefix(2)).uppercased()
            }
        }
        return "?"
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NavigationLink {
                ConversationsListView()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent3)
                        .frame(width: 44, height: 44)
                        .background(AppColors.accent3.opacity(0.15))
                        .cornerRadius(AppCorners.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Messages")
                            .headline(color: AppColors.textPrimary)

                        if conversationsViewModel.totalUnreadCount > 0 {
                            Text("\(conversationsViewModel.totalUnreadCount) unread")
                                .caption(color: AppColors.accent3)
                        } else {
                            Text("Chat with friends")
                                .caption(color: AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Unread badge
                    if conversationsViewModel.totalUnreadCount > 0 {
                        Text("\(conversationsViewModel.totalUnreadCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accent3)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.large)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NavigationLink {
                FriendsListView()
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.dominant)
                        .frame(width: 44, height: 44)
                        .background(AppColors.dominant.opacity(0.15))
                        .cornerRadius(AppCorners.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Friends")
                            .headline(color: AppColors.textPrimary)

                        Text("\(friendsViewModel.friends.count) friends")
                            .caption(color: AppColors.textSecondary)
                    }

                    Spacer()

                    // Pending requests badge
                    if friendsViewModel.pendingRequestCount > 0 {
                        Text("\(friendsViewModel.pendingRequestCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.error)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.large)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NavigationLink {
                UserSearchView(viewModel: friendsViewModel)
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(AppColors.success)
                        .frame(width: 44, height: 44)
                        .background(AppColors.success.opacity(0.15))
                        .cornerRadius(AppCorners.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find Friends")
                            .headline(color: AppColors.textPrimary)

                        Text("Search by username")
                            .caption(color: AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppCorners.large)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sign In Prompt

    private var signInPromptView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.dominant.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "person.2.fill")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.dominant)
                }

                // Title and Description
                VStack(spacing: 12) {
                    Text("Social")
                        .displayLarge(color: AppColors.textPrimary)
                        .fontWeight(.bold)

                    Text("Sign in to connect with friends, share progress, and stay motivated together")
                        .body(color: AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Sign In Button
                Button {
                    showingSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.textPrimary)
                    .foregroundColor(AppColors.background)
                    .cornerRadius(AppCorners.medium)
                }
                .padding(.horizontal, AppSpacing.xl)

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
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Spacer()
            }
        }
        .navigationTitle("Social")
        .background(AppColors.background.ignoresSafeArea())
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
                .foregroundColor(AppColors.dominant)
                .frame(width: 44, height: 44)
                .background(AppColors.dominant.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .headline(color: AppColors.textPrimary)

                Text(description)
                    .subheadline(color: AppColors.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
    }
}

#Preview {
    SocialView()
}
