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
    @State private var conversationToDelete: ConversationWithProfile?

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
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No messages yet",
            subtitle: "Start a conversation with a friend",
            buttonTitle: "New Message",
            buttonIcon: "plus",
            onButtonTap: { showingNewConversation = true }
        )
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        conversationToDelete = convoWithProfile
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if convoWithProfile.id != viewModel.conversations.last?.id {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(AppColors.surfaceSecondary)
        .cornerRadius(AppCorners.large)
        .confirmationDialog(
            "Delete Conversation?",
            isPresented: Binding(
                get: { conversationToDelete != nil },
                set: { if !$0 { conversationToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let convo = conversationToDelete {
                    Task {
                        await viewModel.deleteConversation(convo.conversation)
                    }
                    conversationToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
        } message: {
            Text("This will permanently delete this conversation and all messages.")
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversationWithProfile: ConversationWithProfile
    let onTap: () -> Void

    @State private var isOnline = false
    @State private var lastSeen: Date?

    private var conversation: Conversation { conversationWithProfile.conversation }
    private var profile: UserProfile { conversationWithProfile.otherParticipant }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Avatar with unread indicator and online dot
                ZStack(alignment: .topTrailing) {
                    ProfilePhotoView(profile: profile, size: 52)

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

                    // Online indicator
                    if isOnline {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(AppColors.surfaceSecondary, lineWidth: 2)
                            )
                            .offset(x: 2, y: 38)
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
                    } else if !isOnline, let lastSeen = lastSeen {
                        Text(PresenceService.formatLastSeen(lastSeen))
                            .caption(color: AppColors.textTertiary)
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
        .task {
            let presence = await PresenceService.shared.fetchPresence(userId: conversationWithProfile.otherParticipantFirebaseId)
            isOnline = presence.isOnline
            lastSeen = presence.lastSeen
        }
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
