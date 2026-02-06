//
//  BackgroundSessionManager.swift
//  gym app
//
//  Manages background session persistence and notifications
//  Keeps workout sessions alive when app is backgrounded
//

import Foundation
import UIKit
import UserNotifications

class BackgroundSessionManager: NSObject, ObservableObject {
    static let shared = BackgroundSessionManager()

    // Session timeout: 2 hours in seconds
    private let sessionTimeout: TimeInterval = 7200 // 2 hours

    // Warning time: 10 minutes before timeout (110 minutes after background)
    private let warningOffset: TimeInterval = 6600 // 1 hour 50 minutes

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundEntryTime: Date?
    private var warningNotificationScheduled = false

    private override init() {
        super.init()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        // Only manage background tasks if there's an active session
        Task { @MainActor in
            guard AppState.shared.sessionViewModel.isSessionActive else { return }

            // Immediately save the in-progress session before iOS suspends the app (non-debounced)
            let sessionVM = AppState.shared.sessionViewModel
            if let session = sessionVM.currentSession {
                DataRepository.shared.saveInProgressSession(session)
            }

            self.backgroundEntryTime = Date()
            self.startBackgroundTask()
            self.scheduleWarningNotification()
            self.scheduleTimeoutCheck()

            Logger.debug("Session entered background at \(Date())")
        }
    }

    @objc private func appWillEnterForeground() {
        Task { @MainActor in
            self.backgroundEntryTime = nil
            self.warningNotificationScheduled = false
            self.endBackgroundTask()
            self.cancelScheduledNotifications()

            // Check if session exceeded timeout while in background
            self.checkSessionTimeout()

            Logger.debug("Session returned to foreground at \(Date())")
        }
    }

    /// Start a background task to extend execution time
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Called when background time is about to expire
            self?.endBackgroundTask()
        }
    }

    /// End the background task
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    /// Schedule a local notification to warn user 10 minutes before timeout
    private func scheduleWarningNotification() {
        guard !warningNotificationScheduled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Workout Still Active"
        content.body = "Your workout will be saved and ended in 10 minutes. Return to the app to continue."
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_WARNING"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: warningOffset,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "workout-timeout-warning",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                Logger.error(error, context: "Failed to schedule warning notification")
            } else {
                DispatchQueue.main.async {
                    self?.warningNotificationScheduled = true
                    Logger.debug("Scheduled warning notification for \(self?.warningOffset ?? 0) seconds")
                }
            }
        }
    }

    /// Schedule a check to auto-end session after 2 hours
    private func scheduleTimeoutCheck() {
        // Use a timer to check if we've exceeded timeout
        // This will run as long as the app is in background task mode
        Task {
            try? await Task.sleep(nanoseconds: UInt64(sessionTimeout * 1_000_000_000))
            await checkAndEndSessionIfTimeout()
        }
    }

    /// Check if session has exceeded timeout and end it
    private func checkSessionTimeout() {
        guard let entryTime = backgroundEntryTime else { return }

        let timeInBackground = Date().timeIntervalSince(entryTime)

        if timeInBackground >= sessionTimeout {
            Logger.debug("Session exceeded \(sessionTimeout)s timeout, was in background for \(timeInBackground)s")
            // Session will be available for recovery via crash recovery
            // We don't auto-cancel, just let the user know via the saved state
        }
    }

    /// Check and end session if timeout exceeded (called from timer)
    private func checkAndEndSessionIfTimeout() {
        guard let entryTime = backgroundEntryTime else { return }

        let timeInBackground = Date().timeIntervalSince(entryTime)

        if timeInBackground >= sessionTimeout {
            Logger.debug("Session timeout reached after \(timeInBackground)s in background")
            // Don't actually cancel - let it persist for recovery
            // The session is auto-saved via SessionViewModel's autosave
        }
    }

    /// Cancel all scheduled notifications
    private func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["workout-timeout-warning"]
        )
    }

    /// Request notification permission
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.error(error, context: "Failed to request notification permission")
            }
            Logger.debug("Notification permission granted: \(granted)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}
