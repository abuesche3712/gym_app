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
    @EnvironmentObject var sessionViewModel: SessionViewModel

    @State private var showingAddWorkout = false
    @State private var searchText = ""
    @State private var editingWorkout: Workout?
    @State private var showingActiveSession = false

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
            ScrollView {
                if filteredWorkouts.isEmpty {
                    EmptyStateView(
                        icon: "figure.strengthtraining.traditional",
                        title: "No Workouts",
                        message: "Create a workout by combining modules into a routine",
                        buttonTitle: "Create Workout"
                    ) {
                        showingAddWorkout = true
                    }
                    .padding(.top, AppSpacing.xxl)
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(filteredWorkouts) { workout in
                            WorkoutListCard(
                                workout: workout,
                                modules: workoutViewModel.getModulesForWorkout(workout, allModules: moduleViewModel.modules),
                                onTap: {
                                    editingWorkout = workout
                                },
                                onStart: {
                                    startWorkout(workout)
                                }
                            )
                            .contextMenu {
                                Button {
                                    editingWorkout = workout
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button {
                                    startWorkout(workout)
                                } label: {
                                    Label("Start Workout", systemImage: "play.fill")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    workoutViewModel.deleteWorkout(workout)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                NavigationStack {
                    WorkoutFormView(workout: nil)
                }
            }
            .sheet(item: $editingWorkout) { workout in
                NavigationStack {
                    WorkoutFormView(workout: workout)
                }
            }
            .fullScreenCover(isPresented: $showingActiveSession) {
                if sessionViewModel.isSessionActive {
                    ActiveSessionView()
                }
            }
            .refreshable {
                workoutViewModel.loadWorkouts()
            }
        }
    }

    private func startWorkout(_ workout: Workout) {
        let modules = workout.moduleReferences
            .sorted { $0.order < $1.order }
            .compactMap { ref in moduleViewModel.getModule(id: ref.moduleId) }

        sessionViewModel.startSession(workout: workout, modules: modules)
        showingActiveSession = true
    }
}

// MARK: - Workout List Card

struct WorkoutListCard: View {
    let workout: Workout
    let modules: [Module]
    var onTap: (() -> Void)? = nil
    var onStart: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(workout.name)
                        .font(.title3.bold())
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.md) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 12))
                            Text("\(modules.count) modules")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                        if let duration = workout.estimatedDuration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                Text("\(duration) min")
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                Button(action: { onStart?() }) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentBlue)
                            .frame(width: 44, height: 44)

                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            // Module list
            if !modules.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        HStack(spacing: AppSpacing.md) {
                            // Order number
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 20)

                            // Module icon
                            Image(systemName: module.type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.moduleColor(module.type))
                                .frame(width: 24)

                            // Module name
                            Text(module.name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            // Exercise count
                            Text("\(module.exercises.count)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, AppSpacing.xs)

                        if index < modules.count - 1 {
                            Divider()
                                .background(AppColors.border.opacity(0.5))
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceLight.opacity(0.5))
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

#Preview {
    WorkoutsListView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(ModuleViewModel())
        .environmentObject(SessionViewModel())
}
