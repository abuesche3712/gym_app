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
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
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
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.25), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(iconColor.opacity(0.3), lineWidth: 0.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.3), radius: 4, x: 0, y: 0)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if let active = activeIndicator {
                        Text(active)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Text("\(count) \(countLabel)")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)
        }
        .gradientCard(accent: iconColor)
    }
}

#Preview {
    WorkoutBuilderView()
}
