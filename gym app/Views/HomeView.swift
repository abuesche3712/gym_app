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
    @State private var selectedCalendarDate: Date = Date()
    @State private var showingScheduleSheet = false
    @State private var dayToSchedule: Date?
    @State private var showingTodayWorkoutDetail = false
    @State private var showingQuickSchedule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Active Session Banner
                    if sessionViewModel.isSessionActive {
                        activeSessionBanner
                    }

                    // Today's Workout Bar
                    todayWorkoutBar

                    // Week Calendar
                    weekCalendarSection

                    // Recent Accomplishments
                    recentAccomplishmentsSection

                    // Best Performances (TODO)
                    bestPerformancesSection

                    // Recent Sessions
                    if !sessionViewModel.sessions.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Gym App")
            .fullScreenCover(isPresented: $showingActiveSession) {
                if sessionViewModel.isSessionActive {
                    ActiveSessionView()
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                if let date = dayToSchedule {
                    ScheduleWorkoutSheet(
                        date: date,
                        workouts: workoutViewModel.workouts,
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
                            showingScheduleSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                startWorkout(workout)
                            }
                        }
                    )
                }
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
        }
    }

    // MARK: - Today's Workout Bar

    private var todayWorkoutBar: some View {
        Group {
            if let scheduled = workoutViewModel.getTodaySchedule() {
                if scheduled.isRestDay {
                    // Rest day scheduled
                    restDayBar(scheduled: scheduled)
                } else if let workoutId = scheduled.workoutId,
                          let workout = workoutViewModel.getWorkout(id: workoutId) {
                    // Workout scheduled
                    scheduledWorkoutBar(workout: workout, scheduled: scheduled)
                } else {
                    // No schedule - show option to add
                    noScheduleBar
                }
            } else {
                // No schedule for today
                noScheduleBar
            }
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 32, height: 32)
                }

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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 32, height: 32)
                }
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
                        dayToSchedule = date
                        showingScheduleSheet = true
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

    // MARK: - Recent Accomplishments Section

    private var recentAccomplishmentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Recent Accomplishments")

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

// MARK: - Week Day Cell

struct WeekDayCell: View {
    let date: Date
    let isToday: Bool
    let scheduledWorkouts: [ScheduledWorkout]
    let completedSessions: [Session]
    let onTap: () -> Void

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var hasScheduledWorkouts: Bool {
        scheduledWorkouts.contains { !$0.isRestDay && $0.completedSessionId == nil }
    }

    private var hasRestDay: Bool {
        scheduledWorkouts.contains { $0.isRestDay }
    }

