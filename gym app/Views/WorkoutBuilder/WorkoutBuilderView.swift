//
//  WorkoutBuilderView.swift
//  gym app
//
//  Hub view for building training programs, workouts, and modules
//

import SwiftUI

struct WorkoutBuilderView: View {
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @EnvironmentObject private var workoutViewModel: WorkoutViewModel
    @EnvironmentObject private var moduleViewModel: ModuleViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Builder Cards
                    VStack(spacing: 16) {
                        programsCard
                        workoutsCard
                        modulesCard
                    }
                    .padding(.horizontal)

                    // Quick Stats
                    quickStatsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout Builder")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Build Your Training")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create programs, workouts, and modules")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Builder Cards

    private var programsCard: some View {
        NavigationLink {
            ProgramsListView()
        } label: {
            BuilderCard(
                icon: "calendar.badge.plus",
                iconColor: .green,
                title: "Programs",
                subtitle: "Multi-week training blocks",
                count: programViewModel.programs.count,
                countLabel: "programs",
                activeIndicator: programViewModel.activeProgram != nil ? "1 active" : nil
            )
        }
        .buttonStyle(.plain)
    }

    private var workoutsCard: some View {
        NavigationLink {
            WorkoutsListView()
        } label: {
            BuilderCard(
                icon: "figure.strengthtraining.traditional",
                iconColor: .blue,
                title: "Workouts",
                subtitle: "Individual training sessions",
                count: workoutViewModel.workouts.filter { !$0.archived }.count,
                countLabel: "workouts",
                activeIndicator: nil
            )
        }
        .buttonStyle(.plain)
    }

    private var modulesCard: some View {
        NavigationLink {
            ModulesListView()
        } label: {
            BuilderCard(
                icon: "square.stack.3d.up.fill",
                iconColor: .purple,
                title: "Modules",
                subtitle: "Reusable exercise groups",
                count: moduleViewModel.modules.count,
                countLabel: "modules",
                activeIndicator: nil
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Stats

    private var activeWorkoutsCount: Int {
        workoutViewModel.workouts.reduce(0) { $0 + ($1.archived ? 0 : 1) }
    }

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                StatCard(
                    title: "Programs",
                    value: "\(programViewModel.programs.count)",
                    icon: "calendar",
                    color: .green
                )

                StatCard(
                    title: "Workouts",
                    value: "\(activeWorkoutsCount)",
                    icon: "dumbbell",
                    color: .blue
                )

                StatCard(
                    title: "Modules",
                    value: "\(moduleViewModel.modules.count)",
                    icon: "square.stack.3d.up",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Builder Card

struct BuilderCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let count: Int
    let countLabel: String
    let activeIndicator: String?

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let active = activeIndicator {
                        Text(active)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("\(count) \(countLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

#Preview {
    WorkoutBuilderView()
}
