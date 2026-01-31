//
//  ChatView.swift
//  gym app
//
//  Individual chat conversation view with messages
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    init(conversation: Conversation, otherParticipant: UserProfile, otherParticipantFirebaseId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversation: conversation,
            otherParticipant: otherParticipant,
            otherParticipantFirebaseId: otherParticipantFirebaseId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            messagesScrollView

            // Input bar
            if viewModel.isBlocked {
                blockedBanner
            } else {
                chatInputBar
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(viewModel.otherParticipant.displayName ?? viewModel.otherParticipant.username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMessages()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == viewModel.currentUserId,
                            otherUserProfile: viewModel.otherParticipant
                        )
                        .id(message.id)
                    }
                }
                .padding(AppSpacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Scroll to bottom when new messages arrive
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom on appear
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Blocked Banner

    private var blockedBanner: some View {
        HStack {
            Image(systemName: "hand.raised.slash")
                .foregroundColor(AppColors.error)

            Text("You cannot message this user")
                .subheadline(color: AppColors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surfaceSecondary)
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            // Text input
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(20)
                .focused($isInputFocused)

            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(canSend ? AppColors.dominant : AppColors.textTertiary)
            }
            .disabled(!canSend || viewModel.isSending)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.background)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        let text = messageText
        messageText = ""

        Task {
            do {
                try await viewModel.sendMessage(text: text)
            } catch {
                messageText = text // Restore on failure
                Logger.error(error, context: "ChatView.sendMessage")
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let otherUserProfile: UserProfile

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.xs) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar for other user
                avatarView
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message content
                contentView
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(bubbleBackground)
                    .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)

                // Timestamp
                Text(message.createdAt.messageTimeString)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var avatarView: some View {
        Circle()
            .fill(AppColors.dominant.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay {
                Text(avatarInitials)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.dominant)
            }
    }

    private var avatarInitials: String {
        if let displayName = otherUserProfile.displayName, !displayName.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return String(otherUserProfile.username.prefix(1)).uppercased()
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .subheadline(color: isFromCurrentUser ? .white : AppColors.textPrimary)

        case .sharedProgram(_, let name, _):
            sharedContentView(icon: "doc.text.fill", label: "Program", name: name)

        case .sharedWorkout(_, let name, _):
            sharedContentView(icon: "figure.run", label: "Workout", name: name)

        case .sharedModule(_, let name, _):
            sharedContentView(icon: "square.stack.3d.up.fill", label: "Module", name: name)

        case .sharedSession(_, let workoutName, let date, _):
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completed Workout")
                        .fontWeight(.medium)
                }
                Text("\(workoutName) • \(date.formatted(date: .abbreviated, time: .omitted))")
            }
            .subheadline(color: isFromCurrentUser ? .white : AppColors.textPrimary)

        case .sharedExercise:
            sharedContentView(icon: "dumbbell.fill", label: "Exercise", name: "Shared exercise")

        case .sharedSet:
            sharedContentView(icon: "flame.fill", label: "Personal Best", name: "Shared set")
        }
    }

    private func sharedContentView(icon: String, label: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.medium)
            }
            Text(name)
        }
        .subheadline(color: isFromCurrentUser ? .white : AppColors.textPrimary)
    }

    private var bubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.dominant)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.surfaceSecondary)
            }
        }
    }
}

// MARK: - Message Time Extension

private extension Date {
    var messageTimeString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: self))"
        } else if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, h:mm a"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: self)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversation: Conversation(participantIds: ["user1", "user2"], createdAt: Date()),
            otherParticipant: UserProfile(username: "johndoe"),
            otherParticipantFirebaseId: "user2"
        )
    }
}
