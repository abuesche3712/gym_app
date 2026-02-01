//
//  SocialView.swift
//  gym app
//
//  Social tab - feed-first social experience
//

import SwiftUI

struct SocialView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var dataRepository = DataRepository.shared
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @StateObject private var conversationsViewModel = ConversationsViewModel()

    @State private var showingSignIn = false
    @State private var showingComposeSheet = false
    @State private var selectedPost: PostWithAuthor?

    private var profileRepo: ProfileRepository {
        dataRepository.profileRepo
    }

    var body: some View {
        NavigationStack {
            if authService.isAuthenticated {
                authenticatedFeedView
            } else {
                signInPromptView
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showingComposeSheet) {
            ComposePostSheet()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
        .onAppear {
            if authService.isAuthenticated {
                friendsViewModel.loadFriendships()
                conversationsViewModel.loadConversations()
                feedViewModel.loadFeed()
            }
        }
        // Reload feed when friends list changes (ensures feed includes new friends' posts)
        .onChange(of: friendsViewModel.friends.count) { _, _ in
            if authService.isAuthenticated {
                feedViewModel.loadFeed()
            }
        }
    }

    // MARK: - Authenticated Feed View

    private var authenticatedFeedView: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main feed content
            ScrollView {
                VStack(spacing: 0) {
                    // Custom header
                    socialHeader
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.md)

                    // Feed content
                    LazyVStack(spacing: 0) {
                        if feedViewModel.isLoading && feedViewModel.posts.isEmpty {
                            loadingView
                        } else if feedViewModel.posts.isEmpty {
                            emptyFeedState
                        } else {
                            feedList
                        }
                    }
                }
            }
            .refreshable {
                await feedViewModel.refreshFeed()
                friendsViewModel.loadFriendships()
                conversationsViewModel.loadConversations()
            }

            // Floating compose button
            composeButton
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Social Header

    private var socialHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                // Profile button (left side)
                NavigationLink(destination: AccountProfileView()) {
                    profileAvatar
                }

                Spacer()

                HStack(spacing: AppSpacing.md) {
                    // Search button
                    NavigationLink(destination: UserSearchView(viewModel: friendsViewModel)) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }

                    // Messages button
                    NavigationLink(destination: ConversationsListView()) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)

                            // Unread badge
                            if conversationsViewModel.totalUnreadCount > 0 {
                                Circle()
                                    .fill(AppColors.accent2)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }

                    // Settings button
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                }
            }

            // Bottom border
            Rectangle()
                .fill(AppColors.surfaceTertiary)
                .frame(height: 1)
        }
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        Circle()
            .fill(AppColors.accent2.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay {
                Text(avatarInitials)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.accent2)
            }
            .overlay {
                Circle()
                    .stroke(AppColors.accent2.opacity(0.3), lineWidth: 1.5)
            }
    }

    private var avatarInitials: String {
        if let profile = profileRepo.currentProfile {
            if let displayName = profile.displayName, !displayName.isEmpty {
                return String(displayName.prefix(1)).uppercased()
            }
            if !profile.username.isEmpty {
                return String(profile.username.prefix(1)).uppercased()
            }
        }
        return "?"
    }

    // MARK: - Compose Button

    private var composeButton: some View {
        Button {
            HapticManager.shared.impact()
            showingComposeSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppGradients.socialGradient)
                        .shadow(color: AppColors.accent2.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
        .padding(.trailing, AppSpacing.screenPadding)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .tint(AppColors.accent2)
            Text("Loading feed...")
                .subheadline(color: AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty Feed State

    private var emptyFeedState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
                .frame(height: 60)

            // Empty state icon
            ZStack {
                Circle()
                    .fill(AppColors.accent2.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "rectangle.stack")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.accent2.opacity(0.6))
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Your Feed is Empty")
                    .headline(color: AppColors.textPrimary)

                Text("Add friends to see their workouts and progress")
                    .subheadline(color: AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            NavigationLink {
                UserSearchView(viewModel: friendsViewModel)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.badge.plus")
                    Text("Find Friends")
                }
                .headline(color: .white)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(
                    Capsule()
                        .fill(AppColors.accent2)
                )
            }
            .padding(.top, AppSpacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Feed List

    private var feedList: some View {
        LazyVStack(spacing: AppSpacing.md) {
            ForEach(feedViewModel.posts) { post in
                PostCard(
                    post: post,
                    onLike: {
                        Task {
                            await feedViewModel.toggleLike(for: post)
                        }
                    },
                    onComment: {
                        selectedPost = post
                    },
                    onDelete: post.post.authorId == feedViewModel.currentUserId ? {
                        Task {
                            await feedViewModel.deletePost(post)
                        }
                    } : nil,
                    onProfileTap: {
                        // Profile viewing can be added later
                    }
                )
                .onAppear {
                    // Load more when reaching the end
                    if post.id == feedViewModel.posts.last?.id {
                        Task {
                            await feedViewModel.loadMorePosts()
                        }
                    }
                }
            }

            if feedViewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColors.accent2)
                    .padding(AppSpacing.lg)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.bottom, 80) // Space for FAB
    }

    // MARK: - Sign In Prompt

    private var signInPromptView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                    .frame(height: 60)

                // Hero section
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent2.opacity(0.1))
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(AppColors.accent2.opacity(0.15))
                            .frame(width: 90, height: 90)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.accent2)
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text("Connect & Share")
                            .displayMedium(color: AppColors.textPrimary)

                        Text("Join the community to share your progress and stay motivated with friends")
                            .subheadline(color: AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                }

                // Sign in button
                Button {
                    showingSignIn = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                    }
                    .headline(color: AppColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.textPrimary)
                    .cornerRadius(AppCorners.medium)
                }
                .padding(.horizontal, AppSpacing.xl)

                // Feature cards
                VStack(spacing: AppSpacing.md) {
                    featureRow(
                        icon: "rectangle.stack.fill",
                        title: "Share Workouts",
                        description: "Post your sessions to inspire others",
                        color: AppColors.accent2
                    )

                    featureRow(
                        icon: "heart.fill",
                        title: "Celebrate Progress",
                        description: "Like and comment on friends' achievements",
                        color: AppColors.success
                    )

                    featureRow(
                        icon: "paperplane.fill",
                        title: "Direct Messages",
                        description: "Chat and share tips with workout partners",
                        color: AppColors.accent3
                    )
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.md)

                Spacer()
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.large)
    }

    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .cornerRadius(AppCorners.medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .headline(color: AppColors.textPrimary)

                Text(description)
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .cornerRadius(AppCorners.large)
    }
}

// MARK: - Preview

#Preview {
    SocialView()
}
