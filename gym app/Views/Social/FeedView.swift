//
//  FeedView.swift
//  gym app
//
//  Main social feed view showing posts from friends
//  Design: Strava meets Twitter meets Apple Fitness
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedPost: PostWithAuthor?
    @State private var showingComposeSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    loadingView
                } else if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body.weight(.medium))
                            .foregroundColor(AppColors.dominant)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
            .onAppear {
                viewModel.loadFeed()
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post)
            }
            .sheet(isPresented: $showingComposeSheet) {
                ComposePostSheet()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading feed...")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.dominant.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppColors.dominant)
            }

            // Title
            Text("No Posts Yet")
                .font(.title2.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            // Subtitle
            Text("When you or your friends share workouts,\nthey'll show up here.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // CTA Button
            NavigationLink {
                FriendsListView()
            } label: {
                Text("Find Friends")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppGradients.dominantGradient)
                    )
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.screenPadding)
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xl) {
                ForEach(viewModel.posts) { post in
                    PostCard(
                        post: post,
                        onLike: {
                            Task {
                                await viewModel.toggleLike(for: post)
                            }
                        },
                        onComment: {
                            selectedPost = post
                        },
                        onDelete: post.post.authorId == viewModel.currentUserId ? {
                            Task {
                                await viewModel.deletePost(post)
                            }
                        } : nil,
                        onProfileTap: {
                            // Profile viewing can be added later
                        }
                    )
                    .onAppear {
                        // Load more when reaching near the end
                        if post.id == viewModel.posts.last?.id {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    }
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
    }
}

// MARK: - Preview

#Preview {
    FeedView()
}
