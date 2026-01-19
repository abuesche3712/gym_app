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
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                WorkoutBuilderView()
                    .tabItem {
                        Label("Builder", systemImage: "hammer.fill")
                    }
                    .tag(1)

                SocialView()
                    .tabItem {
                        Label("Social", systemImage: "person.2.fill")
                    }
                    .tag(2)

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(3)

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(4)
            }
            .tint(AppColors.accentBlue)

            // Sync error banner overlay
            if let syncError = appState.syncError {
                SyncErrorBanner(
                    errorInfo: syncError,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.dismissSyncError()
                        }
                    },
                    onRetry: {
                        Task {
                            await appState.retrySyncAfterError()
                        }
                    }
                )
                .padding(.top, 50) // Below safe area
            }
        }
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
