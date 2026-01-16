//
//  SettingsView.swift
//  gym app
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var dataRepository = DataRepository.shared
    @State private var showingAbout = false
    @State private var showingSignIn = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Account Section
                    accountSection

                    // Units Section
                    SettingsSection(title: "Units") {
                        SettingsRow(icon: "scalemass", title: "Weight") {
                            Picker("Weight", selection: $appState.weightUnit) {
                                ForEach(WeightUnit.allCases, id: \.self) { unit in
                                    Text(unit.abbreviation).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        SettingsRow(icon: "ruler", title: "Distance") {
                            Picker("Distance", selection: $appState.distanceUnit) {
                                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                    Text(unit.abbreviation).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }

                    // Timer Section
                    SettingsSection(title: "Timer") {
                        SettingsRow(icon: "timer", title: "Default Rest") {
                            CompactTimePicker(totalSeconds: $appState.defaultRestTime, maxMinutes: 5)
                        }
                    }

                    // Cloud Sync Section (only show when signed in)
                    if authService.isAuthenticated {
                        cloudSyncSection
                    }

                    // Data Section
                    SettingsSection(title: "Data") {
                        NavigationLink {
                            ExerciseLibraryView()
                        } label: {
                            SettingsRowLabel(icon: "dumbbell.fill", title: "Exercise Library")
                        }

                        NavigationLink {
                            EquipmentLibraryView()
                        } label: {
                            SettingsRowLabel(icon: "wrench.and.screwdriver.fill", title: "Equipment Library")
                        }

                        NavigationLink {
                            DataStatsView()
                        } label: {
                            SettingsRowLabel(icon: "chart.bar", title: "Statistics")
                        }

                        NavigationLink {
                            ExportDataView()
                        } label: {
                            SettingsRowLabel(icon: "square.and.arrow.up", title: "Export Data")
                        }
                    }

                    // About Section
                    SettingsSection(title: "About") {
                        SettingsRow(icon: "info.circle", title: "Version") {
                            Text("1.0.0 MVP")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Button {
                            showingAbout = true
                        } label: {
                            SettingsRowLabel(icon: "questionmark.circle", title: "About Gym App")
                        }
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        try? await authService.deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all cloud data. Local data will remain on this device. This cannot be undone.")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            if authService.isAuthenticated {
                // Signed in state
                SettingsRow(icon: "person.circle.fill", title: "Signed In") {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let user = authService.currentUser {
                            Text(user.displayName ?? user.email ?? "Apple ID")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Text("via Apple")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Button(role: .destructive) {
                    try? authService.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(width: 28)
                        Text("Sign Out")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, AppSpacing.sm)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 28)
                        Text("Delete Account")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            } else {
                // Not signed in state
                SettingsRow(icon: "person.circle", title: "Not Signed In") {
                    Text("Local Only")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Button {
                    showingSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .frame(width: 28)
                        Text("Sign in with Apple")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    // MARK: - Cloud Sync Section

    private var cloudSyncSection: some View {
        SettingsSection(title: "Cloud Sync", footer: "Data syncs automatically when connected to the internet.") {
            SettingsRow(icon: "icloud.fill", title: "Sync Status") {
                HStack(spacing: AppSpacing.sm) {
                    if dataRepository.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing...")
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Image(systemName: "checkmark.icloud")
                            .foregroundColor(.green)
                        Text("Up to date")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .font(.subheadline)
            }

            Button {
                Task {
                    await dataRepository.syncFromCloud()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 28)
                    Text("Sync Now")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
            }
            .disabled(dataRepository.isSyncing)
            .padding(.vertical, AppSpacing.sm)

            Button {
                Task {
                    await dataRepository.pushAllToCloud()
                }
            } label: {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 28)
                    Text("Push All to Cloud")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
            }
            .disabled(dataRepository.isSyncing)
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
                .padding(.leading, AppSpacing.xs)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )

            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.leading, AppSpacing.xs)
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: Content

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            trailing
        }
        .padding(.vertical, AppSpacing.md)
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - Data Stats View

struct DataStatsView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @EnvironmentObject var workoutViewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Overview
                StatsSection(title: "Overview") {
                    StatsRow(label: "Total Sessions", value: "\(sessionViewModel.sessions.count)")
                    StatsRow(label: "Total Workouts", value: "\(workoutViewModel.workouts.count)")
                    StatsRow(label: "Total Modules", value: "\(moduleViewModel.modules.count)")
                }

                // This Week
                StatsSection(title: "This Week") {
                    let thisWeekSessions = sessionsThisWeek
                    StatsRow(label: "Sessions", value: "\(thisWeekSessions.count)")
                    StatsRow(label: "Total Sets", value: "\(totalSets(in: thisWeekSessions))")
                    StatsRow(label: "Total Volume", value: "\(Int(totalVolume(in: thisWeekSessions))) lbs")
                }

                // This Month
                StatsSection(title: "This Month") {
                    let thisMonthSessions = sessionsThisMonth
                    StatsRow(label: "Sessions", value: "\(thisMonthSessions.count)")
                    StatsRow(label: "Total Sets", value: "\(totalSets(in: thisMonthSessions))")
                    StatsRow(label: "Total Volume", value: "\(Int(totalVolume(in: thisMonthSessions))) lbs")
                }

                // All Time
                StatsSection(title: "All Time") {
                    StatsRow(label: "Total Sets", value: "\(totalSets(in: sessionViewModel.sessions))")
                    StatsRow(label: "Total Volume", value: "\(Int(totalVolume(in: sessionViewModel.sessions))) lbs")
                    if let firstSession = sessionViewModel.sessions.last {
                        StatsRow(label: "First Session", value: firstSession.formattedDate)
                    }
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Statistics")
    }

    private var sessionsThisWeek: [Session] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return sessionViewModel.sessions.filter { $0.date >= startOfWeek }
    }

    private var sessionsThisMonth: [Session] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return sessionViewModel.sessions.filter { $0.date >= startOfMonth }
    }

    private func totalSets(in sessions: [Session]) -> Int {
        sessions.reduce(0) { $0 + $1.totalSetsCompleted }
    }

    private func totalVolume(in sessions: [Session]) -> Double {
        sessions.flatMap { $0.completedModules }
            .flatMap { $0.completedExercises }
            .reduce(0) { $0 + $1.totalVolume }
    }
}

struct StatsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                content
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )
        }
    }
}

struct StatsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.textTertiary)

                Text("Coming Soon")
                    .font(.title2.bold())
                    .foregroundColor(AppColors.textPrimary)

                Text("Export functionality will be available in a future update.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(AppSpacing.screenPadding)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Export Data")
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // App Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCorners.xl)
                            .fill(AppGradients.accentGradient)
                            .frame(width: 100, height: 100)

                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.top, AppSpacing.xl)

                    // App Info
                    VStack(spacing: AppSpacing.xs) {
                        Text("Gym App")
                            .font(.title.bold())
                            .foregroundColor(AppColors.textPrimary)

                        Text("Version 1.0.0 (MVP)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("A modular gym tracking app designed for flexible workout composition.")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Divider()
                            .background(AppColors.border)

                        Text("Features")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            FeatureRow(icon: "square.stack.3d.up", text: "Modular workout design")
                            FeatureRow(icon: "timer", text: "Built-in rest timer")
                            FeatureRow(icon: "icloud", text: "Cloud sync (coming soon)")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking")
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .fill(AppColors.cardBackground)
                    )

                    Spacer()
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accentBlue)
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 24)

            Text(text)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(AppState.shared.sessionViewModel)
        .environmentObject(AppState.shared.moduleViewModel)
        .environmentObject(AppState.shared.workoutViewModel)
}
