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
    @State private var showingActiveSession = false
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
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                        if let duration = currentWorkout.estimatedDuration ?? calculateDuration() {
                            Label("\(duration) min", systemImage: "clock")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    // Start Workout Button
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
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
                        .foregroundStyle(.secondary)
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
                                        .font(.subheadline)
                                    if let duration = session.formattedDuration {
                                        Text(duration)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Workout", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditWorkout = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditWorkout) {
            NavigationStack {
                WorkoutFormView(workout: currentWorkout)
            }
        }
        .fullScreenCover(isPresented: $showingActiveSession) {
            ActiveSessionView()
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
        sessionViewModel.startSession(workout: currentWorkout, modules: modules)
        showingActiveSession = true
    }
}

// MARK: - Workout Module Row

struct WorkoutModuleRow: View {
    let module: Module
    let order: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(order)")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 24, height: 24)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            Image(systemName: module.type.icon)
                .foregroundStyle(Color(module.type.color))

            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(module.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = module.estimatedDuration {
                Text("\(duration)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Feeling Indicator

struct FeelingIndicator: View {
    let feeling: Int

    var emoji: String {
        switch feeling {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "💪"
        default: return "😐"
        }
    }

    var body: some View {
        Text(emoji)
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
