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
    @Environment(\.hideTabBar) private var hideTabBar

    // Import state
    @State private var selectedMessageForImport: Message?
    @State private var showingImportConfirmation = false
    @State private var showingImportConflicts = false
    @State private var importConflicts: [ImportConflict] = []
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false

    // Preview state
    @State private var previewingMessage: Message?

    init(conversation: Conversation, otherParticipant: UserProfile, otherParticipantFirebaseId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversation: conversation,
            otherParticipant: otherParticipant,
            otherParticipantFirebaseId: otherParticipantFirebaseId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages scroll view takes remaining space
            messagesScrollView

            // Typing indicator
            if viewModel.otherUserIsTyping {
                typingIndicator
            }

            // Input bar at bottom
            Group {
                if viewModel.isBlocked {
                    blockedBanner
                } else {
                    chatInputBar
                }
            }
            .frame(minHeight: 50)  // Ensure minimum height for input area
        }
        .background(AppColors.background)
        .navigationTitle(viewModel.otherParticipant.displayName ?? viewModel.otherParticipant.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(viewModel.otherParticipant.displayName ?? viewModel.otherParticipant.username)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if viewModel.otherUserIsOnline {
                        Text("Online")
                            .font(.caption2)
                            .foregroundColor(AppColors.success)
                    } else if let lastSeen = viewModel.otherUserLastSeen {
                        Text(PresenceService.formatLastSeen(lastSeen))
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .onChange(of: messageText) { _, newValue in
            viewModel.updateTypingStatus(newValue)
        }
        .onAppear {
            Logger.debug("ChatView.onAppear: isBlocked=\(viewModel.isBlocked), messagesCount=\(viewModel.messages.count), currentUserId=\(viewModel.currentUserId ?? "nil")")
            hideTabBar.wrappedValue = true  // Hide custom tab bar
            viewModel.loadMessages()
        }
        .onDisappear {
            hideTabBar.wrappedValue = false  // Show custom tab bar again
            viewModel.stopListening()
        }
        .sheet(isPresented: $showingImportConflicts) {
            if let message = selectedMessageForImport {
                ImportConflictSheet(
                    conflicts: importConflicts,
                    contentName: message.content.previewText,
                    onConfirm: { options in
                        let result = viewModel.importContent(from: message, options: options)
                        importResult = result
                        showingImportConflicts = false
                        showingImportResult = true
                    },
                    onCancel: {
                        showingImportConflicts = false
                        selectedMessageForImport = nil
                    }
                )
            }
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK") {
                selectedMessageForImport = nil
            }
        } message: {
            if let result = importResult {
                Text(result.message)
            }
        }
        .sheet(item: $previewingMessage) { previewMessage in
            SharedContentPreviewSheet(
                content: previewMessage.content,
                onImport: { success in
                    if success {
                        // Optionally show success feedback
                    }
                }
            )
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
                            otherUserProfile: viewModel.otherParticipant,
                            onImport: message.content.isImportable && message.senderId != viewModel.currentUserId ? {
                                handleImport(message: message)
                            } : nil,
                            onView: message.content.isViewable && message.senderId != viewModel.currentUserId ? {
                                previewingMessage = message
                            } : nil,
                            onUnsend: message.senderId == viewModel.currentUserId && !message.isDeleted ? {
                                Task<Void, Never> { @MainActor in
                                    await viewModel.unsendMessage(message)
                                }
                            } : nil,
                            onDeleteForMe: !message.isDeleted ? {
                                viewModel.deleteMessage(message)
                            } : nil
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
        .onAppear {
            Logger.debug("blockedBanner appeared - isBlocked=true")
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            ProfilePhotoView(profile: viewModel.otherParticipant, size: 20, characterCount: 1)

            Text("\(viewModel.otherParticipant.displayName ?? viewModel.otherParticipant.username) is typing")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            TypingDotsView()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.otherUserIsTyping)
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.dominant)

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
        }
        .background(AppColors.surfacePrimary)
        .onAppear {
            Logger.debug("chatInputBar appeared")
        }
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

    private func handleImport(message: Message) {
        selectedMessageForImport = message

        // Check for conflicts
        let conflicts = viewModel.detectConflicts(for: message)

        if conflicts.isEmpty {
            // No conflicts, import directly
            let result = viewModel.importContent(from: message)
            importResult = result
            showingImportResult = true
        } else {
            // Show conflict resolution sheet
            importConflicts = conflicts
            showingImportConflicts = true
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let otherUserProfile: UserProfile
    var onImport: (() -> Void)?
    var onView: (() -> Void)?
    var onUnsend: (() -> Void)?
    var onDeleteForMe: (() -> Void)?

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
                if message.isDeleted {
                    Text("This message was deleted")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppColors.surfaceSecondary)
                        )
                } else if message.content.isSharedContent {
                    SharedContentCard(
                        content: message.content,
                        isFromCurrentUser: isFromCurrentUser,
                        onImport: onImport,
                        onView: onView
                    )
                    .contextMenu {
                        messageContextMenu
                    }
                } else {
                    contentView
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(bubbleBackground)
                        .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                        .contextMenu {
                            messageContextMenu
                        }
                }

                // Timestamp + read receipt
                HStack(spacing: 4) {
                    Text(message.createdAt.messageTimeString)
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)

                    if isFromCurrentUser && !message.isDeleted {
                        if message.isRead {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.dominant)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var messageContextMenu: some View {
        if isFromCurrentUser {
            Button(role: .destructive) {
                onUnsend?()
            } label: {
                Label("Unsend", systemImage: "arrow.uturn.backward")
            }
        }

        Button(role: .destructive) {
            onDeleteForMe?()
        } label: {
            Label("Delete for Me", systemImage: "trash")
        }
    }

    private var avatarView: some View {
        ProfilePhotoView(profile: otherUserProfile, size: 28, characterCount: 1)
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

        case .sharedCompletedModule:
            sharedContentView(icon: "square.stack.3d.up.fill", label: "Module Results", name: "Completed module")

        case .sharedHighlights(let snapshot):
            if let bundle = try? HighlightsShareBundle.decode(from: snapshot) {
                let count = bundle.exercises.count + bundle.sets.count
                sharedContentView(icon: "star.fill", label: "\(count) Highlight\(count == 1 ? "" : "s")", name: bundle.workoutName)
            } else {
                sharedContentView(icon: "star.fill", label: "Highlights", name: "Workout highlights")
            }

        case .sharedExerciseInstance(let snapshot):
            if let bundle = try? ExerciseInstanceShareBundle.decode(from: snapshot) {
                sharedContentView(icon: "dumbbell.fill", label: "Exercise Config", name: bundle.exerciseInstance.name)
            } else {
                sharedContentView(icon: "dumbbell.fill", label: "Exercise Config", name: "Shared exercise")
            }

        case .sharedSetGroup(let snapshot):
            if let bundle = try? SetGroupShareBundle.decode(from: snapshot) {
                sharedContentView(icon: "list.bullet.rectangle", label: "Set Prescription", name: "\(bundle.setGroup.sets) sets of \(bundle.exerciseName)")
            } else {
                sharedContentView(icon: "list.bullet.rectangle", label: "Set Prescription", name: "Shared prescription")
            }

        case .sharedCompletedSetGroup(let snapshot):
            if let bundle = try? CompletedSetGroupShareBundle.decode(from: snapshot) {
                let completedCount = bundle.completedSetGroup.sets.filter(\.completed).count
                sharedContentView(icon: "checkmark.rectangle.stack.fill", label: "Completed Sets", name: "\(completedCount) sets of \(bundle.exerciseName)")
            } else {
                sharedContentView(icon: "checkmark.rectangle.stack.fill", label: "Completed Sets", name: "Shared sets")
            }

        case .decodeFailed(let originalType):
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text("Failed to load")
                        .fontWeight(.medium)
                }
                if let type = originalType {
                    Text("Content type: \(type)")
                } else {
                    Text("Unknown content type")
                }
            }
            .subheadline(color: isFromCurrentUser ? .white : AppColors.textPrimary)
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

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.textTertiary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
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
