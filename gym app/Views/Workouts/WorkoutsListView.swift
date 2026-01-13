//
//  WorkoutsListView.swift
//  gym app
//
//  List of all workout templates
//

import SwiftUI

struct WorkoutsListView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel

    @State private var showingAddWorkout = false
    @State private var searchText = ""

    var filteredWorkouts: [Workout] {
        if searchText.isEmpty {
            return workoutViewModel.workouts
        }
        return workoutViewModel.workouts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Create a workout to get started")
                    )
                } else {
                    ForEach(filteredWorkouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            WorkoutRow(
                                workout: workout,
                                modules: workoutViewModel.getModulesForWorkout(workout, allModules: moduleViewModel.modules)
                            )
                        }
                    }
                    .onDelete { offsets in
                        let workoutsToDelete = offsets.map { filteredWorkouts[$0] }
                        for workout in workoutsToDelete {
                            workoutViewModel.deleteWorkout(workout)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                NavigationStack {
                    WorkoutFormView(workout: nil)
                }
            }
            .refreshable {
                workoutViewModel.loadWorkouts()
            }
        }
    }
}

// MARK: - Workout Row

struct WorkoutRow: View {
    let workout: Workout
    let modules: [Module]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = workout.estimatedDuration {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Module type icons
            if !modules.isEmpty {
                HStack(spacing: 4) {
                    ForEach(modules.prefix(5)) { module in
                        Image(systemName: module.type.icon)
                            .font(.caption)
                            .foregroundStyle(Color(module.type.color))
                    }
                    if modules.count > 5 {
                        Text("+\(modules.count - 5)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutsListView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(ModuleViewModel())
}
