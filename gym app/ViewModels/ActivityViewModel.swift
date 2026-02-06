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
    private var profileCache: [String: UserProfile] = [:]

    var currentUserId: String? { authService.currentUser?.uid }

    deinit {
        activityListener?.remove()
    }

    // MARK: - Loading

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
        var result: [ActivityWithActor] = []

        unreadCount = activities.filter { !$0.isRead }.count

        for activity in activities {
            let profile: UserProfile

            if let cached = profileCache[activity.actorId] {
                profile = cached
            } else if let fetched = try? await firestoreService.fetchPublicProfile(userId: activity.actorId) {
                profileCache[activity.actorId] = fetched
                profile = fetched
            } else {
                profile = UserProfile(id: UUID(), username: "unknown", displayName: "Unknown User")
            }

            result.append(ActivityWithActor(activity: activity, actor: profile))
        }

        self.activities = result
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
                    unreadCount = max(0, unreadCount - 1)
                }
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
                unreadCount = 0
            } catch {
                Logger.error(error, context: "ActivityViewModel.markAllAsRead")
            }
        }
    }
}
