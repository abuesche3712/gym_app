//
//  gym_appApp.swift
//  gym app
//
//  Created by Andrew Buescher on 1/12/26.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Mark startup began FIRST - before any other initialization
        // This detects crashes during startup
        StartupGuard.markStartupBegan()

        FirebaseApp.configure()

        // Initialize background session manager for workout persistence
        _ = BackgroundSessionManager.shared

        // Request notification permissions for workout warnings
        BackgroundSessionManager.shared.requestNotificationPermission()

        return true
    }
}

@main
struct gym_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var dataRepository = DataRepository.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Mark startup as successful once UI appears
                    StartupGuard.markStartupSucceeded()
                }
                .task {
                    // Wait for Firebase to restore auth state, then sync
                    let isAuthenticated = await authService.waitForAuthState()
                    if isAuthenticated {
                        Logger.debug("App launch: Auth restored, starting sync...")
                        await dataRepository.syncFromCloud()
                        PresenceService.shared.goOnline()
                        await ComposePostViewModel.publishScheduledPosts()
                    } else {
                        Logger.debug("App launch: Not authenticated, skipping sync")
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if authService.currentUser != nil {
                            PresenceService.shared.goOnline()
                        }
                    case .inactive, .background:
                        if authService.currentUser != nil {
                            PresenceService.shared.goOffline()
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
}

