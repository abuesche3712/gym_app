//
//  FriendsViewModel.swift
//  gym app
//
//  ViewModel for managing friends and friend requests
//

import Foundation
import FirebaseFirestore

/// Pairs a friendship with the other user's profile
struct FriendWithProfile: Identifiable {
    let friendship: Friendship
    let profile: UserProfile

    var id: UUID { friendship.id }
}

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [FriendWithProfile] = []
    @Published var incomingRequests: [FriendWithProfile] = []
    @Published var outgoingRequests: [FriendWithProfile] = []
    @Published var blockedUsers: [FriendWithProfile] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var isSearching = false

    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var friendshipListener: ListenerRegistration?
    private var searchTask: Task<Void, Never>?

    var currentUserId: String? {
        authService.currentUser?.uid
    }

    var pendingRequestCount: Int {
        incomingRequests.count
    }

    init(friendshipRepo: FriendshipRepository = DataRepository.shared.friendshipRepo) {
        self.friendshipRepo = friendshipRepo
    }

    deinit {
        friendshipListener?.remove()
    }

    // MARK: - Data Loading

    func loadFriendships() {
        guard let userId = currentUserId else { return }

        isLoading = true

        // Start real-time listener
        friendshipListener?.remove()
        friendshipListener = firestoreService.listenToFriendships(for: userId) { [weak self] cloudFriendships in
            Task { @MainActor in
                self?.handleFriendshipsUpdate(cloudFriendships, userId: userId)
            }
        }

        // Also load from local cache immediately
        Task {
            await loadFromLocalCache(userId: userId)
            isLoading = false
        }
    }

    private func loadFromLocalCache(userId: String) async {
        let localFriendships = friendshipRepo.getAllFriendships(for: userId)
        await categorizeAndLoadProfiles(localFriendships, userId: userId)
    }

    private func handleFriendshipsUpdate(_ cloudFriendships: [Friendship], userId: String) {
        // Update local cache with cloud data
        for friendship in cloudFriendships {
            friendshipRepo.updateFromCloud(friendship)
        }

        // Categorize and load profiles
        Task {
            await categorizeAndLoadProfiles(cloudFriendships, userId: userId)
        }
    }

    private func categorizeAndLoadProfiles(_ friendships: [Friendship], userId: String) async {
        var friendsList: [FriendWithProfile] = []
        var incoming: [FriendWithProfile] = []
        var outgoing: [FriendWithProfile] = []
        var blocked: [FriendWithProfile] = []

        // Profile cache to avoid duplicate fetches
        var profileCache: [String: UserProfile] = [:]

        for friendship in friendships {
            guard let otherUserId = friendship.otherUserId(from: userId) else { continue }

            // Get or fetch profile
            let profile: UserProfile?
            if let cached = profileCache[otherUserId] {
                profile = cached
            } else {
                do {
                    profile = try await firestoreService.fetchPublicProfile(userId: otherUserId)
                    if let p = profile {
                        profileCache[otherUserId] = p
                    }
                } catch {
                    Logger.error(error, context: "FriendsViewModel.fetchProfile")
                    profile = nil
                }
            }

            guard let userProfile = profile else { continue }

            let friendWithProfile = FriendWithProfile(friendship: friendship, profile: userProfile)

            switch friendship.status {
            case .accepted:
                friendsList.append(friendWithProfile)
            case .pending:
                if friendship.isIncomingRequest(for: userId) {
                    incoming.append(friendWithProfile)
                } else {
                    outgoing.append(friendWithProfile)
                }
            case .blocked:
                if friendship.requesterId == userId {
                    blocked.append(friendWithProfile)
                }
            }
        }

        // Sort by name
        friends = friendsList.sorted { ($0.profile.displayName ?? $0.profile.username) < ($1.profile.displayName ?? $1.profile.username) }
        incomingRequests = incoming.sorted { $0.friendship.createdAt > $1.friendship.createdAt }
        outgoingRequests = outgoing.sorted { $0.friendship.createdAt > $1.friendship.createdAt }
        blockedUsers = blocked.sorted { ($0.profile.displayName ?? $0.profile.username) < ($1.profile.displayName ?? $1.profile.username) }
    }

    // MARK: - Search

    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run { isSearching = true }

            do {
                var results = try await firestoreService.searchUsersByUsername(prefix: trimmed)

                // Filter out current user and blocked users
                if let myId = currentUserId {
                    results = results.filter { result in
                        // Don't show self
                        if result.firebaseUserId == myId { return false }

                        // Don't show users involved in a block relationship
                        if friendshipRepo.isBlockedByOrBlocking(myId, result.firebaseUserId) {
                            return false
                        }

                        return true
                    }
                }

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isSearching = false
                }
            }
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }

    // MARK: - Actions

    func sendRequest(to addresseeId: String) async throws {
        guard let requesterId = currentUserId else {
            throw FriendshipError.notFound
        }

        // Optimistic update
        let friendship = try friendshipRepo.sendFriendRequest(from: requesterId, to: addresseeId)

        // Sync to cloud
        do {
            try await firestoreService.saveFriendship(friendship)
        } catch {
            // Revert on failure
            friendshipRepo.delete(friendship)
            throw error
        }
    }

    func acceptRequest(_ friendship: Friendship) async throws {
        // Optimistic update
        try friendshipRepo.acceptFriendRequest(friendship)

        // Sync to cloud
        if let updated = friendshipRepo.getFriendship(id: friendship.id) {
            do {
                try await firestoreService.saveFriendship(updated)
            } catch {
                // Revert - restore pending status
                var reverted = updated
                reverted.status = .pending
                friendshipRepo.save(reverted)
                throw error
            }
        }

        // Reload to update UI
        if let userId = currentUserId {
            await loadFromLocalCache(userId: userId)
        }
    }

    func declineRequest(_ friendship: Friendship) async throws {
        // Optimistic delete
        try friendshipRepo.declineFriendRequest(friendship)

        // Sync to cloud
        do {
            try await firestoreService.deleteFriendship(id: friendship.id)
        } catch {
            // On failure, the listener will restore it from cloud
            throw error
        }

        // Reload to update UI
        if let userId = currentUserId {
            await loadFromLocalCache(userId: userId)
        }
    }

    func removeFriend(_ friendship: Friendship) async throws {
        // Delete locally
        friendshipRepo.delete(friendship)

        // Sync to cloud
        do {
            try await firestoreService.deleteFriendship(id: friendship.id)
        } catch {
            // On failure, the listener will restore it
            throw error
        }

        // Reload to update UI
        if let userId = currentUserId {
            await loadFromLocalCache(userId: userId)
        }
    }

    func blockUser(_ blockedId: String) async throws {
        guard let blockerId = currentUserId else {
            throw FriendshipError.notFound
        }

        // Block locally
        let friendship = try friendshipRepo.blockUser(blockerId: blockerId, blockedId: blockedId)

        // Sync to cloud
        do {
            try await firestoreService.saveFriendship(friendship)
        } catch {
            // Revert
            friendshipRepo.delete(friendship)
            throw error
        }

        // Reload to update UI
        await loadFromLocalCache(userId: blockerId)
    }

    func unblockUser(_ friendship: Friendship) async throws {
        // Unblock locally
        try friendshipRepo.unblockUser(friendship)

        // Sync to cloud
        do {
            try await firestoreService.deleteFriendship(id: friendship.id)
        } catch {
            // On failure, the listener will restore it
            throw error
        }

        // Reload to update UI
        if let userId = currentUserId {
            await loadFromLocalCache(userId: userId)
        }
    }

    // MARK: - Status Checks

    func friendshipStatus(with userId: String) -> FriendshipStatusCheck {
        guard let myId = currentUserId else { return .none }

        // Check local cache
        if let friendship = friendshipRepo.getFriendship(between: myId, and: userId) {
            switch friendship.status {
            case .accepted:
                return .friends(friendship)
            case .pending:
                if friendship.isIncomingRequest(for: myId) {
                    return .incomingRequest(friendship)
                } else {
                    return .outgoingRequest(friendship)
                }
            case .blocked:
                if friendship.requesterId == myId {
                    return .blockedByMe(friendship)
                } else {
                    return .blockedByThem
                }
            }
        }

        return .none
    }
}

// MARK: - Friendship Status Check

enum FriendshipStatusCheck {
    case none
    case friends(Friendship)
    case incomingRequest(Friendship)
    case outgoingRequest(Friendship)
    case blockedByMe(Friendship)
    case blockedByThem
}
