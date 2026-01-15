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
        FirebaseApp.configure()
        return true
    }
}

@main
struct gym_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var dataRepository = DataRepository.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // Sync from cloud on app launch if authenticated
                    if authService.isAuthenticated {
                        await dataRepository.syncFromCloud()
                    }
                }
        }
    }
}
