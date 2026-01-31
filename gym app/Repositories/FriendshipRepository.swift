//
//  FriendshipRepository.swift
//  gym app
//
//  Handles Friendship CRUD operations and CoreData conversion
//

import CoreData
import Combine

@MainActor
class FriendshipRepository: ObservableObject {
    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    @Published private(set) var friendships: [Friendship] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadAll()
    }

    // MARK: - CRUD Operations

    /// Load all friendships from CoreData
    func loadAll() {
        let request = NSFetchRequest<FriendshipEntity>(entityName: "FriendshipEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        do {
            let entities = try viewContext.fetch(request)
            friendships = entities.map { $0.toModel() }
        } catch {
            Logger.error(error, context: "FriendshipRepository.loadAll")
        }
    }

    /// Save or update a friendship
    func save(_ friendship: Friendship) {
        var friendshipToSave = friendship
        friendshipToSave.updatedAt = Date()
        friendshipToSave.syncStatus = .pendingSync

        let entity = findOrCreateEntity(id: friendship.id)
        entity.update(from: friendshipToSave)
        persistence.save()

        loadAll()
    }

    /// Delete a friendship
    func delete(_ friendship: Friendship) {
        if let entity = findEntity(id: friendship.id) {
            viewContext.delete(entity)
            persistence.save()
        }
        loadAll()
    }

    /// Get a friendship by ID
    func getFriendship(id: UUID) -> Friendship? {
        friendships.first { $0.id == id }
    }

    // MARK: - Query Operations

    /// Get friendship between two users (if exists)
    func getFriendship(between userA: String, and userB: String) -> Friendship? {
        friendships.first { friendship in
            (friendship.requesterId == userA && friendship.addresseeId == userB) ||
            (friendship.requesterId == userB && friendship.addresseeId == userA)
        }
    }

    /// Get all friendships involving a user
    func getAllFriendships(for userId: String) -> [Friendship] {
        friendships.filter { $0.involves(userId: userId) }
    }

    /// Get accepted friends for a user
    func getAcceptedFriends(for userId: String) -> [Friendship] {
        friendships.filter { $0.involves(userId: userId) && $0.isAccepted }
    }

    /// Get pending incoming requests (requests TO the user)
    func getPendingIncoming(for userId: String) -> [Friendship] {
        friendships.filter { $0.isIncomingRequest(for: userId) }
    }

    /// Get pending outgoing requests (requests FROM the user)
    func getPendingOutgoing(for userId: String) -> [Friendship] {
        friendships.filter { $0.isOutgoingRequest(from: userId) }
    }

    /// Get users blocked by this user
    func getBlockedUsers(for userId: String) -> [Friendship] {
        friendships.filter { $0.requesterId == userId && $0.isBlocked }
    }

    /// Get all blocked relationships (either direction)
    func getBlockedRelationships(for userId: String) -> [Friendship] {
        friendships.filter { $0.involves(userId: userId) && $0.isBlocked }
    }

    // MARK: - Actions

    /// Send a friend request
    func sendFriendRequest(from requesterId: String, to addresseeId: String) throws -> Friendship {
        // Check if blocked
        if isBlockedByOrBlocking(requesterId, addresseeId) {
            throw FriendshipError.blocked
        }

        // Check for existing friendship/request
        if let existing = getFriendship(between: requesterId, and: addresseeId) {
            if existing.isAccepted {
                throw FriendshipError.alreadyFriends
            }
            if existing.isPending {
                // If the other person sent a request, auto-accept (simultaneous request)
                if existing.isIncomingRequest(for: requesterId) {
                    var accepted = existing
                    accepted.status = .accepted
                    accepted.updatedAt = Date()
                    save(accepted)
                    return accepted
                }
                throw FriendshipError.requestAlreadySent
            }
        }

        let friendship = Friendship(
            requesterId: requesterId,
            addresseeId: addresseeId,
            status: .pending
        )

        save(friendship)
        return friendship
    }

    /// Accept a friend request
    func acceptFriendRequest(_ friendship: Friendship) throws {
        guard friendship.isPending else {
            throw FriendshipError.invalidState
        }

        var accepted = friendship
        accepted.status = .accepted
        accepted.updatedAt = Date()
        save(accepted)
    }

    /// Decline a friend request (just deletes it)
    func declineFriendRequest(_ friendship: Friendship) throws {
        guard friendship.isPending else {
            throw FriendshipError.invalidState
        }
        delete(friendship)
    }

    /// Block a user
    func blockUser(blockerId: String, blockedId: String) throws -> Friendship {
        // Check for existing relationship
        if let existing = getFriendship(between: blockerId, and: blockedId) {
            // If we're the requester, just update status
            if existing.requesterId == blockerId {
                var blocked = existing
                blocked.status = .blocked
                blocked.updatedAt = Date()
                save(blocked)
                return blocked
            } else {
                // Need to create a new friendship with us as requester (blocker)
                delete(existing)
            }
        }

        let friendship = Friendship(
            requesterId: blockerId,
            addresseeId: blockedId,
            status: .blocked
        )

        save(friendship)
        return friendship
    }

    /// Unblock a user (deletes the blocked friendship)
    func unblockUser(_ friendship: Friendship) throws {
        guard friendship.isBlocked else {
            throw FriendshipError.invalidState
        }
        delete(friendship)
    }

    // MARK: - Checks

    /// Check if two users are friends
    func areFriends(_ userA: String, _ userB: String) -> Bool {
        getFriendship(between: userA, and: userB)?.isAccepted == true
    }

    /// Check if checker blocked target
    func isBlocked(checker: String, target: String) -> Bool {
        friendships.contains { friendship in
            friendship.requesterId == checker &&
            friendship.addresseeId == target &&
            friendship.isBlocked
        }
    }

    /// Check if either user blocked the other
    func isBlockedByOrBlocking(_ userA: String, _ userB: String) -> Bool {
        isBlocked(checker: userA, target: userB) || isBlocked(checker: userB, target: userA)
    }

    // MARK: - Entity Operations (for sync)

    func findEntity(id: UUID) -> FriendshipEntity? {
        let request = NSFetchRequest<FriendshipEntity>(entityName: "FriendshipEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? viewContext.fetch(request).first
    }

    /// Update from cloud data
    func updateFromCloud(_ cloudFriendship: Friendship) {
        // Only update if cloud is newer
        if let local = getFriendship(id: cloudFriendship.id) {
            if cloudFriendship.updatedAt > local.updatedAt {
                let entity = findOrCreateEntity(id: cloudFriendship.id)
                var merged = cloudFriendship
                merged.syncStatus = .synced
                entity.update(from: merged)
                persistence.save()
                loadAll()
            }
        } else {
            // No local version, save cloud version
            let entity = findOrCreateEntity(id: cloudFriendship.id)
            var merged = cloudFriendship
            merged.syncStatus = .synced
            entity.update(from: merged)
            persistence.save()
            loadAll()
        }
    }

    /// Delete from cloud sync
    func deleteFromCloud(id: UUID) {
        if let entity = findEntity(id: id) {
            viewContext.delete(entity)
            persistence.save()
            loadAll()
        }
    }

    // MARK: - Private Helpers

    private func findOrCreateEntity(id: UUID) -> FriendshipEntity {
        if let existing = findEntity(id: id) {
            return existing
        }
        let entity = FriendshipEntity(context: viewContext)
        entity.id = id
        return entity
    }
}

// MARK: - Friendship Errors

enum FriendshipError: Error, LocalizedError {
    case alreadyFriends
    case requestAlreadySent
    case blocked
    case invalidState
    case notFound

    var errorDescription: String? {
        switch self {
        case .alreadyFriends:
            return "You are already friends with this user"
        case .requestAlreadySent:
            return "Friend request already sent"
        case .blocked:
            return "Cannot send request to this user"
        case .invalidState:
            return "Invalid friendship state for this action"
        case .notFound:
            return "Friendship not found"
        }
    }
}
