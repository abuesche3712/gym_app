//
//  ChatViewModel.swift
//  gym app
//
//  ViewModel for managing an individual chat conversation
//

import Foundation
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: Error?
    @Published var otherUserIsTyping = false
    @Published var otherUserIsOnline = false
    @Published var otherUserLastSeen: Date?

    let conversation: Conversation
    let otherParticipant: UserProfile
    let otherParticipantFirebaseId: String

    private let messageRepo: MessageRepository
    private let conversationRepo: ConversationRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var messageListener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    private let presenceService = PresenceService.shared
    private var typingDebounceTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard
    private let maxHiddenMessageIds = 500

    var currentUserId: String? {
        authService.currentUser?.uid
    }

    var isBlocked: Bool {
        guard let userId = currentUserId else {
            Logger.debug("ChatViewModel.isBlocked: No current user ID, returning false")
            return false
        }
        let blocked = friendshipRepo.isBlockedByOrBlocking(userId, otherParticipantFirebaseId)
        Logger.debug("ChatViewModel.isBlocked: userId=\(Logger.redactUserID(userId)), otherId=\(Logger.redactUserID(otherParticipantFirebaseId)), blocked=\(blocked)")
        return blocked
    }

    init(conversation: Conversation,
         otherParticipant: UserProfile,
         otherParticipantFirebaseId: String,
         messageRepo: MessageRepository? = nil,
         conversationRepo: ConversationRepository? = nil,
         friendshipRepo: FriendshipRepository? = nil) {
        self.conversation = conversation
        self.otherParticipant = otherParticipant
        self.otherParticipantFirebaseId = otherParticipantFirebaseId
        self.messageRepo = messageRepo ?? DataRepository.shared.messageRepo
        self.conversationRepo = conversationRepo ?? DataRepository.shared.conversationRepo
        self.friendshipRepo = friendshipRepo ?? DataRepository.shared.friendshipRepo
    }

    deinit {
        messageListener?.remove()
        typingListener?.remove()
        presenceListener?.remove()
        typingDebounceTask?.cancel()
    }

    // MARK: - Data Loading

    func loadMessages() {
        isLoading = true

        // Start real-time listener
        messageListener?.remove()
        messageListener = firestoreService.listenToMessages(
            conversationId: conversation.id,
            onChange: { [weak self] cloudMessages in
                Task { @MainActor in
                    self?.handleMessagesUpdate(cloudMessages)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    Logger.error(error, context: "ChatViewModel.loadMessages")
                    self?.error = error
                    self?.isLoading = false
                }
            }
        )

        // Load from local cache immediately
        loadFromLocalCache()
        isLoading = false

        // Start typing indicator listener
        typingListener?.remove()
        typingListener = presenceService.listenToTypingStatus(
            conversationId: conversation.id,
            otherUserId: otherParticipantFirebaseId
        ) { [weak self] isTyping in
            Task { @MainActor in
                self?.otherUserIsTyping = isTyping
            }
        }

        // Start presence listener
        presenceListener?.remove()
        presenceListener = presenceService.listenToPresence(
            userId: otherParticipantFirebaseId
        ) { [weak self] isOnline, lastSeen in
            Task { @MainActor in
                self?.otherUserIsOnline = isOnline
                self?.otherUserLastSeen = lastSeen
            }
        }
    }

    private func loadFromLocalCache() {
        let hidden = hiddenMessageIds()
        messages = messageRepo.getAllMessages(for: conversation.id)
            .filter { !hidden.contains($0.id) }
        markMessagesAsRead()
    }

    private func handleMessagesUpdate(_ cloudMessages: [Message]) {
        // Update local cache with cloud data
        for message in cloudMessages {
            messageRepo.updateFromCloud(message)
        }

        // Reload from cache to get properly ordered messages
        loadFromLocalCache()
    }

    private func markMessagesAsRead() {
        guard let userId = currentUserId else { return }
        let localUnreadCount = conversationRepo.getConversation(id: conversation.id)?.unreadCount ?? 0

        // Capture unread remote message IDs before local read-state mutation.
        let unreadFromOther = messageRepo
            .getAllMessages(for: conversation.id)
            .filter { $0.senderId != userId && !$0.isRead }

        // Avoid repeated network writes when nothing is unread locally or remotely.
        if unreadFromOther.isEmpty && localUnreadCount == 0 {
            return
        }

        // Mark messages from the other person as read
        messageRepo.markAllAsRead(in: conversation.id, for: userId)

        // Update conversation unread count locally
        conversationRepo.markConversationRead(conversation.id, for: userId)

        // Mark unread messages from the other user as read in Firestore
        // so the sender's listener picks up the readAt update
        Task {
            do {
                try await firestoreService.resetUnreadCount(conversationId: conversation.id, userId: userId)

                // Mark individual messages as read in Firestore
                for message in unreadFromOther {
                    try await firestoreService.markMessageRead(
                        conversationId: conversation.id,
                        messageId: message.id
                    )
                }
            } catch {
                Logger.error(error, context: "ChatViewModel.markMessagesAsRead.resetUnreadCount")
            }
        }
    }

    // MARK: - Sending Messages

    func sendMessage(text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let senderId = currentUserId else {
            throw MessageError.notAuthenticated
        }

        if isBlocked {
            throw MessageError.userBlocked
        }

        isSending = true
        defer { isSending = false }

        // Create and save locally
        let message = messageRepo.sendMessage(
            conversationId: conversation.id,
            senderId: senderId,
            content: .text(text.trimmingCharacters(in: .whitespacesAndNewlines))
        )

        // Update conversation preview
        conversationRepo.updateLastMessage(
            conversation.id,
            preview: text.trimmingCharacters(in: .whitespacesAndNewlines),
            at: message.createdAt
        )

        // Reload to show new message
        loadFromLocalCache()

        // Sync to cloud
        do {
            // First ensure conversation exists in Firestore (critical for first message)
            try await firestoreService.saveConversation(conversation)

            // Then save message
            try await firestoreService.saveMessage(message)

            // Update conversation with last message preview and increment recipient's unread count
            try await firestoreService.updateConversationOnNewMessage(
                conversationId: conversation.id,
                recipientId: otherParticipantFirebaseId,
                preview: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            Logger.error(error, context: "ChatViewModel.sendMessage")
            // Message is saved locally, will sync when online
        }
    }

    func sendSharedContent(_ content: MessageContent) async throws {
        guard let senderId = currentUserId else {
            throw MessageError.notAuthenticated
        }

        if isBlocked {
            throw MessageError.userBlocked
        }

        isSending = true
        defer { isSending = false }

        // Create and save locally
        let message = messageRepo.sendMessage(
            conversationId: conversation.id,
            senderId: senderId,
            content: content
        )

        // Update conversation preview using the content's built-in preview
        let preview = content.previewText

        conversationRepo.updateLastMessage(
            conversation.id,
            preview: preview,
            at: message.createdAt
        )

        // Reload to show new message
        loadFromLocalCache()

        // Sync to cloud
        do {
            // First ensure conversation exists in Firestore
            try await firestoreService.saveConversation(conversation)

            // Then save message
            try await firestoreService.saveMessage(message)

            // Update conversation with last message preview and increment recipient's unread count
            try await firestoreService.updateConversationOnNewMessage(
                conversationId: conversation.id,
                recipientId: otherParticipantFirebaseId,
                preview: preview
            )
        } catch {
            Logger.error(error, context: "ChatViewModel.sendSharedContent")
        }
    }

    // MARK: - Message Deletion

    /// Delete a message for the current user only (hides locally)
    func deleteMessage(_ message: Message) {
        addHiddenMessageId(message.id)
        messages.removeAll { $0.id == message.id }
    }

    /// Unsend a message (own messages only, soft-deletes in Firestore)
    func unsendMessage(_ message: Message) async {
        guard message.senderId == currentUserId else { return }

        // Optimistic local update
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updated = messages[index]
            updated.isDeleted = true
            updated.content = .text("This message was deleted")
            messages[index] = updated
        }

        do {
            try await firestoreService.deleteMessage(
                conversationId: conversation.id,
                messageId: message.id
            )
        } catch {
            Logger.error(error, context: "ChatViewModel.unsendMessage")
            // Reload on failure
            loadFromLocalCache()
        }
    }

    // MARK: - Pagination

    func loadMoreMessages() async {
        guard let oldestMessage = messages.first else { return }

        let olderMessages = messageRepo.getMessages(
            for: conversation.id,
            limit: 50,
            before: oldestMessage.createdAt
        )

        if !olderMessages.isEmpty {
            // Prepend older messages (they come in reverse order so need to reverse again)
            messages = olderMessages.reversed() + messages
        }
    }

    func updateTypingStatus(_ text: String) {
        guard let userId = currentUserId else { return }

        let isTyping = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        presenceService.setTypingStatus(conversationId: conversation.id, userId: userId, isTyping: isTyping)

        // Auto-clear after 2 seconds of no changes
        typingDebounceTask?.cancel()
        if isTyping {
            typingDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.presenceService.setTypingStatus(conversationId: self.conversation.id, userId: userId, isTyping: false)
                }
            }
        }
    }

    func stopListening() {
        messageListener?.remove()
        messageListener = nil
        typingListener?.remove()
        typingListener = nil
        presenceListener?.remove()
        presenceListener = nil
        typingDebounceTask?.cancel()

        // Clear typing status when leaving
        if let userId = currentUserId {
            presenceService.setTypingStatus(conversationId: conversation.id, userId: userId, isTyping: false)
        }
    }

    private var hiddenMessagesKey: String {
        "chat.hiddenMessages.\(conversation.id.uuidString)"
    }

    private func hiddenMessageIds() -> Set<UUID> {
        Set(hiddenMessageIdsOrdered())
    }

    private func hiddenMessageIdsOrdered() -> [UUID] {
        let stored = userDefaults.stringArray(forKey: hiddenMessagesKey) ?? []
        var seen: Set<UUID> = []
        return stored
            .compactMap(UUID.init)
            .filter { seen.insert($0).inserted }
    }

    private func addHiddenMessageId(_ id: UUID) {
        var ids = hiddenMessageIdsOrdered().filter { $0 != id }
        ids.append(id)
        if ids.count > maxHiddenMessageIds {
            ids.removeFirst(ids.count - maxHiddenMessageIds)
        }
        userDefaults.set(ids.map(\.uuidString), forKey: hiddenMessagesKey)
    }

    // MARK: - Import Shared Content

    /// Imports a program from a shared message
    func importProgram(from message: Message) -> ImportResult {
        guard case .sharedProgram(_, _, let snapshot) = message.content else {
            return .failure("Not a shared program")
        }

        do {
            let bundle = try ProgramShareBundle.decode(from: snapshot)
            let sharingService = SharingService.shared
            return sharingService.importProgram(from: bundle)
        } catch {
            Logger.error(error, context: "ChatViewModel.importProgram")
            return .failure("Failed to import program: \(error.localizedDescription)")
        }
    }

    /// Imports a workout from a shared message
    func importWorkout(from message: Message) -> ImportResult {
        guard case .sharedWorkout(_, _, let snapshot) = message.content else {
            return .failure("Not a shared workout")
        }

        do {
            let bundle = try WorkoutShareBundle.decode(from: snapshot)
            let sharingService = SharingService.shared
            return sharingService.importWorkout(from: bundle)
        } catch {
            Logger.error(error, context: "ChatViewModel.importWorkout")
            return .failure("Failed to import workout: \(error.localizedDescription)")
        }
    }

    /// Imports a module from a shared message
    func importModule(from message: Message) -> ImportResult {
        guard case .sharedModule(_, _, let snapshot) = message.content else {
            return .failure("Not a shared module")
        }

        do {
            let bundle = try ModuleShareBundle.decode(from: snapshot)
            let sharingService = SharingService.shared
            return sharingService.importModule(from: bundle)
        } catch {
            Logger.error(error, context: "ChatViewModel.importModule")
            return .failure("Failed to import module: \(error.localizedDescription)")
        }
    }

    /// Detects conflicts before importing
    func detectConflicts(for message: Message) -> [ImportConflict] {
        let sharingService = SharingService.shared

        switch message.content {
        case .sharedProgram(_, _, let snapshot):
            guard let bundle = try? ProgramShareBundle.decode(from: snapshot) else { return [] }
            return sharingService.detectConflicts(from: bundle)

        case .sharedWorkout(_, _, let snapshot):
            guard let bundle = try? WorkoutShareBundle.decode(from: snapshot) else { return [] }
            return sharingService.detectConflicts(from: bundle)

        case .sharedModule(_, _, let snapshot):
            guard let bundle = try? ModuleShareBundle.decode(from: snapshot) else { return [] }
            return sharingService.detectConflicts(from: bundle)

        case .sharedExerciseInstance(let snapshot):
            guard let bundle = try? ExerciseInstanceShareBundle.decode(from: snapshot) else { return [] }
            return sharingService.detectConflicts(from: bundle)

        default:
            return []
        }
    }

    /// Imports content from a message with options for conflict resolution
    func importContent(from message: Message, options: ImportOptions = ImportOptions()) -> ImportResult {
        let sharingService = SharingService.shared

        switch message.content {
        case .sharedProgram(_, _, let snapshot):
            guard let bundle = try? ProgramShareBundle.decode(from: snapshot) else {
                return .failure("Invalid program data")
            }
            return sharingService.importProgram(from: bundle, options: options)

        case .sharedWorkout(_, _, let snapshot):
            guard let bundle = try? WorkoutShareBundle.decode(from: snapshot) else {
                return .failure("Invalid workout data")
            }
            return sharingService.importWorkout(from: bundle, options: options)

        case .sharedModule(_, _, let snapshot):
            guard let bundle = try? ModuleShareBundle.decode(from: snapshot) else {
                return .failure("Invalid module data")
            }
            return sharingService.importModule(from: bundle, options: options)

        case .sharedExerciseInstance(let snapshot):
            guard let bundle = try? ExerciseInstanceShareBundle.decode(from: snapshot) else {
                return .failure("Invalid exercise data")
            }
            return sharingService.importExerciseInstance(from: bundle, options: options)

        default:
            return .failure("Content cannot be imported")
        }
    }
}

// MARK: - Errors

enum MessageError: LocalizedError {
    case notAuthenticated
    case userBlocked
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to send messages"
        case .userBlocked:
            return "Cannot message this user"
        case .sendFailed:
            return "Failed to send message"
        }
    }
}
