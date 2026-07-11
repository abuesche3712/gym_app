
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
                VStack(spacing: AppSpacing.xl) {
                    // Custom Header
                    builderHeader

                    // Builder Cards
                    VStack(spacing: AppSpacing.md) {
                        programsCard
                        workoutsCard
                        modulesCard
                    }
                    .padding(AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .fill(AppColors.surfacePrimary.opacity(0.55))
                    )

                }
                .padding(AppSpacing.screenPadding)
                .tabBarBottomPadding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var builderHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Training")
                    .elegantLabel(color: AppColors.dominant)
                Text("Build your plan")
                    .displaySmall()

                if programViewModel.activeProgram != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.dominant)
                            .frame(width: 6, height: 6)
                        Text("Program active")
                            .caption(color: AppColors.dominant)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Settings button
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: AppSpacing.minTouchTarget, height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: - Builder Cards

    private var programsCard: some View {
        NavigationLink {
            ProgramsListView()
        } label: {
            BuilderCard(
                icon: "calendar.badge.plus",
                iconColor: AppColors.accent4,
                title: "Programs",
                subtitle: "Multi-week training blocks",
                count: programViewModel.programs.count,
                countLabel: "programs",
                activeIndicator: programViewModel.activeProgram != nil ? "1 active" : nil
            )
        }
        .buttonStyle(.pressable)
    }

    private var workoutsCard: some View {
        NavigationLink {
            WorkoutsListView()
        } label: {
            BuilderCard(
                icon: "figure.strengthtraining.traditional",
                iconColor: AppColors.dominant,
                title: "Workouts",
                subtitle: "Individual training sessions",
                count: workoutViewModel.workouts.filter { !$0.archived }.count,
                countLabel: "workouts",
                activeIndicator: nil
            )
        }
        .buttonStyle(.pressable)
    }

    private var modulesCard: some View {
        NavigationLink {
            ModulesListView()
        } label: {
            BuilderCard(
                icon: "square.stack.3d.up.fill",
                iconColor: AppColors.accent3,
                title: "Modules",
                subtitle: "Reusable exercise groups",
                count: moduleViewModel.modules.count,
                countLabel: "modules",
                activeIndicator: nil
            )
        }
        .buttonStyle(.pressable)
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
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .headline(color: AppColors.textPrimary)

                    if let active = activeIndicator {
                        Text(active)
                            .caption2(color: .white)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColor)
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .subheadline(color: AppColors.textSecondary)

                Text("\(count) \(countLabel)")
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .subheadline(color: AppColors.textTertiary)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(iconColor.opacity(0.035))
        )
        .unifiedCard(padding: 0)
    }
}

#Preview {
    WorkoutBuilderView()
}
