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
                        ForEach(Array(filteredWorkouts.enumerated()), id: \.element.id) { index, workout in
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
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
                                value: filteredWorkouts.count
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
                    .animation(.easeInOut(duration: 0.3), value: filteredWorkouts.count)
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
        // MainTabView will auto-show full session when isSessionActive becomes true
    }
}

// MARK: - Workout List Card

struct WorkoutListCard: View {
    let workout: Workout
    let modules: [Module]
    var onTap: (() -> Void)? = nil
    var onStart: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(workout.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    if let duration = workout.estimatedDuration {
                        Label("\(duration) min", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Module preview chips
                if !modules.isEmpty {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(modules.prefix(3)) { module in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AppColors.moduleColor(module.type))
                                    .frame(width: 6, height: 6)
                                Text(module.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(AppColors.textTertiary)
                        }
                        if modules.count > 3 {
                            Text("+\(modules.count - 3)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            // Play button
            Button(action: { onStart?() }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(AppColors.accentBlue)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
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
