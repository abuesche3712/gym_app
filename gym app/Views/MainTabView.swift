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
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ProgramsListView()
                .tabItem {
                    Label("Programs", systemImage: "calendar.badge.plus")
                }
                .tag(1)

            WorkoutsListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(2)

            ModulesListView()
                .tabItem {
                    Label("Modules", systemImage: "square.stack.3d.up.fill")
                }
                .tag(3)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(AppColors.accentBlue)
        .environmentObject(appState)
        .environmentObject(appState.moduleViewModel)
        .environmentObject(appState.workoutViewModel)
        .environmentObject(appState.sessionViewModel)
        .environmentObject(appState.programViewModel)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