    private var hasCompleted: Bool {
        !completedSessions.isEmpty
    }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.xs) {
                Text(dayName)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isToday ? AppColors.accentBlue : AppColors.textTertiary)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(AppColors.accentBlue)
                            .frame(width: 32, height: 32)
                    }

                    Text(dayNumber)
                        .font(.subheadline.weight(isToday ? .bold : .medium))
                        .foregroundColor(isToday ? .white : (isPast ? AppColors.textTertiary : AppColors.textPrimary))
                }

                // Indicators
                HStack(spacing: 3) {
                    if hasCompleted {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 6, height: 6)
                    }
                    if hasRestDay {
                        Circle()
                            .fill(AppColors.accentTeal)
                            .frame(width: 6, height: 6)
                    }
                    if hasScheduledWorkouts {
                        let pendingCount = scheduledWorkouts.filter { !$0.isRestDay && $0.completedSessionId == nil }.count
                        ForEach(0..<min(pendingCount, 2), id: \.self) { _ in
                            Circle()
                                .fill(AppColors.accentBlue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Workout Sheet

struct ScheduleWorkoutSheet: View {
    let date: Date
    let workouts: [Workout]
    let scheduledWorkouts: [ScheduledWorkout]
    let sessions: [Session]
    let onSchedule: (Workout) -> Void
    let onScheduleRest: () -> Void
    let onUnschedule: (ScheduledWorkout) -> Void
    let onStartWorkout: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss

    private var hasRestDay: Bool {
        scheduledWorkouts.contains { $0.isRestDay }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Completed Sessions
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(AppColors.success)

                            ForEach(sessions) { session in
                                CompletedSessionRow(session: session)
                            }
                        }
                    }

                    // Scheduled Workouts
                    if !scheduledWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Scheduled", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(AppColors.accentBlue)

                            ForEach(scheduledWorkouts) { scheduled in
                                ScheduledWorkoutRow(
                                    scheduled: scheduled,
                                    isToday: isToday,
                                    onStart: {
                                        if let workout = workouts.first(where: { $0.id == scheduled.workoutId }) {
                                            onStartWorkout(workout)
                                        }
                                    },
                                    onRemove: {
                                        onUnschedule(scheduled)
                                    }
                                )
                            }
                        }
                    }

                    // Schedule New Workout
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Schedule Workout", systemImage: "plus.circle")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        if workouts.isEmpty {
                            Text("No workouts available. Create a workout first.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .padding()
                        } else {
                            ForEach(workouts) { workout in
                                Button {
                                    onSchedule(workout)
                                } label: {
                                    HStack {
                                        Text(workout.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppColors.textPrimary)

                                        Spacer()

                                        Image(systemName: "plus.circle")
                                            .foregroundColor(AppColors.accentBlue)
                                    }
                                    .padding(AppSpacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCorners.medium)
                                            .fill(AppColors.cardBackground)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Rest day option
                        if !hasRestDay {
                            Button {
                                onScheduleRest()
                            } label: {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .foregroundColor(AppColors.accentTeal)

                                    Text("Rest Day")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundColor(AppColors.accentTeal)
                                }
                                .padding(AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCorners.medium)
                                        .fill(AppColors.accentTeal.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct CompletedSessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
                .font(.title3)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(session.workoutName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                Text("\(session.totalSetsCompleted) sets • \(session.formattedDuration ?? "—")")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            if let feeling = session.overallFeeling {
                Text("\(feeling)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(feelingColor(feeling))
                    .clipShape(Circle())
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.success.opacity(0.1))
        )
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
}

struct ScheduledWorkoutRow: View {
    let scheduled: ScheduledWorkout
    let isToday: Bool
    let onStart: () -> Void
    let onRemove: () -> Void

    private var iconName: String {
        scheduled.isRestDay ? "moon.zzz.fill" : "calendar.badge.clock"
    }

    private var iconColor: Color {
        scheduled.isRestDay ? AppColors.accentTeal : AppColors.accentBlue
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(scheduled.workoutName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                if let notes = scheduled.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if isToday && !scheduled.isRestDay && !scheduled.isCompleted {
                Button(action: onStart) {
                    Text("Start")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppGradients.accentGradient)
                        .clipShape(Capsule())
                }
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(iconColor.opacity(0.1))
        )
    }
}

// MARK: - Workout Preview Sheet

struct WorkoutPreviewSheet: View {
    let workout: Workout
    let modules: [Module]
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var workoutModules: [Module] {
        workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in modules.first { $0.id == ref.moduleId } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Workout info
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if let description = workout.notes, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        HStack(spacing: AppSpacing.lg) {
                            if let duration = workout.estimatedDuration {
                                Label("\(duration) min", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }

                            Label("\(workoutModules.count) modules", systemImage: "square.stack.3d.up")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Modules list
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Modules")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        ForEach(workoutModules) { module in
                            ModulePreviewRow(module: module)
                        }
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { onStart() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ModulePreviewRow: View {
    let module: Module

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(AppColors.moduleColor(module.type))
                    .frame(width: 10, height: 10)

                Text(module.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(module.type.displayName)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            // Exercise list
            if !module.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(module.exercises.prefix(5)) { exercise in
                        HStack(spacing: AppSpacing.sm) {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text(exercise.name)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if module.exercises.count > 5 {
                        Text("+\(module.exercises.count - 5) more")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.leading, AppSpacing.md)
                    }
                }
                .padding(.leading, AppSpacing.lg)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.cardBackground)
        )
    }
}

// MARK: - Quick Schedule Today Sheet

struct QuickScheduleTodaySheet: View {
    let workouts: [Workout]
    let onScheduleWorkout: (Workout) -> Void
    let onScheduleRest: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Schedule workout
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Schedule Workout", systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        if workouts.isEmpty {
                            Text("No workouts available. Create a workout first.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .padding()
                        } else {
                            ForEach(workouts) { workout in
                                Button {
                                    onScheduleWorkout(workout)
                                } label: {
                                    HStack {
                                        Text(workout.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppColors.textPrimary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .padding(AppSpacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCorners.medium)
                                            .fill(AppColors.cardBackground)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Rest day option
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Or Take a Rest Day", systemImage: "moon.zzz.fill")
                            .font(.headline)
                            .foregroundColor(AppColors.accentTeal)

                        Button {
                            onScheduleRest()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Rest Day")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("Recovery is essential for progress")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .fill(AppColors.accentTeal.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Schedule Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
        .environmentObject(AppState.shared.moduleViewModel)
        .environmentObject(AppState.shared.workoutViewModel)
        .environmentObject(AppState.shared.sessionViewModel)
}
