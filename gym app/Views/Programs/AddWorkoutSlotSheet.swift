//
//  AddWorkoutSlotSheet.swift
//  gym app
//
//  Sheet for adding a workout or module to a program slot
//

import SwiftUI

enum SlotContentType: String, CaseIterable {
    case workout = "Workout"
    case module = "Module"
}

struct AddWorkoutSlotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @EnvironmentObject private var moduleViewModel: ModuleViewModel
    @EnvironmentObject private var programViewModel: ProgramViewModel

    let program: Program
    let dayOfWeek: Int

    @State private var contentType: SlotContentType = .workout
    @State private var selectedWorkout: Workout?
    @State private var selectedModule: Module?
    @State private var scheduleType: SlotScheduleType = .weekly
    @State private var specificWeek: Int = 1

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var availableWorkouts: [Workout] {
        workoutViewModel.workouts.filter { !$0.archived }
    }

    private var availableModules: [Module] {
        moduleViewModel.modules
    }

    private var canAdd: Bool {
        switch contentType {
        case .workout:
            return selectedWorkout != nil
        case .module:
            return selectedModule != nil
        }
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

                // Content type picker
                Section {
                    Picker("Add", selection: $contentType) {
                        ForEach(SlotContentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Type")
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
                        Text("This \(contentType.rawValue.lowercased()) will be scheduled every \(dayNames[dayOfWeek]) for the program duration.")
                    } else {
                        Text("This \(contentType.rawValue.lowercased()) will only be scheduled on \(dayNames[dayOfWeek]) of week \(specificWeek).")
                    }
                }

                // Content selection based on type
                switch contentType {
                case .workout:
                    workoutSelectionSection
                case .module:
                    moduleSelectionSection
                }
            }
            .navigationTitle("Add to Schedule")
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
                    .disabled(!canAdd)
                }
            }
            .onChange(of: contentType) { _, _ in
                // Clear selections when switching types
                selectedWorkout = nil
                selectedModule = nil
            }
        }
    }

    private var workoutSelectionSection: some View {
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

    private var moduleSelectionSection: some View {
        Section {
            if availableModules.isEmpty {
                Text("No modules available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableModules) { module in
                    ModuleSelectionRow(
                        module: module,
                        isSelected: selectedModule?.id == module.id,
                        onTap: {
                            selectedModule = module
                        }
                    )
                }
            }
        } header: {
            Text("Select Module")
        }
    }

    private func addSlot() {
        switch contentType {
        case .workout:
            guard let workout = selectedWorkout else { return }
            programViewModel.addWorkoutSlot(
                to: program,
                workoutId: workout.id,
                workoutName: workout.name,
                dayOfWeek: dayOfWeek,
                scheduleType: scheduleType,
                weekNumber: scheduleType == .specificWeek ? specificWeek : nil
            )
        case .module:
            guard let module = selectedModule else { return }
            programViewModel.addModuleSlot(
                to: program,
                moduleId: module.id,
                moduleName: module.name,
                moduleType: module.type,
                dayOfWeek: dayOfWeek,
                scheduleType: scheduleType,
                weekNumber: scheduleType == .specificWeek ? specificWeek : nil
            )
        }

        // If program is active, update the schedule to include the new slot
        if program.isActive {
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
                        .foregroundColor(AppColors.programAccent)
                }
            }
        }
        .listRowBackground(isSelected ? AppColors.programAccent.opacity(0.1) : nil)
    }
}

// MARK: - Module Selection Row

struct ModuleSelectionRow: View {
    let module: Module
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                // Module type icon
                Image(systemName: module.type.icon)
                    .font(.body)
                    .foregroundColor(module.type.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(module.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Text(module.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(module.exerciseCount) exercises")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.programAccent)
                }
            }
        }
        .listRowBackground(isSelected ? AppColors.programAccent.opacity(0.1) : nil)
    }
}

#Preview {
    AddWorkoutSlotSheet(
        program: Program(name: "Test", durationWeeks: 8),
        dayOfWeek: 1
    )
}
