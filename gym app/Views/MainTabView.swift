//
//  MainTabView.swift
//  gym app
//
//  Main tab navigation structure
//

import SwiftUI

// Environment key for hiding the custom tab bar
struct HideTabBarKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var hideTabBar: Binding<Bool> {
        get { self[HideTabBarKey.self] }
        set { self[HideTabBarKey.self] = newValue }
    }
}

struct MainTabView: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var sessionViewModel: SessionViewModel = AppState.shared.sessionViewModel
    @State private var selectedTab = 0
    @State private var showingFullSession = false
    @State private var hideTabBar = false

    // Pop-to-root triggers - increment to signal navigation reset
    @State private var homePopToRoot = 0
    @State private var trainingPopToRoot = 0
    @State private var socialPopToRoot = 0
    @State private var analyticsPopToRoot = 0

    private let tabCount = 4

    private let tabs: [(icon: String, tag: Int)] = [
        ("house.fill", 0),
        ("dumbbell.fill", 1),
        ("person.2.fill", 2),
        ("chart.line.uptrend.xyaxis", 3)
    ]

    init() {
        // Hide the native tab bar
        UITabBar.appearance().isHidden = true
    }

    /// Show mini bar when session is active but full view is dismissed
    private var showMiniBar: Bool {
        sessionViewModel.isSessionActive && !showingFullSession
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .id("home-\(homePopToRoot)")
                    .tag(0)

                WorkoutBuilderView()
                    .id("training-\(trainingPopToRoot)")
                    .tag(1)

                SocialView()
                    .id("social-\(socialPopToRoot)")
                    .tag(2)

                AnalyticsView()
                    .id("analytics-\(analyticsPopToRoot)")
                    .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                // Custom tab bar - hide when requested (e.g., in chat view)
                if !hideTabBar {
                    customTabBar
                }
            }
            .environment(\.hideTabBar, $hideTabBar)

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
                    .padding(.bottom, 56) // Custom tab bar height
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

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(AppColors.surfaceTertiary)
                .frame(height: 1)

            // Tab buttons
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.tag) { index, tab in
                    Button {
                        if selectedTab == tab.tag {
                            // Already on this tab - pop to root
                            popToRoot(tab: tab.tag)
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab.tag
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(selectedTab == tab.tag ? AppColors.dominant : AppColors.textTertiary)

                            // Selection indicator dot
                            Circle()
                                .fill(selectedTab == tab.tag ? AppColors.dominant : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    // Vertical divider (except after last tab)
                    if index < tabs.count - 1 {
                        Rectangle()
                            .fill(AppColors.surfaceTertiary)
                            .frame(width: 1, height: 24)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // Mini bar spacer when active
            if showMiniBar {
                Color.clear.frame(height: 60)
            }
        }
        .background(
            ZStack {
                AppColors.background

                // Subtle texture overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.clear,
                        Color.white.opacity(0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle noise-like speckle effect
                Canvas { context, size in
                    for _ in 0..<80 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let opacity = Double.random(in: 0.02...0.05)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Pop to Root

    private func popToRoot(tab: Int) {
        switch tab {
        case 0: homePopToRoot += 1
        case 1: trainingPopToRoot += 1
        case 2: socialPopToRoot += 1
        case 3: analyticsPopToRoot += 1
        default: break
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
