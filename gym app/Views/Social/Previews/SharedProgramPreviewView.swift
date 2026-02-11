//
//  SharedProgramPreviewView.swift
//  gym app
//
//  Read-only preview of a shared program from a ShareBundle
//

import SwiftUI

struct SharedProgramPreviewView: View {
    let bundle: ProgramShareBundle
    let onImport: (() -> Void)?

    init(bundle: ProgramShareBundle, onImport: (() -> Void)? = nil) {
        self.bundle = bundle
        self.onImport = onImport
    }

    private var program: Program {
        bundle.program
    }

    // Group workouts by day of week for display
    private var workoutSchedule: [(day: String, workouts: [Workout])] {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var schedule: [Int: [Workout]] = [:]

        // Process legacy workout slots
        for slot in program.workoutSlots {
            if let workout = bundle.workouts.first(where: { $0.id == slot.workoutId }),
               let dayOfWeek = slot.dayOfWeek {
                if schedule[dayOfWeek] == nil {
                    schedule[dayOfWeek] = []
                }
                schedule[dayOfWeek]?.append(workout)
            }
        }

        // Process unified slots
        for slot in program.moduleSlots {
            if case .workout(let id, _) = slot.content,
               let workout = bundle.workouts.first(where: { $0.id == id }),
               let day = slot.dayOfWeek {
                if schedule[day] == nil {
                    schedule[day] = []
                }
                schedule[day]?.append(workout)
            }
        }

        return schedule.keys.sorted().compactMap { day -> (String, [Workout])? in
            guard let workouts = schedule[day], !workouts.isEmpty else { return nil }
            return (dayNames[day], workouts)
        }
    }

    private var totalExerciseCount: Int {
        bundle.modules.reduce(0) { $0 + $1.exerciseCount }
    }

    var body: some View {
        List {
            // Program Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.title)
                            .foregroundColor(AppColors.dominant)
                            .frame(width: 60, height: 60)
                            .background(AppColors.dominant.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(program.name)
                                .font(.title3.weight(.bold))
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: AppSpacing.md) {
                                Label("\(program.durationWeeks) weeks", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)

                                Label("\(bundle.workouts.count) workouts", systemImage: "figure.run")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            if totalExerciseCount > 0 {
                                Label("\(totalExerciseCount) total exercises", systemImage: "dumbbell")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Weekly Schedule Section (simplified)
            if !workoutSchedule.isEmpty {
                Section("Weekly Schedule") {
                    ForEach(workoutSchedule, id: \.day) { dayInfo in
                        HStack {
                            Text(dayInfo.day)
                                .font(.headline.monospacedDigit())
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 40, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(dayInfo.workouts, id: \.id) { workout in
                                    Text(workout.name)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }

            // Workouts Section
            Section {
                if bundle.workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.run",
                        description: Text("This program has no workouts")
                    )
                } else {
                    ForEach(bundle.workouts) { workout in
                        NavigationLink {
                            SharedWorkoutPreviewView(
                                workout: workout,
                                modules: modulesFor(workout: workout),
                                showImportButton: false,
                                onImport: nil
                            )
                        } label: {
                            WorkoutRow(workout: workout, modules: modulesFor(workout: workout))
                        }
                    }
                }
            } header: {
                Text("Workouts (\(bundle.workouts.count))")
            }

            // Import Button Section
            if let onImport = onImport {
                Section {
                    Button {
                        onImport()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Import Program", systemImage: "square.and.arrow.down")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .listRowBackground(AppColors.dominant)
                    .foregroundColor(.white)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Program Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Helper to get modules for a specific workout
    private func modulesFor(workout: Workout) -> [Module] {
        workout.moduleReferences.compactMap { ref in
            bundle.modules.first { $0.id == ref.moduleId }
        }
    }
}

// MARK: - Workout Row

private struct WorkoutRow: View {
    let workout: Workout
    let modules: [Module]

    private var exerciseCount: Int {
        modules.reduce(0) { $0 + $1.exerciseCount }
    }

    private var estimatedDuration: Int? {
        let durations = modules.compactMap { $0.estimatedDuration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.headline)
                .foregroundColor(AppColors.dominant)
                .frame(width: 36, height: 36)
                .background(AppColors.dominant.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    Text("\(modules.count) modules")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text("·")
                        .foregroundColor(AppColors.textTertiary)

                    Text("\(exerciseCount) exercises")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    if let duration = estimatedDuration {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SharedProgramPreviewView(
            bundle: ProgramShareBundle(
                program: Program(name: "Sample Program", durationWeeks: 8),
                workouts: [],
                modules: []
            ),
            onImport: {}
        )
    }
}
