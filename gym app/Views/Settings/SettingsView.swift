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
            Form {
                // Units Section
                Section("Units") {
                    Picker("Weight", selection: $appState.weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Picker("Distance", selection: $appState.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                // Timer Section
                Section("Timer Defaults") {
                    Picker("Default Rest Time", selection: $appState.defaultRestTime) {
                        Text("30 seconds").tag(30)
                        Text("60 seconds").tag(60)
                        Text("90 seconds").tag(90)
                        Text("2 minutes").tag(120)
                        Text("3 minutes").tag(180)
                        Text("4 minutes").tag(240)
                        Text("5 minutes").tag(300)
                    }
                }

                // Sync Section
                Section {
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(.secondary)
                        Text("Local Only")
                            .foregroundStyle(.secondary)
                    }

                    if let lastSync = appState.lastSyncDate {
                        LabeledContent("Last Sync", value: formatDate(lastSync))
                    }

                    Button {
                        Task {
                            await appState.triggerSync()
                        }
                    } label: {
                        HStack {
                            Text("Sync Now")
                            Spacer()
                            if appState.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(true) // Disabled until Firebase is set up
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    Text("Cloud sync coming soon. Your data is currently stored locally on this device.")
                }

                // Data Section
                Section("Data") {
                    NavigationLink {
                        DataStatsView()
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }

                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                }

                // About Section
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "MVP")

                    Button {
                        showingAbout = true
                    } label: {
                        Text("About Gym App")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Data Stats View

struct DataStatsView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @EnvironmentObject var workoutViewModel: WorkoutViewModel

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Total Sessions", value: "\(sessionViewModel.sessions.count)")
                LabeledContent("Total Workouts", value: "\(workoutViewModel.workouts.count)")
                LabeledContent("Total Modules", value: "\(moduleViewModel.modules.count)")
            }

            Section("This Week") {
                let thisWeekSessions = sessionsThisWeek
                LabeledContent("Sessions", value: "\(thisWeekSessions.count)")
                LabeledContent("Total Sets", value: "\(totalSets(in: thisWeekSessions))")
                LabeledContent("Total Volume", value: "\(Int(totalVolume(in: thisWeekSessions))) lbs")
            }

            Section("This Month") {
                let thisMonthSessions = sessionsThisMonth
                LabeledContent("Sessions", value: "\(thisMonthSessions.count)")
                LabeledContent("Total Sets", value: "\(totalSets(in: thisMonthSessions))")
                LabeledContent("Total Volume", value: "\(Int(totalVolume(in: thisMonthSessions))) lbs")
            }

            Section("All Time") {
                LabeledContent("Total Sets", value: "\(totalSets(in: sessionViewModel.sessions))")
                LabeledContent("Total Volume", value: "\(Int(totalVolume(in: sessionViewModel.sessions))) lbs")

                if let firstSession = sessionViewModel.sessions.last {
                    LabeledContent("First Session", value: firstSession.formattedDate)
                }
            }
        }
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

// MARK: - Export Data View

struct ExportDataView: View {
    var body: some View {
        List {
            Section {
                Text("Export functionality coming in a future update.")
                    .foregroundStyle(.secondary)
            } footer: {
                Text("You'll be able to export your workout data to CSV or PDF format.")
            }
        }
        .navigationTitle("Export Data")
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // App Info
                    VStack(spacing: 8) {
                        Text("Gym App")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Version 1.0.0 (MVP)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A modular gym tracking app designed for flexible workout composition.")
                            .multilineTextAlignment(.center)

                        Divider()

                        Text("Features")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "square.stack.3d.up", text: "Modular workout design")
                            FeatureRow(icon: "clock", text: "Built-in rest timer")
                            FeatureRow(icon: "icloud", text: "Cloud sync")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
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
