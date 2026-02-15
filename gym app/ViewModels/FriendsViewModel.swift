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

    @Published var suggestedFriends: [UserSearchResult] = []
    @Published var isLoadingSuggestions = false

    @Published var searchQuery = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var isSearching = false

    private let friendshipRepo: FriendshipRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let activityService = FirestoreActivityService.shared

    private var friendshipListener: ListenerRegistration?
    private var searchTask: Task<Void, Never>?
    private let minimumSearchQueryLength = 2

    var currentUserId: String? {
        authService.currentUser?.uid
    }

    var pendingRequestCount: Int {
        incomingRequests.count
    }

    init(friendshipRepo: FriendshipRepository? = nil) {
        self.friendshipRepo = friendshipRepo ?? DataRepository.shared.friendshipRepo
    }

    deinit {
        friendshipListener?.remove()
    }

    // MARK: - Data Loading

    func stopListening(clearData: Bool = false) {
        friendshipListener?.remove()
        friendshipListener = nil
        searchTask?.cancel()
        if clearData {
            friends = []
            incomingRequests = []
            outgoingRequests = []
            blockedUsers = []
            suggestedFriends = []
            searchResults = []
            isLoading = false
            isSearching = false
        }
    }

    func loadFriendships() {
        guard let userId = currentUserId else { return }

        isLoading = true

        // Run one-time migration of friendIds array if needed
        migrateFriendIdsIfNeeded()

        // Start real-time listener
        friendshipListener?.remove()
        friendshipListener = firestoreService.listenToFriendships(
            for: userId,
            onChange: { [weak self] cloudFriendships in
                Task { @MainActor in
                    self?.handleFriendshipsUpdate(cloudFriendships, userId: userId)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    Logger.error(error, context: "FriendsViewModel.loadFriendships")
                    self?.error = error
                    self?.isLoading = false
                }
            }
        )

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
        // Get IDs that exist in cloud
        let cloudIds = Set(cloudFriendships.map { $0.id })

        // Get IDs that exist locally for this user
        let localFriendships = friendshipRepo.getAllFriendships(for: userId)
        let localIds = Set(localFriendships.map { $0.id })

        // Delete local friendships that no longer exist in cloud
        let deletedIds = localIds.subtracting(cloudIds)
        for deletedId in deletedIds {
            friendshipRepo.deleteFromCloud(id: deletedId)
        }

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

        // Prefetch all profiles in parallel
        let profileCache = ProfileCacheService.shared
        let otherUserIds = friendships.compactMap { $0.otherUserId(from: userId) }
        await profileCache.prefetch(userIds: otherUserIds)

        for friendship in friendships {
            guard let otherUserId = friendship.otherUserId(from: userId) else { continue }

            let userProfile = await profileCache.profile(for: otherUserId)
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
            isSearching = false
            return
        }

        guard trimmed.count >= minimumSearchQueryLength else {
            searchResults = []
            isSearching = false
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

            // Create activity for addressee
            let activity = Activity(
                recipientId: addresseeId,
                actorId: requesterId,
                type: .friendRequest
            )
            try? await activityService.createActivity(activity)
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

                // Update denormalized friendIds arrays for both users
                if let myId = currentUserId, let friendId = friendship.otherUserId(from: myId) {
                    try? await firestoreService.updateFriendIdsArray(userId: myId, friendId: friendId, add: true)
                    try? await firestoreService.updateFriendIdsArray(userId: friendId, friendId: myId, add: true)
                }

                // Create activity for requester
                if let myId = currentUserId {
                    let activity = Activity(
                        recipientId: friendship.requesterId,
                        actorId: myId,
                        type: .friendAccepted
                    )
                    try? await activityService.createActivity(activity)
                }
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

            // Update denormalized friendIds arrays for both users
            if let myId = currentUserId, let friendId = friendship.otherUserId(from: myId) {
                try? await firestoreService.updateFriendIdsArray(userId: myId, friendId: friendId, add: false)
                try? await firestoreService.updateFriendIdsArray(userId: friendId, friendId: myId, add: false)
            }
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

            // Remove from denormalized friendIds arrays (they were friends before blocking)
            try? await firestoreService.updateFriendIdsArray(userId: blockerId, friendId: blockedId, add: false)
            try? await firestoreService.updateFriendIdsArray(userId: blockedId, friendId: blockerId, add: false)
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

    // MARK: - Suggested Friends

    func loadSuggestedFriends() {
        guard let myId = currentUserId else { return }

        isLoadingSuggestions = true

        Task {
            defer { isLoadingSuggestions = false }

            let startTime = CFAbsoluteTimeGetCurrent()

            // Get current friend IDs
            let myFriends = friendshipRepo.getAcceptedFriends(for: myId)
            let myFriendIds = Set(myFriends.compactMap { $0.otherUserId(from: myId) })

            // Get all friendship IDs (including pending/blocked) to exclude
            let allFriendships = friendshipRepo.getAllFriendships(for: myId)
            let allRelatedIds = Set(allFriendships.compactMap { $0.otherUserId(from: myId) })

            let friendList = Array(myFriendIds.prefix(10))
            var candidateIds: Set<String> = []
            var usedBatchedApproach = false

            // Option A: Batched approach using denormalized friendIds arrays
            // Fetch friend profiles in one batch and extract their friendIds client-side
            do {
                let friendProfiles = try await firestoreService.fetchProfilesBatched(userIds: friendList)

                // Check if any profile has the friendIds field populated
                let profilesWithFriendIds = friendProfiles.values.filter { $0.friendIds != nil }

                if !profilesWithFriendIds.isEmpty {
                    usedBatchedApproach = true

                    for (friendId, profile) in friendProfiles {
                        guard let fofIds = profile.friendIds else { continue }
                        for fofId in fofIds {
                            if fofId != myId && !allRelatedIds.contains(fofId) {
                                candidateIds.insert(fofId)
                            }
                        }
                        // Also skip the friend themselves
                        candidateIds.remove(friendId)
                    }
                }
            } catch {
                Logger.error(error, context: "FriendsViewModel.loadSuggestedFriends (batched)")
            }

            // Fallback: N+1 approach if friendIds not available (backward compat)
            if !usedBatchedApproach {
                Logger.debug("loadSuggestedFriends: falling back to N+1 approach (friendIds not populated)")
                await withTaskGroup(of: [String].self) { group in
                    for friendId in friendList {
                        group.addTask {
                            do {
                                let friendsFriendships = try await self.firestoreService.fetchFriendships(for: friendId)
                                return friendsFriendships
                                    .filter { $0.status == .accepted }
                                    .compactMap { $0.otherUserId(from: friendId) }
                            } catch {
                                Logger.error(error, context: "FriendsViewModel.loadSuggestedFriends (fallback)")
                                return []
                            }
                        }
                    }

                    for await friendIds in group {
                        for fofId in friendIds {
                            if fofId != myId && !allRelatedIds.contains(fofId) {
                                candidateIds.insert(fofId)
                            }
                        }
                    }
                }
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            Logger.debug("loadSuggestedFriends: found \(candidateIds.count) candidates in \(String(format: "%.2f", elapsed))s (batched: \(usedBatchedApproach))")

            // Fetch profiles for candidates
            let candidateList = Array(candidateIds.prefix(5))
            let profileCache = ProfileCacheService.shared
            await profileCache.prefetch(userIds: candidateList)

            var suggestions: [UserSearchResult] = []
            for candidateId in candidateList {
                let profile = await profileCache.profile(for: candidateId)
                // Skip placeholder profiles (fetch failed) rather than showing "unknown"
                guard profile.username != "unknown" else {
                    Logger.debug("loadSuggestedFriends: skipping candidate \(candidateId) — profile fetch failed")
                    continue
                }
                suggestions.append(UserSearchResult(firebaseUserId: candidateId, profile: profile))
            }

            suggestedFriends = suggestions
        }
    }

    // TODO: Option B — Cloud Function that maintains a dedicated `friendGraph` collection.
    // Each doc: { userId: string, friendIds: [string], updatedAt: timestamp }
    // Updated automatically on friendship changes via Firestore triggers.
    // More scalable for users with 100+ friends since profile docs stay lean.

    // MARK: - Friend IDs Migration

    private static let friendIdsMigratedKey = "friendIdsMigrated"

    /// One-time migration: builds the friendIds array for the current user's profile.
    /// Called when friendships are first loaded after auth.
    func migrateFriendIdsIfNeeded() {
        guard let myId = currentUserId else { return }
        guard !UserDefaults.standard.bool(forKey: Self.friendIdsMigratedKey) else { return }

        Task {
            do {
                let friendships = try await firestoreService.fetchFriendships(for: myId)
                let acceptedFriendIds = friendships
                    .filter { $0.status == .accepted }
                    .compactMap { $0.otherUserId(from: myId) }

                guard !acceptedFriendIds.isEmpty else {
                    UserDefaults.standard.set(true, forKey: Self.friendIdsMigratedKey)
                    Logger.debug("friendIds migration: no accepted friends, marking complete")
                    return
                }

                try await firestoreService.setFriendIdsArray(userId: myId, friendIds: acceptedFriendIds)

                UserDefaults.standard.set(true, forKey: Self.friendIdsMigratedKey)
                Logger.debug("friendIds migration: wrote \(acceptedFriendIds.count) friend IDs")
            } catch {
                Logger.error(error, context: "friendIds migration failed")
                // Don't set the flag — will retry next launch
            }
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
