//
//  ProgramsListView.swift
//  gym app
//
//  Monthly calendar view for training programs
//

import SwiftUI

struct ProgramsListView: View {
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @State private var showingCreateSheet = false
    @State private var showingProgramsSheet = false
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var showingDayDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Active Program Header
                    activeProgramHeader

                    // Monthly Calendar
                    monthlyCalendarSection

                    // Program List (collapsed)
                    programListSection
                }
                .padding()
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateProgramSheet()
            }
            .sheet(isPresented: $showingProgramsSheet) {
                ProgramsManagementSheet()
            }
            .sheet(isPresented: $showingDayDetail) {
                if let date = selectedDate {
                    DayDetailSheet(date: date, scheduledWorkouts: workoutViewModel.getScheduledWorkouts(for: date))
                }
            }
        }
    }

    // MARK: - Active Program Header

    private var activeProgramHeader: some View {
        Group {
            if let activeProgram = programViewModel.activeProgram {
                NavigationLink(value: activeProgram) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active Program")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }

                                Text(activeProgram.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let startDate = activeProgram.startDate {
                            let progress = programProgress(startDate: startDate, durationWeeks: activeProgram.durationWeeks)
                            let currentWeek = Int(progress * Double(activeProgram.durationWeeks)) + 1

                            HStack {
                                Text("Week \(min(currentWeek, activeProgram.durationWeeks)) of \(activeProgram.durationWeeks)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(activeProgram.workoutSlots.filter { $0.scheduleType == .weekly }.count) workouts/week")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(.green)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else {
                noActiveProgramCard
            }
        }
        .navigationDestination(for: Program.self) { program in
            ProgramDetailView(program: program)
        }
    }

    private var noActiveProgramCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Active Program")
                .font(.headline)

            Text("Create or activate a program to auto-schedule your workouts")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if programViewModel.programs.isEmpty {
                Button {
                    showingCreateSheet = true
                } label: {
                    Text("Create Program")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            } else {
                Button {
                    showingProgramsSheet = true
                } label: {
                    Text("Choose Program")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
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
                        .font(.title3)
                }

                Spacer()

                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)

                Spacer()

                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 8)

            // Day Headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
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
                            showingDayDetail = true
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
                    .font(.headline)

                Spacer()

                if programViewModel.programs.count > 1 {
                    Button("Manage") {
                        showingProgramsSheet = true
                    }
                    .font(.subheadline)
                }
            }

            if programViewModel.programs.isEmpty {
                Text("No programs yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(programViewModel.programs) { program in
                    NavigationLink(value: program) {
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
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayTextColor)

                // Workout indicators
                if !scheduledWorkouts.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(scheduledWorkouts.prefix(3)) { scheduled in
                            Circle()
                                .fill(scheduled.isRestDay ? Color.gray : (scheduled.isFromProgram ? Color.green : Color.accentColor))
                                .frame(width: 4, height: 4)
                        }
                        if scheduledWorkouts.count > 3 {
                            Text("+")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(isToday ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .opacity(isCurrentMonth ? 1 : 0.3)
        }
        .buttonStyle(.plain)
    }

    private var dayTextColor: Color {
        if isToday {
            return .accentColor
        }
        return isCurrentMonth ? .primary : .secondary
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .cornerRadius(3)
                    }
                }

                Text("\(program.durationWeeks) weeks • \(program.workoutSlots.count) slots")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Programs Management Sheet

struct ProgramsManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(programViewModel.programs) { program in
                    NavigationLink(value: program) {
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
            .navigationDestination(for: Program.self) { program in
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
                    .font(.headline)

                if isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label("\(program.durationWeeks) weeks", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(program.workoutSlots.count) slots", systemImage: "figure.run")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let description = program.programDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    var body: some View {
        NavigationStack {
            List {
                if scheduledWorkouts.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Rest Day")
                                    .font(.headline)
                                Text("No workouts scheduled")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                                        .foregroundColor(.secondary)
                                    Text("Rest Day")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scheduled.workoutName)
                                            .font(.headline)

                                        if scheduled.isFromProgram {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .font(.caption)
                                                Text("From Program")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.green)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
    ProgramsListView()
}
