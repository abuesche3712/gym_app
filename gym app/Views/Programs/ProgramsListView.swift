//
//  ProgramsListView.swift
//  gym app
//
//  Monthly calendar view for training programs
//

import SwiftUI

// MARK: - Date Identifiable Extension

extension Date: Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

struct ProgramsListView: View {
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateSheet = false
    @State private var showingProgramsSheet = false
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var selectedProgram: Program?

    // Selection mode support for share flow
    var selectionMode: ViewSelectionMode? = nil
    var onSelectForShare: ((Program) -> Void)? = nil

    private var isSelectionMode: Bool { selectionMode != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isSelectionMode {
                    // Simplified view for selection mode - just show program list
                    selectionModeContent
                } else {
                    // Custom header
                    programsHeader

                    // Active Program Header
                    activeProgramHeader

                    // Monthly Calendar
                    monthlyCalendarSection

                    // Program List (collapsed)
                    programListSection
                }
            }
            .padding()
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                ProgramFormView(program: nil)
            }
        }
        .sheet(isPresented: $showingProgramsSheet) {
            ProgramsManagementSheet()
        }
        .sheet(item: $selectedDate) { date in
            DayDetailSheet(
                date: date,
                scheduledWorkouts: workoutViewModel.getScheduledWorkouts(for: date),
                workouts: workoutViewModel.workouts
            )
        }
        .navigationDestination(item: $selectedProgram) { program in
            ProgramDetailView(program: program)
        }
    }

    // MARK: - Selection Mode Content

    @ViewBuilder
    private var selectionModeContent: some View {
        if programViewModel.programs.isEmpty {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.textTertiary)

                Text("No Programs")
                    .headline(color: AppColors.textPrimary)

                Text("Create a program to share it")
                    .subheadline(color: AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, AppSpacing.xxl)
        } else {
            VStack(spacing: AppSpacing.md) {
                ForEach(programViewModel.programs) { program in
                    Button {
                        onSelectForShare?(program)
                    } label: {
                        ProgramSelectionRow(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Active Program Header

    private var activeProgramHeader: some View {
        Group {
            if let activeProgram = programViewModel.activeProgram {
                Button {
                    selectedProgram = activeProgram
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(AppColors.accent2)
                                        .frame(width: 8, height: 8)
                                    Text("Active Program")
                                        .caption(color: AppColors.accent2)
                                        .fontWeight(.medium)
                                }

                                Text(activeProgram.name)
                                    .displaySmall(color: AppColors.textPrimary)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .caption(color: AppColors.textSecondary)
                        }

                        if let startDate = activeProgram.startDate {
                            let progress = programProgress(startDate: startDate, durationWeeks: activeProgram.durationWeeks)
                            let currentWeek = Int(progress * Double(activeProgram.durationWeeks)) + 1

                            HStack {
                                Text("Week \(min(currentWeek, activeProgram.durationWeeks)) of \(activeProgram.durationWeeks)")
                                    .caption(color: AppColors.textSecondary)

                                Spacer()

                                Text("\(activeProgram.workoutSlots.filter { $0.scheduleType == .weekly }.count) workouts/week")
                                    .caption(color: AppColors.textSecondary)
                            }

                            AnimatedProgressBar(
                                progress: progress,
                                gradient: AppGradients.programGradient,
                                height: 6
                            )
                        }
                    }
                    .gradientCard(accent: AppColors.accent2)
                }
                .buttonStyle(.plain)
            } else {
                noActiveProgramCard
            }
        }
    }

    private var noActiveProgramCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .displayMedium(color: AppColors.textSecondary)

            Text("No Active Program")
                .headline(color: AppColors.textPrimary)

            Text("Create or activate a program to auto-schedule your workouts")
                .caption(color: AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if programViewModel.programs.isEmpty {
                Button {
                    showingCreateSheet = true
                } label: {
                    Text("Create Program")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent2)
                .padding(.top, 4)
            } else {
                Button {
                    showingProgramsSheet = true
                } label: {
                    Text("Choose Program")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent2)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Monthly Calendar

    private var monthlyCalendarSection: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .displaySmall(color: AppColors.textPrimary)
                }

                Spacer()

                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .headline(color: AppColors.textPrimary)

                Spacer()

                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .displaySmall(color: AppColors.textPrimary)
                }
            }
            .padding(.horizontal, 8)

            // Day Headers
            HStack(spacing: 0) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar Grid
            let days = monthDays(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedMonth, toGranularity: .month),
                        scheduledWorkouts: workoutViewModel.getScheduledWorkouts(for: date),
                        isToday: Calendar.current.isDateInToday(date),
                        onTap: {
                            selectedDate = date
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Program List Section

    private var programListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Programs")
                    .headline(color: AppColors.textPrimary)

                Spacer()

                if programViewModel.programs.count > 1 {
                    Button("Manage") {
                        showingProgramsSheet = true
                    }
                    .subheadline(color: AppColors.accent1)
                }
            }

            if programViewModel.programs.isEmpty {
                Text("No programs yet")
                    .subheadline(color: AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(programViewModel.programs) { program in
                    Button {
                        selectedProgram = program
                    } label: {
                        ProgramCompactRow(program: program, isActive: program.isActive)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Header

    private var programsHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Navigation row
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .body(color: AppColors.accent2)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.accent2.opacity(0.1)))
                        .overlay(Circle().stroke(AppColors.accent2.opacity(0.2), lineWidth: 1))
                }
                Spacer()
                if !isSelectionMode {
                    Button { showingCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .body(color: AppColors.accent2)
                            .fontWeight(.semibold)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppColors.accent2.opacity(0.1)))
                            .overlay(Circle().stroke(AppColors.accent2.opacity(0.2), lineWidth: 1))
                    }
                }
            }

            // Title section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRAMS")
                        .elegantLabel(color: AppColors.accent2)
                    Text("Your Programs")
                        .displayMedium(color: AppColors.textPrimary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                    Text("\(programViewModel.programs.count) total")
                        .subheadline(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                }
            }

            // Gold accent line
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppColors.accent2.opacity(0.6), AppColors.accent2.opacity(0.1), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 2)
        }
    }

    // MARK: - Helpers

    private func programProgress(startDate: Date, durationWeeks: Int) -> Double {
        let totalDays = Double(durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }

    private func monthDays(for date: Date) -> [Date] {
        let calendar = Calendar.current

        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }

        var days: [Date] = []
        var currentDate = monthFirstWeek.start

        while currentDate < monthLastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }
}

