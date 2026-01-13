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
    @State private var showingWorkoutPicker = false
    @State private var selectedWorkout: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Active Session Banner
                    if sessionViewModel.isSessionActive {
                        activeSessionBanner
                    }

                    // Quick Start Section
                    quickStartSection

                    // Stats Summary
                    statsSummarySection

                    // Recent Sessions
                    if !sessionViewModel.sessions.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Gym App")
            .sheet(isPresented: $showingWorkoutPicker) {
                WorkoutPickerSheet(
                    workouts: workoutViewModel.workouts,
                    modules: moduleViewModel.modules,
                    onSelect: { workout in
                        selectedWorkout = workout
                        showingWorkoutPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startWorkout(workout)
                        }
                    }
                )
            }
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
            HStack(spacing: AppSpacing.md) {
                // Pulsing indicator
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(AppColors.success.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Session in Progress")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    if let session = sessionViewModel.currentSession {
                        Text(session.workoutName)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(AppColors.success)

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.success.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Start Section

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Quick Start")

            if workoutViewModel.workouts.isEmpty {
                emptyWorkoutsCard
            } else {
                // Main start button
                Button(action: { showingWorkoutPicker = true }) {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppGradients.accentGradient)
                                .frame(width: 56, height: 56)

                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .glowShadow()

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Start Workout")
                                .font(.title3.bold())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Choose from \(workoutViewModel.workouts.count) templates")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .fill(AppGradients.subtleGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.large)
                                    .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Quick access cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(workoutViewModel.workouts.prefix(4)) { workout in
                            QuickStartCard(workout: workout, modules: moduleViewModel.modules) {
                                startWorkout(workout)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyWorkoutsCard: some View {
        NavigationLink(destination: WorkoutFormView(workout: nil)) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundColor(AppColors.accentBlue)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Create your first workout")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Combine modules into a routine")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundColor(AppColors.border)
                    )
            )
        }
    }

    // MARK: - Stats Summary Section

    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "This Week")

            HStack(spacing: AppSpacing.md) {
                StatCard(
                    title: "Workouts",
                    value: "\(sessionsThisWeek)",
                    icon: "flame.fill",
                    color: AppColors.warning
                )

                StatCard(
                    title: "Sets",
                    value: "\(setsThisWeek)",
                    icon: "square.stack.fill",
                    color: AppColors.accentBlue
                )

                StatCard(
                    title: "Volume",
                    value: formatVolume(volumeThisWeek),
                    icon: "scalemass.fill",
                    color: AppColors.accentTeal
                )
            }
        }
    }

    // MARK: - Recent Sessions Section

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Recent Activity") {
                // Navigate to history
            }

            VStack(spacing: 0) {
                ForEach(Array(sessionViewModel.getRecentSessions(limit: 5).enumerated()), id: \.element.id) { index, session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        HomeSessionRow(session: session)
                    }
                    .buttonStyle(.plain)

                    if index < min(sessionViewModel.sessions.count - 1, 4) {
                        Divider()
                            .background(AppColors.border)
                            .padding(.leading, 48)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )
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

// MARK: - Quick Start Card

struct QuickStartCard: View {
    let workout: Workout
    let modules: [Module]
    let action: () -> Void

    private var workoutModules: [Module] {
        workout.moduleReferences.compactMap { ref in
            modules.first { $0.id == ref.moduleId }
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                // Module indicators
                HStack(spacing: AppSpacing.xs) {
                    ForEach(workoutModules.prefix(3)) { module in
                        Circle()
                            .fill(AppColors.moduleColor(module.type))
                            .frame(width: 8, height: 8)
                    }
                    if workoutModules.count > 3 {
                        Text("+\(workoutModules.count - 3)")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer()

                HStack {
                    if let duration = workout.estimatedDuration {
                        Text("\(duration)m")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .padding(AppSpacing.md)
            .frame(width: 140, height: 100)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home Session Row

struct HomeSessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Date indicator
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accentBlue)
                Text(dayNumber)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(session.workoutName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(session.completedModules.count) modules • \(session.totalSetsCompleted) sets")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: session.date)
    }
}

// MARK: - Workout Picker Sheet

struct WorkoutPickerSheet: View {
    let workouts: [Workout]
    let modules: [Module]
    let onSelect: (Workout) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    ForEach(workouts) { workout in
                        WorkoutPickerCard(workout: workout, modules: modules) {
                            onSelect(workout)
                        }
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Choose Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct WorkoutPickerCard: View {
    let workout: Workout
    let modules: [Module]
    let action: () -> Void

    private var workoutModules: [Module] {
        workout.moduleReferences.compactMap { ref in
            modules.first { $0.id == ref.moduleId }
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accentBlue)
                }

                if !workoutModules.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(workoutModules) { module in
                                ModulePill(module: module)
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
        .environmentObject(AppState.shared.moduleViewModel)
        .environmentObject(AppState.shared.workoutViewModel)
        .environmentObject(AppState.shared.sessionViewModel)
}
