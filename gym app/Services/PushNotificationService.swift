//
//  PushNotificationService.swift
//  gym app
//
//  Manages push notification permissions, FCM token lifecycle,
//  foreground display, and deep-link routing for notification taps.
//

import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

// MARK: - Deep Link

enum NotificationDeepLink: Equatable {
    case post(postId: UUID)
    case friends
}

// MARK: - Push Notification Service

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingDeepLink: NotificationDeepLink?

    private let core = FirestoreCore.shared

    private static let permissionRequestedKey = "pushNotificationPermissionRequested"

    /// Whether the user has ever been prompted for notification permission
    var hasRequestedPermission: Bool {
        UserDefaults.standard.bool(forKey: Self.permissionRequestedKey)
    }

    override init() {
        super.init()
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Setup

    /// Called from AppDelegate after Firebase is configured.
    /// Sets delegates and registers for remote notifications.
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Logger.debug("PushNotificationService: setup complete")
    }

    // MARK: - Permission

    /// Refresh current authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Request notification permission if not already determined.
    /// Returns true if authorized.
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            // Already authorized — ensure we're registered for remote
            UIApplication.shared.registerForRemoteNotifications()
            return true

        case .denied:
            Logger.debug("PushNotificationService: permission denied by user")
            return false

        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                UserDefaults.standard.set(true, forKey: Self.permissionRequestedKey)
                await refreshAuthorizationStatus()
                if granted {
                    Logger.debug("PushNotificationService: permission granted")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    Logger.debug("PushNotificationService: permission declined")
                }
                return granted
            } catch {
                Logger.error(error, context: "PushNotificationService.requestPermission")
                return false
            }

        @unknown default:
            return false
        }
    }

    // MARK: - FCM Token Management

    /// Save the current FCM token to Firestore for the authenticated user.
    func saveFCMToken() async {
        guard core.isAuthenticated else { return }

        do {
            guard let token = Messaging.messaging().fcmToken else {
                Logger.debug("PushNotificationService: no FCM token available yet")
                return
            }

            let settingsRef = try core.userCollection(FirestoreCollections.profile)
                .document(FirestoreCollections.profileSettings)

            try await settingsRef.setData(["fcmToken": token], merge: true)
            Logger.debug("PushNotificationService: saved FCM token")
        } catch {
            Logger.error(error, context: "PushNotificationService.saveFCMToken")
        }
    }

    /// Remove the FCM token from Firestore and delete the local FCM registration.
    func clearFCMToken() async {
        // Remove from Firestore
        if core.isAuthenticated {
            do {
                let settingsRef = try core.userCollection(FirestoreCollections.profile)
                    .document(FirestoreCollections.profileSettings)

                try await settingsRef.updateData(["fcmToken": FieldValue.delete()])
                Logger.debug("PushNotificationService: cleared FCM token from Firestore")
            } catch {
                Logger.error(error, context: "PushNotificationService.clearFCMToken")
            }
        }

        // Delete local FCM token
        do {
            try await Messaging.messaging().deleteToken()
            Logger.debug("PushNotificationService: deleted local FCM token")
        } catch {
            Logger.error(error, context: "PushNotificationService.deleteFCMToken")
        }
    }

    // MARK: - Deep Link Handling

    /// Parse notification payload and return a deep link if applicable.
    nonisolated private static func parseDeepLink(from userInfo: [AnyHashable: Any]) -> NotificationDeepLink? {
        guard let typeString = userInfo["type"] as? String else { return nil }

        switch typeString {
        case "like", "comment":
            if let postIdString = userInfo["postId"] as? String,
               let postId = UUID(uuidString: postIdString) {
                return .post(postId: postId)
            }
        case "friendRequest", "friendAccepted":
            return .friends
        default:
            break
        }

        return nil
    }

    /// Consume and return the pending deep link (caller is responsible for navigation).
    func consumeDeepLink() -> NotificationDeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// Foreground notification display — show as banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Logger.debug("PushNotificationService: foreground notification received")
        return [.banner, .badge, .sound]
    }

    /// Notification tap — extract deep link for navigation.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        Logger.debug("PushNotificationService: notification tapped, payload: \(userInfo)")
        let deepLink = Self.parseDeepLink(from: userInfo)

        await MainActor.run {
            if let deepLink {
                pendingDeepLink = deepLink
            }
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: @preconcurrency MessagingDelegate {

    /// Called when FCM token is generated or refreshed.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard fcmToken != nil else { return }
        Logger.debug("PushNotificationService: FCM token refreshed")

        Task {
            await saveFCMToken()
        }

        // TODO: Phase 2 — Cloud Function triggered by Firestore writes to users/{userId}/activities/
        // TODO: Phase 2 — Function reads recipient's FCM token and sends notification
        // TODO: Phase 2 — Rate limiting (batch rapid likes into one notification)
        // TODO: Phase 2 — Badge count management
    }
}
