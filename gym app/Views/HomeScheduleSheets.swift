//
//  HomeScheduleSheets.swift
//  gym app
//
//  Schedule-related sheets and components - extracted from HomeView
//

import SwiftUI

// MARK: - Rest Day Jabs

private let restDayJabs = [
    "Go look at yourself in the mirror real quick",
    "Fine, take a break...",
    "The gym will be there tomorrow. But you might not",
]

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
    let modules: [Module]
    let scheduledWorkouts: [ScheduledWorkout]
    let sessions: [Session]
    let onSchedule: (Workout) -> Void
    let onScheduleRest: () -> Void
    let onUnschedule: (ScheduledWorkout) -> Void
    let onStartWorkout: (Workout) -> Void
    var onDeleteSession: ((Session) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showRestDayJab = false
    @State private var restDayJab = restDayJabs.randomElement() ?? ""

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

    private var hasCompletedSession: Bool {
        !sessions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Completed Sessions (tappable to view details)
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(AppColors.success)

                            ForEach(sessions) { session in
                                HStack(spacing: 0) {
                                    NavigationLink(destination: SessionDetailView(session: session)) {
                                        CompletedSessionRow(session: session)
                                    }
                                    .buttonStyle(.plain)

                                    if onDeleteSession != nil {
                                        Button {
                                            onDeleteSession?(session)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.error)
                                                .frame(width: 44, height: 44)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Scheduled Workouts (tappable to view workout)
                    if !scheduledWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Scheduled", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(AppColors.accentBlue)

                            ForEach(scheduledWorkouts) { scheduled in
                                if let workout = workouts.first(where: { $0.id == scheduled.workoutId }) {
                                    ScheduledWorkoutDetailRow(
                                        scheduled: scheduled,
                                        workout: workout,
                                        modules: modules,
                                        isToday: isToday,
                                        onStart: { onStartWorkout(workout) },
                                        onRemove: { onUnschedule(scheduled) }
                                    )
                                } else {
                                    ScheduledWorkoutRow(
                                        scheduled: scheduled,
                                        isToday: isToday,
                                        onStart: {},
                                        onRemove: { onUnschedule(scheduled) }
                                    )
                                }
                            }
                        }
                    }

                    // Schedule New Workout - only show if no completed sessions
                    if !hasCompletedSession {
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
                                    restDayJab = restDayJabs.randomElement() ?? ""
                                    showRestDayJab = true
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
                }
                .padding(AppSpacing.screenPadding)
            }
            .sheetBackground()
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .alert("Rest Day?", isPresented: $showRestDayJab) {
                Button("Yes, I need it") {
                    onScheduleRest()
                }
                Button("Nevermind, let's lift", role: .cancel) { }
            } message: {
                Text(restDayJab)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Completed Session Row

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

// MARK: - Scheduled Workout Row

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

// MARK: - Scheduled Workout Detail Row (with navigation to workout)

struct ScheduledWorkoutDetailRow: View {
    let scheduled: ScheduledWorkout
    let workout: Workout
    let modules: [Module]
    let isToday: Bool
    let onStart: () -> Void
    let onRemove: () -> Void

    private var workoutModules: [Module] {
        workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in modules.first { $0.id == ref.moduleId } }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content - tappable to view workout details
            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(AppColors.accentBlue)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(scheduled.workoutName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        // Module summary
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(workoutModules.prefix(3)) { module in
                                Circle()
                                    .fill(AppColors.moduleColor(module.type))
                                    .frame(width: 8, height: 8)
                            }
                            Text("\(workoutModules.count) modules")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Action buttons
            HStack(spacing: AppSpacing.md) {
                if isToday && !scheduled.isCompleted {
                    Button(action: onStart) {
                        Text("Start Workout")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppGradients.accentGradient)
                            .clipShape(Capsule())
                    }
                }

                Button(action: onRemove) {
                    Text("Remove")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: isToday && !scheduled.isCompleted ? nil : .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .padding(.horizontal, AppSpacing.md)
                        .background(
                            Capsule()
                                .fill(AppColors.surfaceLight)
                        )
                }
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.accentBlue.opacity(0.1))
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
            .sheetBackground()
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
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Module Preview Row

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
                let resolvedExercises = module.resolvedExercises()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(resolvedExercises.prefix(5))) { exercise in
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
    @State private var showRestDayJab = false
    @State private var restDayJab = restDayJabs.randomElement() ?? ""

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
                            restDayJab = restDayJabs.randomElement() ?? ""
                            showRestDayJab = true
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
            .sheetBackground()
            .navigationTitle("Schedule Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .alert("Rest Day?", isPresented: $showRestDayJab) {
                Button("Yes, I need it") {
                    onScheduleRest()
                }
                Button("Nevermind, let's lift", role: .cancel) { }
            } message: {
                Text(restDayJab)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Identifiable Date Wrapper

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}
