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

    @State private var selectedCalendarDate: Date = Date()
    @State private var dayToSchedule: IdentifiableDate?
    @State private var showingTodayWorkoutDetail = false
    @State private var showingQuickSchedule = false

    // Session recovery state
    @State private var showingRecoveryAlert = false
    @State private var recoverableSession: Session?
    @State private var recoveryInfo: (workoutName: String, startTime: Date, lastUpdated: Date)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Today's Workout Bar
                    todayWorkoutBar

                    // Week Calendar
                    weekCalendarSection

                    // Week in Review
                    weekInReviewSection

                    // Best Performances (TODO)
                    bestPerformancesSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Gym App")
            .sheet(item: $dayToSchedule) { identifiableDate in
                let date = identifiableDate.date
                ScheduleWorkoutSheet(
                    date: date,
                    workouts: workoutViewModel.workouts,
                    modules: moduleViewModel.modules,
                    scheduledWorkouts: workoutViewModel.getScheduledWorkouts(for: date),
                    sessions: sessionsForDate(date),
                    onSchedule: { workout in
                        workoutViewModel.scheduleWorkout(workout, for: date)
                    },
                    onScheduleRest: {
                        workoutViewModel.scheduleRestDay(for: date)
                    },
                    onUnschedule: { scheduled in
                        workoutViewModel.unscheduleWorkout(scheduled)
                    },
                    onStartWorkout: { workout in
                        dayToSchedule = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startWorkout(workout)
                        }
                    },
                    onDeleteSession: { session in
                        sessionViewModel.deleteSession(session)
                    }
                )
            }
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
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.success)

                    Spacer()

                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.success)
                }

                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(session.workoutName)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.md) {
                            Label("\(session.completedModules.count) modules", systemImage: "square.stack.3d.up")
                            Label("\(session.totalSetsCompleted) sets", systemImage: "checkmark.circle")
                            if let duration = session.formattedDuration {
                                Label(duration, systemImage: "clock")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    // Rating badge (number + icon for accessibility)
                    if let feeling = session.overallFeeling {
                        HStack(spacing: 4) {
                            Text("\(feeling)")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Image(systemName: feelingIcon(feeling))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 52, height: 36)
                        .background(feelingColor(feeling))
                        .clipShape(Capsule())
                        .accessibilityLabel("Workout rating: \(feeling) out of 10, \(feelingDescription(feeling))")
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
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

    private func feelingColor(_ rating: Int) -> Color {
        switch rating {
        case 1...3: return AppColors.error
        case 4...5: return AppColors.warning
        case 6...7: return AppColors.accentBlue
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
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentBlue)

                Spacer()

                if scheduled.completedSessionId != nil {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.success)
                }
            }

            HStack(spacing: AppSpacing.md) {
                // Workout info - tappable
                Button {
                    showingTodayWorkoutDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(workout.name)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        // Module pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(workoutModules.prefix(4)) { module in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(AppColors.moduleColor(module.type))
                                            .frame(width: 8, height: 8)
                                        Text(module.name)
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.surfaceLight)
                                    )
                                }
                                if workoutModules.count > 4 {
                                    Text("+\(workoutModules.count - 4)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Start button
                if scheduled.completedSessionId == nil {
                    Button {
                        startWorkout(workout)
                    } label: {
                        Text("Start")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppGradients.accentGradient)
                            .clipShape(Capsule())
                    }
                    .glowShadow()
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.accentBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func restDayBar(scheduled: ScheduledWorkout) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentTeal)

                Spacer()

                Button {
                    workoutViewModel.unscheduleWorkout(scheduled)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accentTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Day")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Recovery is part of the process")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.accentTeal.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.accentTeal.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var noScheduleBar: some View {
        Button {
            showingQuickSchedule = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)

                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No workout scheduled")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        Text("Tap to schedule a workout or rest day")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
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
        .buttonStyle(.plain)
    }

    // MARK: - Week Calendar Section

    private var weekCalendarSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header with week navigation
            HStack {
                Button {
                    withAnimation {
                        selectedCalendarDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedCalendarDate) ?? selectedCalendarDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel("Previous week")

                Spacer()

                Text(weekRangeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    withAnimation {
                        selectedCalendarDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedCalendarDate) ?? selectedCalendarDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel("Next week")
            }

            // Week days
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayCell(
                        date: date,
                        isToday: Calendar.current.isDateInToday(date),
                        scheduledWorkouts: workoutViewModel.getScheduledWorkouts(for: date),
                        completedSessions: sessionsForDate(date)
                    ) {
                        dayToSchedule = IdentifiableDate(date: date)
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
            )
        }
    }

    private var weekDates: [Date] {
        workoutViewModel.getWeekDates(for: selectedCalendarDate)
    }

    private var weekRangeText: String {
        guard let firstDate = weekDates.first, let lastDate = weekDates.last else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: firstDate)
        let endStr = formatter.string(from: lastDate)
        return "\(startStr) - \(endStr)"
    }

    private func sessionsForDate(_ date: Date) -> [Session] {
        sessionViewModel.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Week in Review Section

    private var weekInReviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Week in Review")

            // Streak banner (only show if streak >= 2)
            if currentStreak >= 2 {
                HStack(spacing: AppSpacing.sm) {
                    Text("🔥")
                        .font(.title2)

                    Text("\(currentStreak) day streak!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text("Keep it going")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(LinearGradient(
                            colors: [AppColors.accentOrange.opacity(0.15), AppColors.warning.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
            }

            HStack(spacing: 0) {
                // Completed stat
                VStack(spacing: AppSpacing.xs) {
                    Text("\(sessionsThisWeek)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.success)
                        .minimumScaleFactor(0.7)

                    Text("completed")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(sessionsThisWeek) workouts completed this week")

                // Divider
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 44)

                // Scheduled stat
                VStack(spacing: AppSpacing.xs) {
                    Text("\(scheduledThisWeek)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.accentBlue)
                        .minimumScaleFactor(0.7)

                    Text("scheduled")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(scheduledThisWeek) workouts scheduled this week")

                // Divider
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 44)

                // Volume stat
                VStack(spacing: AppSpacing.xs) {
                    Text(formatVolume(volumeThisWeek))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.accentPurple)
                        .minimumScaleFactor(0.7)

                    Text("volume")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(formatVolume(volumeThisWeek)) pounds total volume this week")

                // Divider
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 44)

                // Cardio stat
                VStack(spacing: AppSpacing.xs) {
                    Text("\(cardioMinutesThisWeek)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.warning)
                        .minimumScaleFactor(0.7)

                    Text("cardio min")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(cardioMinutesThisWeek) minutes of cardio this week")
            }
            .padding(.vertical, AppSpacing.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .fill(AppColors.cardBackground)
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Best Performances Section

    private var bestPerformancesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Best Performances")

            // TODO: Show recent PRs and best performances
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.warning.opacity(0.5))

                Text("Coming soon - track your PRs and best performances")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                            .foregroundColor(AppColors.border.opacity(0.5))
                    )
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

    private var cardioMinutesThisWeek: Int {
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekSessions = sessionViewModel.sessions.filter { $0.date >= startOfWeek }

        var totalSeconds = 0
        for session in weekSessions {
            for module in session.completedModules {
                for exercise in module.completedExercises where exercise.exerciseType == .cardio {
                    for setGroup in exercise.completedSetGroups {
                        for set in setGroup.sets where set.completed {
                            totalSeconds += set.duration ?? 0
                        }
                    }
                }
            }
        }
        return totalSeconds / 60
    }

    private var scheduledThisWeek: Int {
        let weekDates = workoutViewModel.getWeekDates(for: Date())
        guard let startOfWeek = weekDates.first, let endOfWeek = weekDates.last else { return 0 }
        return workoutViewModel.scheduledWorkouts.filter { scheduled in
            !scheduled.isRestDay &&
            scheduled.completedSessionId == nil &&
            scheduled.scheduledDate >= startOfWeek &&
            scheduled.scheduledDate <= endOfWeek
        }.count
    }

    /// Calculate current workout streak (consecutive days with workouts)
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get all unique workout dates, sorted descending
        let workoutDates = Set(sessionViewModel.sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        guard !workoutDates.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        // If no workout today, check if there was one yesterday (streak still counts)
        if !workoutDates.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if !workoutDates.contains(yesterday) {
                return 0  // No workout today or yesterday = no active streak
            }
            checkDate = yesterday
        }

        // Count consecutive days backwards
        while workoutDates.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    // MARK: - Helper Functions

    private func startWorkout(_ workout: Workout) {
        let modules = workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in moduleViewModel.getModule(id: ref.moduleId) }

        sessionViewModel.startSession(workout: workout, modules: modules)
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
