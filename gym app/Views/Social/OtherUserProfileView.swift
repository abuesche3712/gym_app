//
//  OtherUserProfileView.swift
//  gym app
//
//  View for displaying another user's profile
//

import SwiftUI

struct OtherUserProfileView: View {
    @StateObject private var viewModel: OtherUserProfileViewModel
    @State private var showingBlockConfirmation = false
    @State private var showingConversation = false
    @State private var conversationData: (Conversation, UserProfile, String)?
    @State private var errorMessage = ""
    @State private var showError = false

    init(profile: UserProfile, firebaseUserId: String) {
        _viewModel = StateObject(wrappedValue: OtherUserProfileViewModel(
            profile: profile,
            firebaseUserId: firebaseUserId
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Profile header
                profileHeader

                // Action buttons
                actionButtons

                // Stats row
                statsRow

                // Bio
                if let bio = viewModel.profile.bio, !bio.isEmpty {
                    Text(bio)
                        .subheadline(color: AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.screenPadding)
                }

                // Recent posts
                recentPostsSection
            }
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("@\(viewModel.profile.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
        }
        .confirmationDialog("Block User?", isPresented: $showingBlockConfirmation, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    do {
                        try await viewModel.blockUser()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to see your posts or message you.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .navigationDestination(isPresented: $showingConversation) {
            if let (conversation, profile, firebaseId) = conversationData {
                ChatView(
                    conversation: conversation,
                    otherParticipant: profile,
                    otherParticipantFirebaseId: firebaseId
                )
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ProfilePhotoView(
                profile: viewModel.profile,
                size: 80,
                borderWidth: 2
            )

            VStack(spacing: 4) {
                Text(viewModel.profile.displayName ?? viewModel.profile.username)
                    .headline(color: AppColors.textPrimary)

                Text("@\(viewModel.profile.username)")
                    .subheadline(color: AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppSpacing.md) {
            // Friendship action
            friendshipButton

            // Message button
            Button {
                Task {
                    do {
                        let conversation = try await viewModel.startConversation()
                        conversationData = (conversation, viewModel.profile, viewModel.firebaseUserId)
                        showingConversation = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                Label("Message", systemImage: "paperplane")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(AppColors.textSecondary)

            // More menu
            Menu {
                Button(role: .destructive) {
                    showingBlockConfirmation = true
                } label: {
                    Label("Block User", systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    @ViewBuilder
    private var friendshipButton: some View {
        switch viewModel.friendshipStatus {
        case .none:
            Button {
                Task {
                    do {
                        try await viewModel.sendFriendRequest()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                Label("Add Friend", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)

        case .friends:
            Label("Friends", systemImage: "checkmark")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.success)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.success.opacity(0.15))
                .clipShape(Capsule())

        case .outgoingRequest:
            Text("Requested")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceSecondary)
                .clipShape(Capsule())

        case .incomingRequest(let friendship):
            Button {
                Task {
                    do {
                        try await viewModel.acceptFriendRequest(friendship)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                Label("Accept Request", systemImage: "checkmark")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)

        case .blockedByMe:
            Text("Blocked")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.error)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.error.opacity(0.15))
                .clipShape(Capsule())

        case .blockedByThem:
            EmptyView()
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.xl) {
            VStack(spacing: 2) {
                Text("\(viewModel.posts.count)")
                    .headline(color: AppColors.textPrimary)
                Text("Posts")
                    .caption(color: AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Recent Posts Section

    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent Posts")
                .headline(color: AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.screenPadding)

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xl)
            } else if viewModel.posts.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "rectangle.stack")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)

                    Text("No posts yet")
                        .subheadline(color: AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(AppColors.surfaceTertiary.opacity(0.5))
                                .frame(height: 0.5)

                            FeedPostRow(
                                post: post,
                                onLike: {},
                                onComment: {},
                                onEdit: nil,
                                onDelete: nil,
                                onProfileTap: {}
                            )
                        }
                    }

                    Rectangle()
                        .fill(AppColors.surfaceTertiary.opacity(0.5))
                        .frame(height: 0.5)
                }
            }
        }
    }
}
