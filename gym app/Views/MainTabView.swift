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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Real pop-to-root: each tab's NavigationStack binds one of these paths,
    // so re-tapping the active tab pops its stack without destroying and
    // rebuilding the subtree (or losing scroll/view state).
    @State private var homePath = NavigationPath()
    @State private var trainingPath = NavigationPath()
    @State private var socialPath = NavigationPath()
    @State private var analyticsPath = NavigationPath()

    private let tabCount = 4

    private let tabs: [(title: String, icon: String, tag: Int)] = [
        ("Home", "house.fill", 0),
        ("Training", "dumbbell.fill", 1),
        ("Social", "person.2.fill", 2),
        ("Analytics", "chart.line.uptrend.xyaxis", 3)
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
                HomeView(path: $homePath)
                    .tag(0)

                WorkoutBuilderView(path: $trainingPath)
                    .tag(1)

                SocialView(path: $socialPath)
                    .tag(2)

                AnalyticsView(path: $analyticsPath)
                    .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                // Custom tab bar - hide when requested (e.g., in chat view)
                if !hideTabBar {
                    VStack(spacing: 0) {
                        if sessionViewModel.undoToastMessage != nil {
                            UndoToast(
                                message: sessionViewModel.undoToastMessage ?? "",
                                onUndo: { sessionViewModel.undoDelete() }
                            )
                            .padding(.bottom, AppSpacing.xs)
                        }

                        if showMiniBar {
                            MiniSessionBar(sessionViewModel: sessionViewModel) {
                                withAnimation(AppMotion.interactiveSpring) {
                                    showingFullSession = true
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        customTabBar
                    }
                    .animation(AppAnimation.standard, value: sessionViewModel.undoToastMessage != nil)
                }
            }
            .environment(\.hideTabBar, $hideTabBar)

            // Sync error banner overlay (top)
            if let syncError = appState.syncError {
                SyncErrorBanner(
                    errorInfo: syncError,
                    onDismiss: {
                        withAnimation(AppMotion.stateChange) {
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
        .transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
            }
        }
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
                            withAnimation(AppMotion.stateChange) {
                                selectedTab = tab.tag
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedTab == tab.tag ? AppColors.dominant : AppColors.textTertiary)

                            Text(tab.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(selectedTab == tab.tag ? AppColors.textPrimary : AppColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppSpacing.minTouchTarget)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(tab.title)
                }
            }
            .padding(.horizontal, AppSpacing.sm)

        }
        .background(
            AppColors.background
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Custom Tab Bar Height

    /// Height of `customTabBar`, including the 44pt icon-and-label touch target.
    static let tabBarHeight: CGFloat = 52

    // MARK: - Pop to Root

    private func popToRoot(tab: Int) {
        switch tab {
        case 0: homePath.removeLast(homePath.count)
        case 1: trainingPath.removeLast(trainingPath.count)
        case 2: socialPath.removeLast(socialPath.count)
        case 3: analyticsPath.removeLast(analyticsPath.count)
        default: break
        }
    }

}

// MARK: - Tab Bar Bottom Padding

extension View {
    /// Bottom padding sized to clear `MainTabView`'s custom tab bar, so a tab
    /// screen's last scrollable item isn't flush against it. Pass `extra` for
    /// screens that also need to clear something above the tab bar (e.g.
    /// SocialView's floating compose button).
    func tabBarBottomPadding(extra: CGFloat = 0) -> some View {
        self.padding(.bottom, MainTabView.tabBarHeight + extra)
    }
}

// MARK: - Mini Session Bar

struct MiniSessionBar: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    let onTap: () -> Void

    private var elapsedTimeString: String {
        let minutes = sessionViewModel.sessionElapsedSeconds / 60
        let seconds = sessionViewModel.sessionElapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .fixedSize()

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
        .buttonStyle(.pressable)
    }
}

// Pulse animation modifier
private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && !reduceMotion ? 1.2 : 1.0)
            .opacity(isPulsing && !reduceMotion ? 0.75 : 1.0)
            .animation(
                reduceMotion ? nil : AppMotion.stateChange.repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = !reduceMotion
            }
    }
}

#Preview {
    MainTabView()
}
