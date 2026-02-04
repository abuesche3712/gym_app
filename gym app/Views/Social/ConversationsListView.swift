//
//  ConversationsListView.swift
//  gym app
//
//  List of all conversations for messaging
//

import SwiftUI

struct ConversationsListView: View {
    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showingNewConversation = false
    @State private var selectedConversation: ConversationWithProfile?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    loadingView
                } else if viewModel.conversations.isEmpty {
                    emptyView
                } else {
                    conversationsList
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewConversation) {
            NewConversationSheet(viewModel: viewModel) { conversation in
                selectedConversation = conversation
            }
        }
        .navigationDestination(item: $selectedConversation) { convoWithProfile in
            ChatView(
                conversation: convoWithProfile.conversation,
                otherParticipant: convoWithProfile.otherParticipant,
                otherParticipantFirebaseId: convoWithProfile.otherParticipantFirebaseId
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .refreshable {
            viewModel.loadConversations()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No messages yet")
                .headline(color: AppColors.textSecondary)

            Text("Start a conversation with a friend")
                .caption(color: AppColors.textTertiary)

            Button {
                showingNewConversation = true
            } label: {
                Label("New Message", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.dominant)
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Conversations List

    private var conversationsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.conversations) { convoWithProfile in
                ConversationRow(
                    conversationWithProfile: convoWithProfile,
                    onTap: {
                        viewModel.markAsRead(convoWithProfile.conversation.id)
                        selectedConversation = convoWithProfile
                    }
                )

                if convoWithProfile.id != viewModel.conversations.last?.id {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversationWithProfile: ConversationWithProfile
    let onTap: () -> Void

    private var conversation: Conversation { conversationWithProfile.conversation }
    private var profile: UserProfile { conversationWithProfile.otherParticipant }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Avatar with unread indicator
                ZStack(alignment: .topTrailing) {
                    AvatarView(profile: profile, size: 52)

                    if conversation.unreadCount > 0 {
                        Circle()
                            .fill(AppColors.dominant)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text(unreadBadgeText)
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 2, y: -2)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile.displayName ?? profile.username)
                            .headline(color: AppColors.textPrimary)
                            .fontWeight(conversation.unreadCount > 0 ? .bold : .regular)

                        Spacer()

                        if let lastMessageAt = conversation.lastMessageAt {
                            Text(lastMessageAt.relativeTimeString)
                                .caption(color: AppColors.textTertiary)
                        }
                    }

                    if let preview = conversation.lastMessagePreview {
                        Text(preview)
                            .subheadline(color: conversation.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary)
                            .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .caption(color: AppColors.textTertiary)
                            .italic()
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var unreadBadgeText: String {
        conversation.unreadCount > 9 ? "9+" : "\(conversation.unreadCount)"
    }
}

// MARK: - Relative Time Extension

private extension Date {
    var relativeTimeString: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let days = components.day, days >= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        } else if let days = components.day, days >= 1 {
            return "\(days)d"
        } else if let hours = components.hour, hours >= 1 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes >= 1 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}

#Preview {
    NavigationStack {
        ConversationsListView()
    }
}
