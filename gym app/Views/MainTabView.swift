//
//  MainTabView.swift
//  gym app
//
//  Main tab navigation structure
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            WorkoutsListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(1)

            ModulesListView()
                .tabItem {
                    Label("Modules", systemImage: "square.stack.3d.up")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .environmentObject(appState)
        .environmentObject(appState.moduleViewModel)
        .environmentObject(appState.workoutViewModel)
        .environmentObject(appState.sessionViewModel)
    }
}

#Preview {
    MainTabView()
}
