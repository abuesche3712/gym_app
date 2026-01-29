//
//  WorkoutDetailView.swift
//  gym app
//
//  Detailed view of a workout with its modules
//

import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    let workout: Workout

    @State private var showingEditWorkout = false
    @State private var showingDeleteConfirmation = false

    private var currentWorkout: Workout {
        workoutViewModel.getWorkout(id: workout.id) ?? workout
    }

    private var modules: [Module] {
        workoutViewModel.getModulesForWorkout(currentWorkout, allModules: moduleViewModel.modules)
    }

    var body: some View {
        List {
            // Workout Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentWorkout.name)
                        .displaySmall(color: AppColors.textPrimary)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                        if let duration = currentWorkout.estimatedDuration ?? calculateDuration() {
                            Label("\(duration) min", systemImage: "clock")
                        }
                    }
                    .subheadline(color: AppColors.textSecondary)

                    // Start Workout Button
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .headline(color: .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.success)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.clear)
            }

            // Notes Section
            if let notes = currentWorkout.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .body(color: AppColors.textSecondary)
                }
            }

            // Modules Section
            Section("Modules") {
                if modules.isEmpty {
                    ContentUnavailableView(
                        "No Modules",
                        systemImage: "square.stack.3d.up",
                        description: Text("Add modules to this workout")
                    )
                } else {
                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        NavigationLink(destination: ModuleDetailView(module: module)) {
                            WorkoutModuleRow(module: module, order: index + 1)
                        }
                    }
                }
            }

            // Recent Sessions
            let recentSessions = sessionViewModel.getSessionsForWorkout(currentWorkout.id).prefix(3)
            if !recentSessions.isEmpty {
                Section("Recent Sessions") {
                    ForEach(Array(recentSessions)) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.formattedDate)
                                        .subheadline(color: AppColors.textPrimary)
                                    if let duration = session.formattedDuration {
                                        Text(duration)
                                            .caption(color: AppColors.textSecondary)
                                    }
                                }
                                Spacer()
                                if let feeling = session.overallFeeling {
                                    FeelingIndicator(feeling: feeling)
                                }
                            }
                        }
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditWorkout = true
                    } label: {
                        Label("Edit Workout", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            NavigationStack {
                WorkoutFormView(workout: currentWorkout)
            }
        }
        .confirmationDialog(
            "Delete Workout",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                workoutViewModel.deleteWorkout(currentWorkout)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(currentWorkout.name)\"? This action cannot be undone.")
        }
    }

    private func calculateDuration() -> Int? {
        let total = modules.compactMap { $0.estimatedDuration }.reduce(0, +)
        return total > 0 ? total : nil
    }

    private func startWorkout() {
        // Refresh modules to ensure we have the latest data (picks up any recently added exercises)
        moduleViewModel.loadModules()

        // Re-fetch modules after refresh
        let freshModules = workoutViewModel.getModulesForWorkout(currentWorkout, allModules: moduleViewModel.modules)
        sessionViewModel.startSession(workout: currentWorkout, modules: freshModules)
        // MainTabView will auto-show full session when isSessionActive becomes true
    }
}

// MARK: - Workout Module Row

struct WorkoutModuleRow: View {
    let module: Module
    let order: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(order)")
                .caption(color: AppColors.textPrimary)
                .fontWeight(.semibold)
                .frame(width: 24, height: 24)
                .background(AppColors.surfaceTertiary)
                .clipShape(Circle())

            Image(systemName: module.type.icon)
                .foregroundStyle(module.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.medium)

                Text("\(module.exercises.count) exercises")
                    .caption(color: AppColors.textSecondary)
            }

            Spacer()

            if let duration = module.estimatedDuration {
                Text("\(duration)m")
                    .caption(color: AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Feeling Indicator

struct FeelingIndicator: View {
    let feeling: Int

    var body: some View {
        Text("\(feeling)")
            .caption(color: AppColors.textPrimary)
            .fontWeight(.bold)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Sample Workout"))
            .environmentObject(WorkoutViewModel())
            .environmentObject(ModuleViewModel())
            .environmentObject(SessionViewModel())
    }
}
