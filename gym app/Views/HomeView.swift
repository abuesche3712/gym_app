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

    @State private var showingTodayWorkoutDetail = false
    @State private var showingQuickSchedule = false
    @State private var showingQuickLog = false

    // Session recovery state
    @State private var showingRecoveryAlert = false
    @State private var recoverableSession: Session?
    @State private var recoveryInfo: (workoutName: String, startTime: Date, lastUpdated: Date)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Custom header
                    homeHeader

                    // Today's Workout Bar
                    todayWorkoutBar

                    adHocLogButton
                }
                .padding(AppSpacing.screenPadding)
                .tabBarBottomPadding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingTodayWorkoutDetail) {
                if let scheduled = workoutViewModel.getTodaySchedule(),
                   let workoutId = scheduled.workoutId,
                   let workout = workoutViewModel.getWorkout(id: workoutId) {
                    WorkoutPreviewSheet(
                        workout: workout,
                        modules: moduleViewModel.modules,
                        onStart: {
                            showingTodayWorkoutDetail = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                startWorkout(workout)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingQuickSchedule) {
                QuickScheduleTodaySheet(
                    workouts: workoutViewModel.workouts,
                    onScheduleWorkout: { workout in
                        workoutViewModel.scheduleWorkout(workout, for: Date())
                        showingQuickSchedule = false
                    },
                    onScheduleRest: {
                        workoutViewModel.scheduleRestDay(for: Date())
                        showingQuickSchedule = false
                    }
                )
            }
            .sheet(isPresented: $showingQuickLog) {
                QuickLogSheet()
            }
            .alert("Resume Workout?", isPresented: $showingRecoveryAlert) {
                Button("Resume") {
                    if let session = recoverableSession {
                        sessionViewModel.resumeSession(session)
                        // MainTabView will auto-show full session when isSessionActive becomes true
                    }
                }
                Button("Discard", role: .destructive) {
                    sessionViewModel.discardRecoverableSession()
                    recoverableSession = nil
                    recoveryInfo = nil
                }
            } message: {
                if let info = recoveryInfo {
                    Text("You have an unfinished '\(info.workoutName)' workout from \(formatRecoveryTime(info.startTime)). Would you like to resume?")
                } else {
                    Text("You have an unfinished workout. Would you like to resume?")
                }
            }
            .onAppear {
                checkForRecoverableSession()
            }
        }
    }

    // MARK: - Session Recovery

    private func checkForRecoverableSession() {
        // Don't show recovery if already in a session
        guard !sessionViewModel.isSessionActive else { return }

        if let session = sessionViewModel.checkForRecoverableSession() {
            recoverableSession = session
            recoveryInfo = sessionViewModel.getRecoverableSessionInfo()
            showingRecoveryAlert = true
        }
    }

    private func formatRecoveryTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Home Header

    private var homeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(formattedDate)
                    .elegantLabel(color: AppColors.dominant)
                Text("Home")
                    .displaySmall()
            }

            Spacer()

            // History button
            NavigationLink(destination: HistoryView()) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.pressable)

            // Settings button
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.pressable)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Today's Workout Bar

    private var todaysSessions: [Session] {
        sessionsForDate(Date())
    }

    private var todayWorkoutBar: some View {
        Group {
            // Priority 1: Show completed workout if done today
            if let completedSession = todaysSessions.first {
                completedTodayBar(session: completedSession)
            }
            // Priority 2: Check for scheduled items
            else if let scheduled = workoutViewModel.getTodaySchedule() {
                if scheduled.isRestDay {
                    restDayBar(scheduled: scheduled)
                } else if let workoutId = scheduled.workoutId,
                          let workout = workoutViewModel.getWorkout(id: workoutId) {
                    scheduledWorkoutBar(workout: workout, scheduled: scheduled)
                } else {
                    noScheduleBar
                }
            }
            // Priority 3: Nothing scheduled
            else {
                noScheduleBar
            }
        }
    }

    private func completedTodayBar(session: Session) -> some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Today")
                        .elegantLabel(color: AppColors.success)

                    Spacer()

                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .caption(color: AppColors.success)
                        .fontWeight(.medium)
                }

                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(session.displayName)
                            .headline()

                        HStack(spacing: AppSpacing.md) {
                            Label("\(session.completedModules.count) modules", systemImage: "square.stack.3d.up")
                            Label("\(session.totalSetsCompleted) sets", systemImage: "checkmark.circle")
                            if let duration = session.formattedDuration {
                                Label(duration, systemImage: "clock")
                            }
                        }
                        .caption()
                    }

                    Spacer()

                    // Rating badge (number + icon for accessibility)
                    if let feeling = session.overallFeeling {
                        HStack(spacing: 4) {
                            Text("\(feeling)")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Image(systemName: feelingIcon(feeling))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 52, height: 36)
                        .background(feelingColor(feeling))
                        .clipShape(Capsule())
                        .accessibilityLabel("Workout rating: \(feeling) out of 10, \(feelingDescription(feeling))")
                    }

                    Image(systemName: "chevron.right")
                        .subheadline(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.success.opacity(0.08), AppColors.success.opacity(0.03), AppColors.surfacePrimary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.success.opacity(0.3), AppColors.surfaceTertiary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(.pressable)
    }

    private func feelingColor(_ rating: Int) -> Color {
        switch rating {
        case 1...3: return AppColors.error
        case 4...5: return AppColors.warning
        case 6...7: return AppColors.dominant
        case 8...10: return AppColors.success
        default: return AppColors.textTertiary
        }
    }

    private func feelingIcon(_ rating: Int) -> String {
        switch rating {
        case 1...3: return "arrow.down"
        case 4...5: return "minus"
        case 6...7: return "arrow.up"
        case 8...10: return "star.fill"
        default: return "circle"
        }
    }

    private func feelingDescription(_ rating: Int) -> String {
        switch rating {
        case 1...3: return "tough workout"
        case 4...5: return "okay workout"
        case 6...7: return "good workout"
        case 8...10: return "great workout"
        default: return ""
        }
    }

    private func scheduledWorkoutBar(workout: Workout, scheduled: ScheduledWorkout) -> some View {
        let workoutModules = workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in moduleViewModel.getModule(id: ref.moduleId) }

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Text("Today")
                    .elegantLabel(color: AppColors.dominant)

                Spacer()

                if scheduled.completedSessionId != nil {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .caption(color: AppColors.success)
                        .fontWeight(.medium)
                }
            }

            HStack(spacing: AppSpacing.md) {
                // Workout info - tappable
                Button {
                    showingTodayWorkoutDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(workout.name)
                            .headline()
                            .lineLimit(1)

                        // Module pills
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(workoutModules.prefix(4)) { module in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(AppColors.moduleColor(module.type))
                                        .frame(width: 8, height: 8)
                                    Text(module.name)
                                        .caption()
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(AppColors.surfaceTertiary)
                                )
                            }
                            if workoutModules.count > 4 {
                                Text("+\(workoutModules.count - 4)")
                                    .caption(color: AppColors.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.pressable)

                Spacer()

                // Start button
                if scheduled.completedSessionId == nil {
                    Button {
                        startWorkout(workout, scheduledDate: scheduled.scheduledDate)
                    } label: {
                        Text("Start")
                            .subheadline()
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppGradients.dominantGradient)
                            .clipShape(Capsule())
                    }
                    .glowShadow()
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.dominant.opacity(0.06), AppColors.dominant.opacity(0.02), AppColors.surfacePrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.dominant.opacity(0.3), AppColors.surfaceTertiary.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    private func restDayBar(scheduled: ScheduledWorkout) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Today")
                    .elegantLabel(color: AppColors.accent1)

                Spacer()

                Button {
                    workoutViewModel.unscheduleWorkout(scheduled)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .body(color: AppColors.textTertiary)
                }
            }

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "moon.zzz.fill")
                    .displaySmall(color: AppColors.accent1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Day")
                        .headline()

                    Text("Recovery is part of the process")
                        .caption()
                }

                Spacer()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent1.opacity(0.08), AppColors.accent1.opacity(0.03), AppColors.surfacePrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent1.opacity(0.3), AppColors.surfaceTertiary.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    // MARK: - Ad-hoc Logging

    private var adHocLogButton: some View {
        Button {
            HapticManager.shared.tap()
            showingQuickLog = true
        } label: {
            Label("Log activity", systemImage: "plus.circle.fill")
                .headline(color: AppColors.dominant)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppSpacing.minTouchTarget)
                .background(AppColors.dominantMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        }
        .buttonStyle(.pressable)
        .accessibilityHint("Log an activity without using a workout template")
    }

    private var noScheduleBar: some View {
        Button {
            showingQuickSchedule = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Today")
                    .elegantLabel(color: AppColors.textTertiary)

                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "calendar.badge.plus")
                        .displaySmall(color: AppColors.textTertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No workout scheduled")
                            .headline()

                        Text("Tap to schedule a workout or rest day")
                            .caption()
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .subheadline(color: AppColors.textTertiary)
                        .fontWeight(.semibold)
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundColor(AppColors.surfaceTertiary)
                    )
            )
        }
        .buttonStyle(.pressable)
    }

    private func sessionsForDate(_ date: Date) -> [Session] {
        sessionViewModel.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Helper Functions

    private func startWorkout(_ workout: Workout, scheduledDate: Date = Date()) {
        // Refresh modules to ensure we have the latest data (picks up any recently added exercises)
        moduleViewModel.loadModules()

        let modules = workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in moduleViewModel.getModule(id: ref.moduleId) }

        let scheduledContext = workoutViewModel.getScheduledWorkouts(for: scheduledDate).first {
            $0.workoutId == workout.id && !$0.isRestDay && $0.completedSessionId == nil
        }

        sessionViewModel.startSession(workout: workout, modules: modules, scheduledWorkout: scheduledContext)
        // MainTabView will auto-show full session when isSessionActive becomes true
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
        .environmentObject(AppState.shared.moduleViewModel)
        .environmentObject(AppState.shared.workoutViewModel)
        .environmentObject(AppState.shared.sessionViewModel)
}
