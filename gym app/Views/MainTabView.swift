//
//  MainTabView.swift
//  gym app
//
//  Main tab navigation structure
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var sessionViewModel: SessionViewModel = AppState.shared.sessionViewModel
    @State private var selectedTab = 0
    @State private var showingFullSession = false

    private let tabCount = 5

    /// Show mini bar when session is active but full view is dismissed
    private var showMiniBar: Bool {
        sessionViewModel.isSessionActive && !showingFullSession
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                    .simultaneousGesture(swipeGesture)

                WorkoutBuilderView()
                    .tabItem {
                        Label("Workout", systemImage: "dumbbell.fill")
                    }
                    .tag(1)
                    .simultaneousGesture(swipeGesture)

                SocialView()
                    .tabItem {
                        Label("Social", systemImage: "person.2.fill")
                    }
                    .tag(2)
                    .simultaneousGesture(swipeGesture)

                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(3)
                    .simultaneousGesture(swipeGesture)

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(4)
                    .simultaneousGesture(swipeGesture)
            }
            .tint(AppColors.dominant)
            .safeAreaInset(edge: .bottom) {
                // Add space for mini bar when visible
                if showMiniBar {
                    Color.clear.frame(height: 60)
                }
            }

            // Sync error banner overlay (top)
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

            // Mini session bar overlay (bottom, above tab bar)
            if showMiniBar {
                VStack {
                    Spacer()
                    MiniSessionBar(sessionViewModel: sessionViewModel) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingFullSession = true
                        }
                    }
                    .padding(.bottom, 49) // Tab bar height
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .environmentObject(appState)
        .environmentObject(appState.moduleViewModel)
        .environmentObject(appState.workoutViewModel)
        .environmentObject(appState.sessionViewModel)
        .environmentObject(appState.programViewModel)
        .preferredColorScheme(.dark)
        // Centralized full-screen session presentation
        .fullScreenCover(isPresented: $showingFullSession) {
            if sessionViewModel.isSessionActive {
                ActiveSessionView(onMinimize: {
                    showingFullSession = false
                })
                .environmentObject(appState)
                .environmentObject(appState.sessionViewModel)
                .environmentObject(appState.workoutViewModel)
                .environmentObject(appState.moduleViewModel)
                .environmentObject(appState.programViewModel)
            }
        }
        // Auto-show full session when a new session starts
        .onReceive(sessionViewModel.$isSessionActive) { isActive in
            if isActive && !showingFullSession {
                showingFullSession = true
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height

                // Only trigger on clearly horizontal swipes (2:1 ratio)
                // and require significant horizontal movement
                guard abs(horizontalAmount) > abs(verticalAmount) * 2,
                      abs(horizontalAmount) > 80 else { return }

                // Use spring animation for smooth, natural feel
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.5)) {
                    if horizontalAmount < 0 {
                        // Swipe left - go to next tab
                        selectedTab = min(selectedTab + 1, tabCount - 1)
                    } else {
                        // Swipe right - go to previous tab
                        selectedTab = max(selectedTab - 1, 0)
                    }
                }
            }
    }
}

// MARK: - Mini Session Bar

struct MiniSessionBar: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    let onTap: () -> Void

    private var elapsedTimeString: String {
        let minutes = sessionViewModel.sessionElapsedSeconds / 60
        let seconds = sessionViewModel.sessionElapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var currentExerciseName: String? {
        sessionViewModel.currentExercise?.exerciseName
    }

    private var workoutName: String {
        sessionViewModel.currentSession?.workoutName ?? "Workout"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Pulsing indicator
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())

                // Workout info
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName)
                        .subheadline(color: .white)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if let exercise = currentExerciseName {
                        Text(exercise)
                            .caption(color: .white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .caption(color: .white)
                    Text(elapsedTimeString)
                        .monoSmall(color: .white)
                }

                // Expand indicator
                Image(systemName: "chevron.up")
                    .caption(color: .white.opacity(0.6))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.dominant)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

// Pulse animation modifier
private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

#Preview {
    MainTabView()
}
