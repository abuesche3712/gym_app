//
//  ActivityViewModel.swift
//  gym app
//
//  ViewModel for managing activity/notification feed
//

import Foundation
import FirebaseFirestore
import Combine

/// Single in-memory source of truth for activity/notification state, shared by every
/// `ActivityViewModel` instance.
///
/// Unlike friendships/conversations, activities have no local CoreData-backed
/// repository (they're cloud-only, see `FirestoreActivityService`), so each screen's
/// `ActivityViewModel` previously kept its own private `@Published` copy fed only by
/// its own Firestore listener. A local mutation performed by one instance (e.g.
/// `markAllAsRead` from `ActivityFeedView`) never reached a sibling instance's state
/// (e.g. `SocialView`'s unread badge) until that sibling's own listener happened to
/// re-fire. This store plays the same role `FriendshipRepository`/
/// `ConversationRepository` play for friends/conversations: every `ActivityViewModel`
/// mirrors this shared object's published state, so a mutation from any instance is
/// visible to all instances immediately.
@MainActor
final class ActivityStore: ObservableObject {
    static let shared = ActivityStore()

    @Published var activities: [ActivityWithActor] = []
    @Published var unreadCount: Int = 0

    private var signOutCancellable: AnyCancellable?

    private init() {
        setupSignOutObserver()
    }

    /// Clears the shared activity state on sign-out (or account deletion) so a
    /// previous account's activities never bleed into a newly signed-in account's
    /// view before that account's own listener has a chance to populate the store.
    /// Per-instance Firestore listeners are torn down separately by each
    /// `ActivityViewModel`, which owns its own `activityListener`.
    private func setupSignOutObserver() {
        signOutCancellable = NotificationCenter.default.publisher(for: .userDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.debug("ActivityStore: received userDidSignOut, clearing shared state")
                self?.activities = []
                self?.unreadCount = 0
            }
    }
}

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var activities: [ActivityWithActor] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?

    private let activityService = FirestoreActivityService.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    private let store: ActivityStore

    private var activityListener: ListenerRegistration?
    private let profileCache = ProfileCacheService.shared
    private var storeCancellables: Set<AnyCancellable> = []
    private var signOutCancellable: AnyCancellable?

    var currentUserId: String? { authService.currentUser?.uid }

    init(store: ActivityStore = .shared) {
        self.store = store
        setupStoreObserver()
        setupSignOutObserver()
    }

    deinit {
        activityListener?.remove()
        signOutCancellable?.cancel()
    }

    /// Stops this instance's Firestore listener when the user signs out (or deletes
    /// their account) — the shared `ActivityStore` clears its own published state
    /// independently (see `ActivityStore.setupSignOutObserver`).
    private func setupSignOutObserver() {
        signOutCancellable = NotificationCenter.default.publisher(for: .userDidSignOut)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Logger.debug("ActivityViewModel: received userDidSignOut, tearing down listener")
                self?.stopListening(clearData: true)
            }
    }

    /// Mirrors `ActivityStore.shared`'s published state into this instance's own
    /// `@Published` properties, so existing view bindings (`viewModel.activities`,
    /// `viewModel.unreadCount`) keep working unchanged while the underlying data is
    /// shared across every `ActivityViewModel` instance.
    private func setupStoreObserver() {
        store.$activities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activities in
                self?.activities = activities
            }
            .store(in: &storeCancellables)

        store.$unreadCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.unreadCount = count
            }
            .store(in: &storeCancellables)
    }

    // MARK: - Loading

    func stopListening(clearData: Bool = false) {
        activityListener?.remove()
        activityListener = nil
        if clearData {
            // Only clear this instance's mirrored view of the data, not the shared
            // store — another still-active instance (or this same screen reappearing)
            // may still need it.
            activities = []
            unreadCount = 0
            isLoading = false
        }
    }

    func loadActivities() {
        guard let userId = currentUserId else { return }

        isLoading = true

        activityListener?.remove()
        activityListener = activityService.listenToActivities(
            userId: userId,
            limit: 50,
            onChange: { [weak self] activities in
                Task { @MainActor in
                    await self?.processActivities(activities)
                    await self?.refreshUnreadCount(for: userId)
                    self?.isLoading = false
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.error = error
                    self?.isLoading = false
                }
            }
        )
    }

    private func processActivities(_ activities: [Activity]) async {
        // Prefetch all unique actor profiles in parallel
        let uniqueActorIds = Array(Set(activities.map { $0.actorId }))
        await profileCache.prefetch(userIds: uniqueActorIds)

        var result: [ActivityWithActor] = []
        for activity in activities {
            let profile = await profileCache.profile(for: activity.actorId)
            result.append(ActivityWithActor(activity: activity, actor: profile))
        }

        // Write through the shared store so every ActivityViewModel instance observes
        // the update (see ActivityStore doc comment above).
        store.activities = result
    }

    private func refreshUnreadCount(for userId: String) async {
        do {
            store.unreadCount = try await firestoreService.fetchUnreadActivityCount(userId: userId)
        } catch {
            store.unreadCount = store.activities.filter { !$0.activity.isRead }.count
            Logger.error(error, context: "ActivityViewModel.refreshUnreadCount")
        }
    }

    // MARK: - Actions

    func markAsRead(_ activity: ActivityWithActor) {
        guard let userId = currentUserId else { return }

        Task {
            do {
                try await activityService.markAsRead(userId: userId, activityId: activity.activity.id)

                // Update shared state so all instances (e.g. SocialView's badge) reflect
                // the read status immediately, not just the acting instance.
                if let index = store.activities.firstIndex(where: { $0.id == activity.id }) {
                    var updated = store.activities[index].activity
                    updated.isRead = true
                    store.activities[index] = ActivityWithActor(activity: updated, actor: store.activities[index].actor)
                }
                await refreshUnreadCount(for: userId)
            } catch {
                Logger.error(error, context: "ActivityViewModel.markAsRead")
            }
        }
    }

    func markAllAsRead() {
        guard let userId = currentUserId else { return }

        Task {
            do {
                try await activityService.markAllAsRead(userId: userId)

                // Update shared state so all instances reflect the read status
                // immediately, not just the acting instance.
                store.activities = store.activities.map { item in
                    var updated = item.activity
                    updated.isRead = true
                    return ActivityWithActor(activity: updated, actor: item.actor)
                }
                await refreshUnreadCount(for: userId)
            } catch {
                Logger.error(error, context: "ActivityViewModel.markAllAsRead")
            }
        }
    }
}