// MARK: - Month Day Cell

struct MonthDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let scheduledWorkouts: [ScheduledWorkout]
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .subheadline(color: dayTextColor)
                    .fontWeight(isToday ? .bold : .regular)

                // Workout indicators
                if !scheduledWorkouts.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(scheduledWorkouts.prefix(3)) { scheduled in
                            Circle()
                                .fill(workoutIndicatorColor(for: scheduled))
                                .frame(width: 4, height: 4)
                        }
                        if scheduledWorkouts.count > 3 {
                            Text("+")
                                .caption2(color: AppColors.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(isToday ? AppColors.accent1.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .opacity(isCurrentMonth ? 1 : 0.3)
        }
        .buttonStyle(.plain)
    }

    private var dayTextColor: Color {
        if isToday {
            return AppColors.accent1
        }
        return isCurrentMonth ? .primary : .secondary
    }

    private func workoutIndicatorColor(for scheduled: ScheduledWorkout) -> Color {
        // Rest day
        if scheduled.isRestDay {
            return AppColors.textTertiary
        }

        // Completed workout
        if scheduled.completedSessionId != nil {
            return AppColors.success
        }

        // Scheduled workout (teal for both program and regular workouts)
        return AppColors.accent1
    }
}

// MARK: - Program Selection Row (for share flow)

struct ProgramSelectionRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(AppColors.accent2.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "doc.text.fill")
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppColors.accent2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .headline(color: AppColors.textPrimary)

                Text("\(program.durationWeeks) weeks • \(program.workoutSlots.count) slots")
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "square.and.arrow.up")
                .subheadline(color: AppColors.dominant)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Program Compact Row

struct ProgramCompactRow: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(program.name)
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.medium)

                    if isActive {
                        Text("ACTIVE")
                            .caption2(color: .white)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.accent2)
                            .cornerRadius(3)
                    }
                }

                Text("\(program.durationWeeks) weeks • \(program.workoutSlots.count) slots")
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .caption(color: AppColors.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Programs Management Sheet

struct ProgramsManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @State private var selectedProgram: Program?

    var body: some View {
        NavigationStack {
            List {
                ForEach(programViewModel.programs) { program in
                    Button {
                        selectedProgram = program
                    } label: {
                        ProgramRow(program: program, isActive: program.isActive)
                    }
                }
                .onDelete(perform: deletePrograms)
            }
            .navigationTitle("Manage Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
        }
    }

    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            programViewModel.deleteProgram(programViewModel.programs[index])
        }
    }
}

// MARK: - Program Row (kept for management sheet)

struct ProgramRow: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .headline(color: AppColors.textPrimary)

                if isActive {
                    Text("ACTIVE")
                        .caption2(color: .white)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accent2)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label("\(program.durationWeeks) weeks", systemImage: "calendar")
                    .caption(color: AppColors.textSecondary)

                Label("\(program.workoutSlots.count) slots", systemImage: "figure.run")
                    .caption(color: AppColors.textSecondary)
            }

            if let description = program.programDescription, !description.isEmpty {
                Text(description)
                    .caption(color: AppColors.textSecondary)
                    .lineLimit(1)
            }

            if isActive, let startDate = program.startDate {
                let progress = programProgress(startDate: startDate, durationWeeks: program.durationWeeks)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func programProgress(startDate: Date, durationWeeks: Int) -> Double {
        let totalDays = Double(durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let scheduledWorkouts: [ScheduledWorkout]
    let workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                if scheduledWorkouts.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "moon.zzz")
                                    .displaySmall(color: AppColors.textSecondary)
                                Text("Rest Day")
                                    .headline(color: AppColors.textPrimary)
                                Text("No workouts scheduled")
                                    .subheadline(color: AppColors.textSecondary)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    }
                } else {
                    Section {
                        ForEach(scheduledWorkouts) { scheduled in
                            if scheduled.isRestDay {
                                HStack {
                                    Image(systemName: "moon.zzz")
                                        .body(color: AppColors.textSecondary)
                                    Text("Rest Day")
                                        .body(color: AppColors.textSecondary)
                                }
                            } else if let workout = workouts.first(where: { $0.id == scheduled.workoutId }) {
                                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.name)
                                            .headline(color: AppColors.textPrimary)

                                        if scheduled.isFromProgram {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .caption(color: AppColors.accent2)
                                                Text("From Program")
                                                    .caption(color: AppColors.accent2)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            } else {
                                // Workout not found - show name only
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scheduled.workoutName)
                                            .headline(color: AppColors.textPrimary)

                                        if scheduled.isFromProgram {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .caption(color: AppColors.accent2)
                                                Text("From Program")
                                                    .caption(color: AppColors.accent2)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Scheduled Workouts")
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
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

#Preview {
    NavigationStack {
        ProgramsListView()
    }
}
