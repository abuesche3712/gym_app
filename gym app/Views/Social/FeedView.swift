//
//  FeedView.swift
//  gym app
//
//  Main social feed view showing posts from friends
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
            Text("Loading feed...")
                .subheadline(color: AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No Posts Yet")
                .headline(color: AppColors.textPrimary)

            Text("Add friends to see their workouts in your feed")
                .subheadline(color: AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            NavigationLink {
                FriendsListView()
            } label: {
                Text("Find Friends")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.dominant)
                    .cornerRadius(AppCorners.medium)
            }
        }
        .padding()
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
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
                        // Load more when reaching the end
                        if post.id == viewModel.posts.last?.id {
                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, AppSpacing.md)
        }
    }
}

// MARK: - Preview

#Preview {
    FeedView()
}
