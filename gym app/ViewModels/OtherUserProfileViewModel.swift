//
//  OtherUserProfileViewModel.swift
//  gym app
//
//  ViewModel for viewing another user's profile
//

import Foundation
import FirebaseFirestore

@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var posts: [PostWithAuthor] = []
    @Published var friendshipStatus: FriendshipStatusCheck = .none
    @Published var isLoading = false
    @Published var error: Error?

    let firebaseUserId: String

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let friendshipRepo: FriendshipRepository

    var currentUserId: String? { authService.currentUser?.uid }

    init(
        profile: UserProfile,
        firebaseUserId: String,
        friendshipRepo: FriendshipRepository? = nil
    ) {
        self.profile = profile
        self.firebaseUserId = firebaseUserId
        self.friendshipRepo = friendshipRepo ?? DataRepository.shared.friendshipRepo
    }

    // MARK: - Loading

    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        checkFriendshipStatus()
        await loadPosts()
    }

    func loadPosts() async {
        do {
            let fetchedPosts = try await firestoreService.fetchPostsByUser(userId: firebaseUserId, limit: 20)
            var postsWithAuthors: [PostWithAuthor] = []
            for post in fetchedPosts {
                postsWithAuthors.append(PostWithAuthor(post: post, author: profile))
            }
            posts = postsWithAuthors
        } catch {
            Logger.error(error, context: "OtherUserProfileViewModel.loadPosts")
            self.error = error
        }
    }

    func checkFriendshipStatus() {
        guard let myId = currentUserId else { return }

        if let friendship = friendshipRepo.getFriendship(between: myId, and: firebaseUserId) {
            switch friendship.status {
            case .accepted:
                friendshipStatus = .friends(friendship)
            case .pending:
                if friendship.isIncomingRequest(for: myId) {
                    friendshipStatus = .incomingRequest(friendship)
                } else {
                    friendshipStatus = .outgoingRequest(friendship)
                }
            case .blocked:
                if friendship.requesterId == myId {
                    friendshipStatus = .blockedByMe(friendship)
                } else {
                    friendshipStatus = .blockedByThem
                }
            }
        } else {
            friendshipStatus = .none
        }
    }

    // MARK: - Actions

    func sendFriendRequest() async throws {
        guard let myId = currentUserId else { return }

        let friendship = try friendshipRepo.sendFriendRequest(from: myId, to: firebaseUserId)
        do {
            try await firestoreService.saveFriendship(friendship)
            checkFriendshipStatus()
        } catch {
            friendshipRepo.delete(friendship)
            throw error
        }
    }

    func acceptFriendRequest(_ friendship: Friendship) async throws {
        try friendshipRepo.acceptFriendRequest(friendship)

        if let updated = friendshipRepo.getFriendship(id: friendship.id) {
            do {
                try await firestoreService.saveFriendship(updated)
                checkFriendshipStatus()
            } catch {
                var reverted = updated
                reverted.status = .pending
                friendshipRepo.save(reverted)
                throw error
            }
        }
    }

    func blockUser() async throws {
        guard let myId = currentUserId else { return }

        let friendship = try friendshipRepo.blockUser(blockerId: myId, blockedId: firebaseUserId)
        do {
            try await firestoreService.saveFriendship(friendship)
            checkFriendshipStatus()
        } catch {
            friendshipRepo.delete(friendship)
            throw error
        }
    }

    func startConversation() async throws -> Conversation {
        guard currentUserId != nil else {
            throw MessageError.notAuthenticated
        }

        let conversationsViewModel = ConversationsViewModel()
        return try await conversationsViewModel.startConversation(with: firebaseUserId)
    }
}
