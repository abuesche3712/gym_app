//
//  SettingsView.swift
//  gym app
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
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

                    // Sync Section
                    SettingsSection(title: "Cloud Sync", footer: "Cloud sync coming soon. Your data is stored locally.") {
                        SettingsRow(icon: "icloud", title: "Sync Status") {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "icloud.slash")
                                    .foregroundColor(AppColors.textTertiary)
                                Text("Local Only")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .font(.subheadline)
                        }

                        Button {
                            Task {
                                await appState.triggerSync()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(width: 28)
                                Text("Sync Now")
                                    .foregroundColor(AppColors.textTertiary)
                                Spacer()
                            }
                        }
                        .disabled(true)
                        .padding(.vertical, AppSpacing.sm)
                    }

                    // Data Section
                    SettingsSection(title: "Data") {
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
