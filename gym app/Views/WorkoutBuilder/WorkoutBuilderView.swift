
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
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var builderHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Top row
            HStack(alignment: .center) {
                Text("TRAINING HUB")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentBlue)
                    .tracking(1.5)

                Spacer()

                // Total items badge
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 10))
                    Text("\(totalItems) items")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(AppColors.textSecondary)
            }

            // Title
            Text("Workout Builder")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.5)

            // Subtitle with quick stats
            HStack(spacing: AppSpacing.md) {
                quickStat(value: programViewModel.programs.count, label: "programs", color: AppColors.success)
                quickStat(value: workoutViewModel.workouts.count, label: "workouts", color: AppColors.accentBlue)
                quickStat(value: moduleViewModel.modules.count, label: "modules", color: AppColors.accentPurple)
            }

            // Accent line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accentBlue.opacity(0.6), AppColors.accentPurple.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.top, AppSpacing.xs)
        }
    }

    private var totalItems: Int {
        programViewModel.programs.count + workoutViewModel.workouts.count + moduleViewModel.modules.count
    }

    private func quickStat(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
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
