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

    @EnvironmentObject var sessionViewModel: SessionViewModel

    @State private var showingSignIn = false
    @State private var showingComposeSheet = false
    @State private var selectedPost: PostWithAuthor?
    @State private var postToEdit: PostWithAuthor?
    @State private var postToShare: PostWithAuthor?
    @State private var profileToView: PostWithAuthor?
    @State private var showRestoreSuccess = false

    /// Owned by MainTabView so re-tapping the Social tab can pop to root
    /// (by clearing the path) without destroying and rebuilding this subtree.
    @Binding var path: NavigationPath

    private var profileRepo: ProfileRepository {
        dataRepository.profileRepo
    }

    var body: some View {
        NavigationStack(path: $path) {
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
        .sheet(item: $postToShare) { postWithAuthor in
            ShareWithFriendSheet(content: postWithAuthor.post)
        }
        .sheet(item: $profileToView) { postWithAuthor in
            NavigationStack {
                OtherUserProfileView(
                    profile: postWithAuthor.author,
                    firebaseUserId: postWithAuthor.post.authorId
                )
            }
        }
        .sheet(item: $postToEdit) { postWithAuthor in
            EditPostSheet(post: postWithAuthor.post) { updatedPost in
                Task<Void, Never> { @MainActor in
                    await feedViewModel.updatePost(updatedPost)
                }
            }
        }
        .onAppear {
            if authService.isAuthenticated {
                startSocialListeners()
            } else {
                stopSocialListeners()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                startSocialListeners()
            } else {
                stopSocialListeners()
            }
        }
        .alert("Session Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The workout has been added to your history.")
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

                    if feedViewModel.isLoading && feedViewModel.posts.isEmpty {
                        loadingView
                    } else if feedViewModel.error != nil && feedViewModel.posts.isEmpty {
                        errorFeedState
                    } else if feedViewModel.posts.isEmpty {
                        emptyFeedState
                    } else {
                        feedList
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await feedViewModel.refreshFeed()
                friendsViewModel.loadFriendships()
                conversationsViewModel.loadConversations()
            }

            // Floating compose button
            composeButton
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Social Header

    private var socialHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Social")
                    .elegantLabel(color: AppColors.dominant)
                Text("Community")
                    .displaySmall()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                // Profile button (left side)
                NavigationLink(destination: AccountProfileView()) {
                    profileAvatar
                }
                .buttonStyle(.pressable)

                Spacer()

                HStack(spacing: AppSpacing.md) {
                    // Search button
                    NavigationLink(destination: UserSearchView(viewModel: friendsViewModel)) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                    .buttonStyle(.pressable)

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
                    .buttonStyle(.pressable)

                    // Settings button
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        Group {
            if let profile = profileRepo.currentProfile {
                ProfilePhotoView.gold(profile: profile, size: 32)
            } else {
                Circle()
                    .fill(AppColors.dominantMuted)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.dominant)
                    }
                    .overlay {
                        Circle()
                            .stroke(AppColors.dominant.opacity(0.3), lineWidth: 1.5)
                    }
            }
        }
    }

    // MARK: - Compose Button

    private var composeButton: some View {
        Button {
            HapticManager.shared.impact()
            showingComposeSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(AppColors.background)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppColors.accent2)
                        .shadow(color: AppColors.accent2.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.pressable)
        .padding(.trailing, AppSpacing.screenPadding)
        .tabBarBottomPadding(extra: 24) // Clear tab bar + breathing room above it
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

    // MARK: - Error Feed State

    /// Shown when the feed listener fails and there's no cached data to fall back on.
    /// Without this, a listener error silently rendered as the "nothing here yet" empty
    /// state, which reads to the user as "you have no friends/posts" instead of "we
    /// couldn't load your feed" — indistinguishable failure modes that need different
    /// user actions (retry vs. add friends).
    private var errorFeedState: some View {
        EmptyStateView(
            icon: "wifi.exclamationmark",
            title: "Couldn't Load Feed",
            subtitle: feedViewModel.error?.localizedDescription ?? "Something went wrong. Please try again.",
            buttonTitle: "Retry",
            buttonIcon: "arrow.clockwise",
            onButtonTap: {
                feedViewModel.error = nil
                feedViewModel.loadFeed()
            }
        )
        .padding(.top, 60)
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

    // MARK: - Feed List (Twitter-style flat layout)

    private var feedList: some View {
        LazyVStack(spacing: 0) {
            ForEach(feedViewModel.filteredFeedPosts) { post in
                VStack(spacing: 0) {
                    // Divider at top of each post
                    Rectangle()
                        .fill(AppColors.surfaceTertiary.opacity(0.5))
                        .frame(height: 0.5)

                    FeedPostRow(
                        post: post,
                        onLike: {
                            Task<Void, Never> { @MainActor in
                                await feedViewModel.toggleLike(for: post)
                            }
                        },
                        onComment: {
                            selectedPost = post
                        },
                        onEdit: post.post.authorId == feedViewModel.currentUserId ? {
                            postToEdit = post
                        } : nil,
                        onDelete: post.post.authorId == feedViewModel.currentUserId ? {
                            Task<Void, Never> { @MainActor in
                                await feedViewModel.deletePost(post)
                            }
                        } : nil,
                        onProfileTap: {
                            if post.post.authorId != feedViewModel.currentUserId {
                                profileToView = post
                            }
                        },
                        onShare: {
                            postToShare = post
                        },
                        onPostTap: {
                            selectedPost = post
                        },
                        onReact: { reaction in
                            Task<Void, Never> { @MainActor in
                                await feedViewModel.react(to: post, with: reaction)
                            }
                        },
                        onRestoreSession: post.post.authorId == feedViewModel.currentUserId && isSessionPost(post.post.content) ? {
                            if sessionViewModel.restoreSessionFromPost(post.post) {
                                showRestoreSuccess = true
                            }
                        } : nil,
                        onBlockUser: post.post.authorId != feedViewModel.currentUserId ? {
                            Task<Void, Never> { @MainActor in
                                try? await friendsViewModel.blockUser(post.post.authorId)
                            }
                        } : nil
                    )
                }
                .onAppear {
                    // Load more when reaching the end
                    if post.id == feedViewModel.posts.last?.id {
                        Task<Void, Never> { @MainActor in
                            await feedViewModel.loadMorePosts()
                        }
                    }
                }
            }

            // Final divider
            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)

            if feedViewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColors.accent2)
                    .padding(AppSpacing.lg)
            }
        }
        .tabBarBottomPadding(extra: 24) // Space for floating compose button above the tab bar
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

    private func startSocialListeners() {
        friendsViewModel.loadFriendships()
        conversationsViewModel.loadConversations()
        feedViewModel.loadFeed()
    }

    private func stopSocialListeners() {
        feedViewModel.stopListening(clearData: true)
        friendsViewModel.stopListening(clearData: true)
        conversationsViewModel.stopListening(clearData: true)
    }

    private func isSessionPost(_ content: PostContent) -> Bool {
        if case .session = content { return true }
        return false
    }
}

// MARK: - Preview

#Preview {
    SocialView(path: .constant(NavigationPath()))
}
