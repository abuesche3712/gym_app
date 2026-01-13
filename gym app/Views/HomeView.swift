//
//  HomeView.swift
//  gym app
//
//  Home screen with quick start options
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel

    @State private var showingActiveSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Active Session Banner
                    if sessionViewModel.isSessionActive {
                        activeSessionBanner
                    }

                    // Quick Start Section
                    quickStartSection

                    // Recent Sessions
                    if !sessionViewModel.sessions.isEmpty {
                        recentSessionsSection
                    }

                    // Stats Summary
                    statsSummarySection
                }
                .padding()
            }
            .navigationTitle("Gym App")
            .fullScreenCover(isPresented: $showingActiveSession) {
                if sessionViewModel.isSessionActive {
                    ActiveSessionView()
                }
            }
        }
    }

    // MARK: - Active Session Banner

    private var activeSessionBanner: some View {
        Button {
            showingActiveSession = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session in Progress")
                        .font(.headline)
                    if let session = sessionViewModel.currentSession {
                        Text(session.workoutName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)

                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.green.opacity(0.2))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Quick Start Section

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.title2)
                .fontWeight(.bold)

            if workoutViewModel.workouts.isEmpty {
                emptyWorkoutsCard
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(workoutViewModel.workouts.prefix(4)) { workout in
                        QuickStartCard(workout: workout) {
                            startWorkout(workout)
                        }
                    }
                }
            }
        }
    }

    private var emptyWorkoutsCard: some View {
        NavigationLink(destination: WorkoutFormView(workout: nil)) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                Text("Create your first workout")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Recent Sessions Section

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink("See All") {
                    HistoryView()
                }
                .font(.subheadline)
            }

            ForEach(sessionViewModel.getRecentSessions(limit: 3)) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    RecentSessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Summary Section

    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                StatCard(
                    title: "Workouts",
                    value: "\(sessionsThisWeek)",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "Sets",
                    value: "\(setsThisWeek)",
                    icon: "number",
                    color: .blue
                )

                StatCard(
                    title: "Volume",
                    value: formatVolume(volumeThisWeek),
                    icon: "scalemass",
                    color: .green
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var sessionsThisWeek: Int {
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return sessionViewModel.sessions.filter { $0.date >= startOfWeek }.count
    }

    private var setsThisWeek: Int {
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return sessionViewModel.sessions
            .filter { $0.date >= startOfWeek }
            .reduce(0) { $0 + $1.totalSetsCompleted }
    }

    private var volumeThisWeek: Double {
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return sessionViewModel.sessions
            .filter { $0.date >= startOfWeek }
            .flatMap { $0.completedModules }
            .flatMap { $0.completedExercises }
            .reduce(0) { $0 + $1.totalVolume }
    }

    // MARK: - Helper Functions

    private func startWorkout(_ workout: Workout) {
        let modules = workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in moduleViewModel.getModule(id: ref.moduleId) }

        sessionViewModel.startSession(workout: workout, modules: modules)
        showingActiveSession = true
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - Supporting Views

struct QuickStartCard: View {
    let workout: Workout
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(workout.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let duration = workout.estimatedDuration {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct RecentSessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.workoutName)
                    .font(.headline)
                Text(session.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = session.formattedDuration {
                Text(duration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
        .environmentObject(AppState.shared.moduleViewModel)
        .environmentObject(AppState.shared.workoutViewModel)
        .environmentObject(AppState.shared.sessionViewModel)
}
