//
//  ConversationsViewModel.swift
//  gym app
//
//  ViewModel for managing the conversations list
//

import Foundation
import FirebaseFirestore
import Combine

/// Pairs a conversation with the other participant's profile
struct ConversationWithProfile: Identifiable, Hashable {
    let conversation: Conversation
    let otherParticipant: UserProfile
    let otherParticipantFirebaseId: String

    var id: UUID { conversation.id }

    static func == (lhs: ConversationWithProfile, rhs: ConversationWithProfile) -> Bool {
        lhs.conversation.id == rhs.conversation.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(conversation.id)
    }
}

@MainActor
class ConversationsViewModel: ObservableObject {
    @Published var conversations: [ConversationWithProfile] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let conversationRepo: ConversationRepository
    private let messageRepo: MessageRepository
    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var conversationListener: ListenerRegistration?
    private var conversationCancellable: AnyCancellable?
    private var signOutCancellable: AnyCancellable?

    var currentUserId: String? {
        authService.currentUser?.uid
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.conversation.unreadCount }
    }

    init(conversationRepo: ConversationRepository? = nil,
         messageRepo: MessageRepository? = nil,
         friendshipRepo: FriendshipRepository? = nil) {
        self.conversationRepo = conversationRepo ?? DataRepository.shared.conversationRepo
        self.messageRepo = messageRepo ?? DataRepository.shared.messageRepo
        self.friendshipRepo = friendshipRepo ?? DataRepository.shared.friendshipRepo
        setupConversationObserver()
        setupSignOutObserver()
    }

    deinit {
        conversationListener?.remove()
        conversationCancellable?.cancel()
        signOutCancellable?.cancel()
    }

    /// Stops the Firestore listener and clears all published state when the user signs
    /// out (or deletes their account), so a still-mounted conversations list doesn't
    /// keep streaming a previous account's conversations into shared CoreData after a
    /// different account signs in.
    private func setupSignOutObserver() {
        signOutCancellable = NotificationCenter.default.publisher(for: .userDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.debug("ConversationsViewModel: received userDidSignOut, tearing down listener")
                self?.stopListening(clearData: true)
            }
    }

    /// Mirrors the shared `ConversationRepository`'s published state into this
    /// instance's `conversations` list. Every screen constructs its own
    /// `ConversationsViewModel` (`SocialView`, `ConversationsListView`,
    /// `ShareWithFriendSheet`), so without this a mutation performed by one instance
    /// (e.g. `markAsRead` from `ConversationsListView`) leaves sibling instances (e.g.
    /// `SocialView`'s unread badge) stale until a cloud round-trip echoes back — which
    /// never happens while offline. `conversationRepo` is the single shared
    /// `DataRepository.shared.conversationRepo` instance, so any local mutation from any
    /// instance updates `conversations` synchronously, and every subscribed instance
    /// re-derives its state here. Mirrors `FeedViewModel.setupFriendshipObserver()`.
    private func setupConversationObserver() {
        conversationCancellable = conversationRepo.$conversations
            .dropFirst() // Skip the initial buffered value; loadConversations() handles first load
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let userId = self.currentUserId else { return }
                Task { await self.loadProfilesAndFilter(self.conversationRepo.getAllConversations(for: userId), userId: userId) }
            }
    }

    // MARK: - Data Loading

    func loadConversations() {
        guard let userId = currentUserId else { return }

        isLoading = true

        // Start real-time listener
        conversationListener?.remove()
        conversationListener = firestoreService.listenToConversations(
            for: userId,
            onChange: { [weak self] cloudConversations in
                Task { @MainActor in
                    self?.handleConversationsUpdate(cloudConversations, userId: userId)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    Logger.error(error, context: "ConversationsViewModel.loadConversations")
                    self?.error = error
                    self?.isLoading = false
                }
            }
        )

        // Load from local cache immediately
        Task {
            await loadFromLocalCache(userId: userId)
            isLoading = false
        }
    }

    private func loadFromLocalCache(userId: String) async {
        let localConversations = conversationRepo.getAllConversations(for: userId)
        await loadProfilesAndFilter(localConversations, userId: userId)
    }

    private func handleConversationsUpdate(_ cloudConversations: [Conversation], userId: String) {
        // Update local cache with cloud data
        for conversation in cloudConversations {
            conversationRepo.updateFromCloud(conversation)
        }

        // Load profiles for display
        Task {
            await loadProfilesAndFilter(cloudConversations, userId: userId)
        }
    }

    private func loadProfilesAndFilter(_ convos: [Conversation], userId: String) async {
        // Collect other participant IDs (excluding blocked users)
        let profileCache = ProfileCacheService.shared
        var validConvos: [(Conversation, String)] = []

        for conversation in convos {
            guard let otherUserId = conversation.participantIds.first(where: { $0 != userId }) else {
                continue
            }
            if friendshipRepo.isBlockedByOrBlocking(userId, otherUserId) {
                continue
            }
            validConvos.append((conversation, otherUserId))
        }

        // Prefetch all profiles in parallel
        let otherUserIds = validConvos.map { $0.1 }
        await profileCache.prefetch(userIds: otherUserIds)

        var result: [ConversationWithProfile] = []
        for (conversation, otherUserId) in validConvos {
            let userProfile = await profileCache.profile(for: otherUserId)
            result.append(ConversationWithProfile(
                conversation: conversation,
                otherParticipant: userProfile,
                otherParticipantFirebaseId: otherUserId
            ))
        }

        // Sort by most recent message
        conversations = result.sorted {
            ($0.conversation.lastMessageAt ?? $0.conversation.createdAt) >
            ($1.conversation.lastMessageAt ?? $1.conversation.createdAt)
        }
    }

    // MARK: - Actions

    /// Start or get existing conversation with a friend
    func startConversation(with friendId: String) async throws -> Conversation {
        guard let userId = currentUserId else {
            throw ConversationError.notAuthenticated
        }

        // Check if blocked
        if friendshipRepo.isBlockedByOrBlocking(userId, friendId) {
            throw ConversationError.userBlocked
        }

        // Generate canonical ID to check for existing conversation
        let participants = [userId, friendId].sorted()
        let canonicalId = Conversation.canonicalId(for: participants)

        // Try to fetch from Firestore first (in case other device created it)
        if let cloudConversation = try? await firestoreService.fetchConversation(id: canonicalId, for: userId) {
            conversationRepo.updateFromCloud(cloudConversation)
            return cloudConversation
        }

        // Get or create locally with canonical ID
        let conversation = conversationRepo.getOrCreateConversation(between: userId, and: friendId)

        // Sync to cloud
        do {
            try await firestoreService.saveConversation(conversation)
        } catch {
            Logger.error(error, context: "ConversationsViewModel.startConversation")
            // Continue with local conversation even if cloud sync fails
        }

        return conversation
    }

    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) async {
        // Delete locally
        messageRepo.deleteAllMessages(for: conversation.id)
        conversationRepo.delete(conversation)

        // Remove from cloud
        do {
            try await firestoreService.deleteConversation(id: conversation.id)
        } catch {
            Logger.error(error, context: "ConversationsViewModel.deleteConversation")
        }

        // Reload
        if let userId = currentUserId {
            await loadFromLocalCache(userId: userId)
        }
    }

    /// Mark conversation as read
    func markAsRead(_ conversationId: UUID) {
        guard let userId = currentUserId else { return }
        conversationRepo.markConversationRead(conversationId, for: userId)

        // Update local list
        if let index = conversations.firstIndex(where: { $0.conversation.id == conversationId }) {
            var updated = conversations[index].conversation
            updated.unreadCount = 0
            conversations[index] = ConversationWithProfile(
                conversation: updated,
                otherParticipant: conversations[index].otherParticipant,
                otherParticipantFirebaseId: conversations[index].otherParticipantFirebaseId
            )
        }
    }

    func stopListening(clearData: Bool = false) {
        conversationListener?.remove()
        conversationListener = nil
        if clearData {
            conversations = []
            isLoading = false
        }
    }
}

// MARK: - Errors

enum ConversationError: LocalizedError {
    case notAuthenticated
    case userBlocked
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to message"
        case .userBlocked:
            return "Cannot message this user"
        case .notFound:
            return "Conversation not found"
        }
    }
}
