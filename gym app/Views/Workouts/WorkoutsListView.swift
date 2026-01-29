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
    @Environment(\.dismiss) private var dismiss

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
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Custom header
                    workoutsHeader

                    if filteredWorkouts.isEmpty {
                        EmptyStateView(
                            icon: "figure.strengthtraining.traditional",
                            title: "No Workouts",
                            message: "Create a workout by combining modules into a routine",
                            buttonTitle: "Create Workout"
                        ) {
                            showingAddWorkout = true
                        }
                        .padding(.top, AppSpacing.xl)
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
                        .animation(.easeInOut(duration: 0.3), value: filteredWorkouts.count)
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .displaySmall(color: AppColors.dominant)
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

    // MARK: - Header

    private var workoutsHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Navigation row with circular back and plus buttons
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .body(color: AppColors.dominant)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.dominant.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.dominant.opacity(0.2), lineWidth: 1)
                        )
                }

                Spacer()

                Button {
                    showingAddWorkout = true
                } label: {
                    Image(systemName: "plus")
                        .body(color: AppColors.dominant)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.dominant.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.dominant.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // Title section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORKOUTS")
                        .elegantLabel(color: AppColors.dominant)

                    Text("Your Workouts")
                        .displayMedium(color: AppColors.textPrimary)

                    if let subtitle = workoutSubtitle {
                        Text(subtitle)
                            .subheadline(color: AppColors.textSecondary)
                    }
                }

                Spacer()

                // Count badge
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .caption(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                    Text("\(workoutViewModel.workouts.count) total")
                        .subheadline(color: AppColors.textSecondary)
                        .fontWeight(.medium)
                }
            }

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.dominant.opacity(0.6), AppColors.dominant.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    private var workoutSubtitle: String? {
        guard let lastSession = sessionViewModel.sessions.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last workout \(formatter.localizedString(for: lastSession.date, relativeTo: Date()))"
    }

    // MARK: - Actions

    private func startWorkout(_ workout: Workout) {
        // Refresh modules to ensure we have the latest data (picks up any recently added exercises)
        moduleViewModel.loadModules()

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
                    .headline(color: AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                        .subheadline(color: AppColors.textSecondary)

                    if let duration = workout.estimatedDuration {
                        Label("\(duration) min", systemImage: "clock")
                            .subheadline(color: AppColors.textSecondary)
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
                                    .caption(color: AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        if modules.count > 3 {
                            Text("+\(modules.count - 3)")
                                .caption(color: AppColors.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            // Play button
            Button(action: { onStart?() }) {
                Image(systemName: "play.fill")
                    .subheadline(color: .white)
                    .fontWeight(.semibold)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(AppColors.dominant)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 0.5)
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
