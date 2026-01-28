//
//  ActivateProgramSheet.swift
//  gym app
//
//  Sheet for activating a program with start date selection
//

import SwiftUI

struct ActivateProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel

    let program: Program

    @State private var startDate = Date()
    @State private var showingWarning = false

    private var hasActiveProgram: Bool {
        if let active = programViewModel.activeProgram {
            return active.id != program.id
        }
        return false
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: program.durationWeeks, to: startDate) ?? startDate
    }

    private var scheduledWorkoutsPreview: [ScheduledWorkout] {
        var tempProgram = program
        tempProgram.startDate = startDate
        return Array(tempProgram.generateScheduledWorkouts(from: startDate).prefix(7))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                } header: {
                    Text("Choose Start Date")
                } footer: {
                    Text("Program will run from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                }

                Section {
                    ForEach(scheduledWorkoutsPreview) { scheduled in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scheduled.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                Text(dayOfWeekString(scheduled.scheduledDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if scheduled.isRestDay {
                                Text("Rest")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(scheduled.workoutName)
                                    .font(.subheadline)
                            }
                        }
                    }

                    if scheduledWorkoutsPreview.count < program.generateScheduledWorkouts(from: startDate).count {
                        HStack {
                            Spacer()
                            Text("+ more workouts...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("First Week Preview")
                }

                if hasActiveProgram {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.warning)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Another program is active")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Activating this program will deactivate \"\(programViewModel.activeProgram?.name ?? "the current program")\".")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        summaryRow(icon: "calendar", title: "Duration", value: "\(program.durationWeeks) weeks")
                        summaryRow(icon: "figure.run", title: "Workouts", value: "\(program.workoutSlots.count) per cycle")
                        summaryRow(icon: "repeat", title: "Weekly slots", value: "\(program.workoutSlots.filter { $0.scheduleType == .weekly }.count)")
                    }
                } header: {
                    Text("Program Summary")
                }
            }
            .navigationTitle("Activate Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Activate") {
                        activateProgram()
                    }
                }
            }
        }
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }

    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func activateProgram() {
        programViewModel.activateProgram(program, startDate: startDate)
        dismiss()
    }
}

#Preview {
    var program = Program(name: "8-Week Strength", durationWeeks: 8)
    program.addSlot(ProgramWorkoutSlot(
        workoutId: UUID(),
        workoutName: "Upper Body A",
        scheduleType: .weekly,
        dayOfWeek: 1
    ))
    program.addSlot(ProgramWorkoutSlot(
        workoutId: UUID(),
        workoutName: "Lower Body A",
        scheduleType: .weekly,
        dayOfWeek: 3
    ))
    program.addSlot(ProgramWorkoutSlot(
        workoutId: UUID(),
        workoutName: "Upper Body B",
        scheduleType: .weekly,
        dayOfWeek: 5
    ))

    return ActivateProgramSheet(program: program)
}
