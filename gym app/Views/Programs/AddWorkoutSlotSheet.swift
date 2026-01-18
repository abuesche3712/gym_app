//
//  AddWorkoutSlotSheet.swift
//  gym app
//
//  Sheet for adding a workout to a program slot
//

import SwiftUI

struct AddWorkoutSlotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @EnvironmentObject private var programViewModel: ProgramViewModel

    let program: Program
    let dayOfWeek: Int

    @State private var selectedWorkout: Workout?
    @State private var scheduleType: SlotScheduleType = .weekly
    @State private var specificWeek: Int = 1

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var availableWorkouts: [Workout] {
        workoutViewModel.workouts.filter { !$0.archived }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(dayNames[dayOfWeek])
                        .font(.headline)
                } header: {
                    Text("Selected Day")
                }

                Section {
                    Picker("Schedule Type", selection: $scheduleType) {
                        Text("Every Week").tag(SlotScheduleType.weekly)
                        Text("Specific Week").tag(SlotScheduleType.specificWeek)
                    }
                    .pickerStyle(.segmented)

                    if scheduleType == .specificWeek {
                        Picker("Week Number", selection: $specificWeek) {
                            ForEach(1...program.durationWeeks, id: \.self) { week in
                                Text("Week \(week)").tag(week)
                            }
                        }
                    }
                } header: {
                    Text("Schedule Type")
                } footer: {
                    if scheduleType == .weekly {
                        Text("This workout will be scheduled every \(dayNames[dayOfWeek]) for the program duration.")
                    } else {
                        Text("This workout will only be scheduled on \(dayNames[dayOfWeek]) of week \(specificWeek).")
                    }
                }

                Section {
                    if availableWorkouts.isEmpty {
                        Text("No workouts available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableWorkouts) { workout in
                            WorkoutSelectionRow(
                                workout: workout,
                                isSelected: selectedWorkout?.id == workout.id,
                                onTap: {
                                    selectedWorkout = workout
                                }
                            )
                        }
                    }
                } header: {
                    Text("Select Workout")
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSlot()
                    }
                    .disabled(selectedWorkout == nil)
                }
            }
        }
    }

    private func addSlot() {
        guard let workout = selectedWorkout else { return }

        programViewModel.addWorkoutSlot(
            to: program,
            workoutId: workout.id,
            workoutName: workout.name,
            dayOfWeek: dayOfWeek,
            scheduleType: scheduleType,
            weekNumber: scheduleType == .specificWeek ? specificWeek : nil
        )

        // If program is active, update the schedule to include the new slot
        if program.isActive {
            // Reload to get the updated program with the new slot
            if let updatedProgram = programViewModel.programs.first(where: { $0.id == program.id }) {
                programViewModel.updateActiveProgramSchedule(updatedProgram)
            }
        }

        dismiss()
    }
}

// MARK: - Workout Selection Row

struct WorkoutSelectionRow: View {
    let workout: Workout
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text("\(workout.moduleReferences.count) modules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : nil)
    }
}

#Preview {
    AddWorkoutSlotSheet(
        program: Program(name: "Test", durationWeeks: 8),
        dayOfWeek: 1
    )
}
