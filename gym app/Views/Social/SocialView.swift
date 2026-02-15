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
    @StateObject private var activityViewModel = ActivityViewModel()

    @EnvironmentObject var sessionViewModel: SessionViewModel

    @State private var showingSignIn = false
    @State private var showingComposeSheet = false
    @State private var selectedPost: PostWithAuthor?
    @State private var postToEdit: PostWithAuthor?
    @State private var postToShare: PostWithAuthor?
    @State private var postToReport: PostWithAuthor?
    @State private var profileToView: PostWithAuthor?
    @State private var showRestoreSuccess = false

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
        .sheet(item: $postToReport) { postWithAuthor in
            ReportSheet(
                reportedUserId: postWithAuthor.post.authorId,
                contentType: .post,
                contentId: postWithAuthor.post.id.uuidString
            )
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

                    // Feed / Discover segmented control
                    feedModeSelector
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.xs)

                    contentFilterSelector
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.xs)

                    if feedViewModel.hiddenAuthorCount > 0 {
                        hiddenAuthorsBanner
                            .padding(.horizontal, AppSpacing.screenPadding)
                            .padding(.bottom, AppSpacing.xs)
                    }

                    // Feed content (no wrapping LazyVStack - each branch handles its own lazy loading)
                    if feedViewModel.feedMode == .discover {
                        discoverContent
                    } else if feedViewModel.isLoading && feedViewModel.posts.isEmpty {
                        loadingView
                    } else if feedViewModel.posts.isEmpty {
                        emptyFeedState
                    } else if feedViewModel.filteredFeedPosts.isEmpty {
                        emptyFilteredFeedState
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
            HStack {
                // Profile button (left side)
                NavigationLink(destination: AccountProfileView()) {
                    profileAvatar
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: AppSpacing.md) {
                    // Search button
                    NavigationLink(destination: UserSearchView(viewModel: friendsViewModel)) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                    .buttonStyle(.plain)

                    // Friends button
                    NavigationLink(destination: FriendsListView()) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.2")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)

                            // Pending request badge
                            if friendsViewModel.pendingRequestCount > 0 {
                                Circle()
                                    .fill(AppColors.warning)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Activity/notifications button
                    NavigationLink(destination: ActivityFeedView()) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)

                            if activityViewModel.unreadCount > 0 {
                                Circle()
                                    .fill(AppColors.error)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)

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
                    .buttonStyle(.plain)

                    // Settings button
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                    }
                    .buttonStyle(.plain)
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
        Group {
            if let profile = profileRepo.currentProfile {
                ProfilePhotoView.gold(profile: profile, size: 32)
            } else {
                Circle()
                    .fill(AppColors.accent2.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("?")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.accent2)
                    }
                    .overlay {
                        Circle()
                            .stroke(AppColors.accent2.opacity(0.3), lineWidth: 1.5)
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
        .buttonStyle(.plain)
        .padding(.trailing, AppSpacing.screenPadding)
        .padding(.bottom, 80) // Clear the custom tab bar
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
                        onReport: post.post.authorId != feedViewModel.currentUserId ? {
                            postToReport = post
                        } : nil,
                        onHideAuthor: post.post.authorId != feedViewModel.currentUserId ? {
                            feedViewModel.hideAuthor(post.post.authorId)
                        } : nil,
                        onRestoreSession: post.post.authorId == feedViewModel.currentUserId && isSessionPost(post.post.content) ? {
                            if sessionViewModel.restoreSessionFromPost(post.post) {
                                showRestoreSuccess = true
                            }
                        } : nil
                    )
                }
                .onAppear {
                    // Load more when reaching the end
                    if feedViewModel.contentFilter == .all,
                       post.id == feedViewModel.posts.last?.id {
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
            } else if feedViewModel.contentFilter != .all {
                Button {
                    Task<Void, Never> { @MainActor in
                        await feedViewModel.loadMorePosts()
                    }
                } label: {
                    Text("Load more posts")
                        .subheadline(color: AppColors.accent2)
                        .padding(.vertical, AppSpacing.md)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 80) // Space for FAB
    }

    // MARK: - Content Filter Selector

    private var contentFilterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(FeedContentFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            feedViewModel.contentFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(
                                feedViewModel.contentFilter == filter
                                ? AppColors.background
                                : AppColors.textSecondary
                            )
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(
                                        feedViewModel.contentFilter == filter
                                        ? AppColors.accent2
                                        : AppColors.surfaceSecondary
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hiddenAuthorsBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "eye.slash")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            Text("\(feedViewModel.hiddenAuthorCount) hidden")
                .caption(color: AppColors.textSecondary)

            Spacer()

            Button("Show all") {
                feedViewModel.clearHiddenAuthors()
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.accent2)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(AppColors.surfaceSecondary)
        )
    }

    // MARK: - Feed Mode Selector

    private var feedModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(FeedMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        feedViewModel.feedMode = mode
                    }
                    if mode == .discover && feedViewModel.trendingPosts.isEmpty {
                        Task {
                            await feedViewModel.loadTrendingPosts()
                        }
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(feedViewModel.feedMode == mode ? .bold : .medium))
                        .foregroundColor(feedViewModel.feedMode == mode ? AppColors.textPrimary : AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .overlay(alignment: .bottom) {
                            if feedViewModel.feedMode == mode {
                                Rectangle()
                                    .fill(AppColors.accent2)
                                    .frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    // MARK: - Discover Content

    private var discoverContent: some View {
        Group {
            if feedViewModel.isLoadingTrending && feedViewModel.trendingPosts.isEmpty {
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .tint(AppColors.accent2)
                    Text("Finding trending posts...")
                        .subheadline(color: AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if feedViewModel.filteredTrendingPosts.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Spacer()
                        .frame(height: 60)

                    Image(systemName: "flame")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)

                    if feedViewModel.trendingPosts.isEmpty {
                        Text("No trending posts yet")
                            .subheadline(color: AppColors.textSecondary)

                        Text("Check back later for popular posts from the community")
                            .caption(color: AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    } else {
                        Text("No discover posts match this filter")
                            .subheadline(color: AppColors.textSecondary)

                        Button {
                            feedViewModel.contentFilter = .all
                        } label: {
                            Text("Show all posts")
                                .subheadline(color: AppColors.accent2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xl)
            } else {
                trendingFeedList
            }
        }
    }

    private var emptyFilteredFeedState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)

            Text("No posts in \(feedViewModel.contentFilter.rawValue)")
                .headline(color: AppColors.textPrimary)

            Button {
                feedViewModel.contentFilter = .all
            } label: {
                Text("Show all posts")
                    .subheadline(color: AppColors.accent2)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, 80)
    }

    // MARK: - Trending Feed List

    private var trendingFeedList: some View {
        LazyVStack(spacing: 0) {
            ForEach(feedViewModel.filteredTrendingPosts) { post in
                VStack(spacing: 0) {
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
                        onEdit: nil,
                        onDelete: nil,
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
                        onReport: post.post.authorId != feedViewModel.currentUserId ? {
                            postToReport = post
                        } : nil,
                        onHideAuthor: post.post.authorId != feedViewModel.currentUserId ? {
                            feedViewModel.hideAuthor(post.post.authorId)
                        } : nil
                    )
                }
            }

            Rectangle()
                .fill(AppColors.surfaceTertiary.opacity(0.5))
                .frame(height: 0.5)
        }
        .padding(.bottom, 80)
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
        activityViewModel.loadActivities()
    }

    private func stopSocialListeners() {
        feedViewModel.stopListening(clearData: true)
        friendsViewModel.stopListening(clearData: true)
        conversationsViewModel.stopListening(clearData: true)
        activityViewModel.stopListening(clearData: true)
    }

    private func isSessionPost(_ content: PostContent) -> Bool {
        if case .session = content { return true }
        return false
    }
}

// MARK: - Preview

#Preview {
    SocialView()
}
