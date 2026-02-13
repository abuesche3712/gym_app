//
//  ActivityViewModel.swift
//  gym app
//
//  ViewModel for managing activity/notification feed
//

import Foundation
import FirebaseFirestore

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var activities: [ActivityWithActor] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?

    private let activityService = FirestoreActivityService.shared
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    private var activityListener: ListenerRegistration?
    private let profileCache = ProfileCacheService.shared

    var currentUserId: String? { authService.currentUser?.uid }

    deinit {
        activityListener?.remove()
    }

    // MARK: - Loading

    func stopListening(clearData: Bool = false) {
        activityListener?.remove()
        activityListener = nil
        if clearData {
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

        self.activities = result
    }

    private func refreshUnreadCount(for userId: String) async {
        do {
            unreadCount = try await firestoreService.fetchUnreadActivityCount(userId: userId)
        } catch {
            unreadCount = activities.filter { !$0.activity.isRead }.count
            Logger.error(error, context: "ActivityViewModel.refreshUnreadCount")
        }
    }

    // MARK: - Actions

    func markAsRead(_ activity: ActivityWithActor) {
        guard let userId = currentUserId else { return }

        Task {
            do {
                try await activityService.markAsRead(userId: userId, activityId: activity.activity.id)

                // Update local state
                if let index = activities.firstIndex(where: { $0.id == activity.id }) {
                    var updated = activities[index].activity
                    updated.isRead = true
                    activities[index] = ActivityWithActor(activity: updated, actor: activities[index].actor)
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

                // Update local state
                activities = activities.map { item in
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
