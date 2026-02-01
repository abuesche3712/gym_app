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

    let conversation: Conversation
    let otherParticipant: UserProfile
    let otherParticipantFirebaseId: String

    private let messageRepo: MessageRepository
    private let conversationRepo: ConversationRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var messageListener: ListenerRegistration?

    var currentUserId: String? {
        authService.currentUser?.uid
    }

    var isBlocked: Bool {
        guard let userId = currentUserId else { return false }
        return friendshipRepo.isBlockedByOrBlocking(userId, otherParticipantFirebaseId)
    }

    init(conversation: Conversation,
         otherParticipant: UserProfile,
         otherParticipantFirebaseId: String,
         messageRepo: MessageRepository = DataRepository.shared.messageRepo,
         conversationRepo: ConversationRepository = DataRepository.shared.conversationRepo,
         friendshipRepo: FriendshipRepository = DataRepository.shared.friendshipRepo) {
        self.conversation = conversation
        self.otherParticipant = otherParticipant
        self.otherParticipantFirebaseId = otherParticipantFirebaseId
        self.messageRepo = messageRepo
        self.conversationRepo = conversationRepo
        self.friendshipRepo = friendshipRepo
    }

    deinit {
        messageListener?.remove()
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
    }

    private func loadFromLocalCache() {
        messages = messageRepo.getAllMessages(for: conversation.id)
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

        // Mark messages from the other person as read
        messageRepo.markAllAsRead(in: conversation.id, for: userId)

        // Update conversation unread count
        conversationRepo.markConversationRead(conversation.id, for: userId)
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
            try await firestoreService.saveMessage(message)

            // Also update conversation in cloud
            if let updatedConversation = conversationRepo.getConversation(id: conversation.id) {
                try await firestoreService.saveConversation(updatedConversation)
            }
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
            try await firestoreService.saveMessage(message)
        } catch {
            Logger.error(error, context: "ChatViewModel.sendSharedContent")
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

    func stopListening() {
        messageListener?.remove()
        messageListener = nil
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
