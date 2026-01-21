
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Top label row
            HStack(alignment: .center) {
                Text("TRAINING HUB")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentBlue)
                    .tracking(1.5)

                Spacer()

                // Animated pulse indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(AppColors.success.opacity(0.4), lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                    Text("\(totalItems) items")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Visual stat blocks
            HStack(spacing: AppSpacing.sm) {
                statBlock(
                    value: programViewModel.programs.count,
                    label: "Programs",
                    icon: "calendar.badge.plus",
                    color: AppColors.success,
                    hasActive: programViewModel.activeProgram != nil
                )

                statBlock(
                    value: workoutViewModel.workouts.filter { !$0.archived }.count,
                    label: "Workouts",
                    icon: "figure.strengthtraining.traditional",
                    color: AppColors.accentBlue,
                    hasActive: false
                )

                statBlock(
                    value: moduleViewModel.modules.count,
                    label: "Modules",
                    icon: "square.stack.3d.up.fill",
                    color: AppColors.accentPurple,
                    hasActive: false
                )
            }

            // Contextual tip/message
            contextualMessage
        }
    }

    private func statBlock(value: Int, label: String, icon: String, color: Color, hasActive: Bool) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )

                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)

                    Text("\(value)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.vertical, AppSpacing.md)

                if hasActive {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(AppColors.success)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.cardBackground, lineWidth: 2)
                                )
                                .offset(x: -8, y: 8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private var contextualMessage: some View {
        let message = getContextualMessage()
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: message.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(message.color)

            Text(message.text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            if let action = message.actionIcon {
                Image(systemName: action)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(message.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(message.color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func getContextualMessage() -> (text: String, icon: String, color: Color, actionIcon: String?) {
        let moduleCount = moduleViewModel.modules.count
        let workoutCount = workoutViewModel.workouts.filter { !$0.archived }.count
        let programCount = programViewModel.programs.count

        if moduleCount == 0 {
            return ("Start by creating your first module", "lightbulb.fill", AppColors.warning, "arrow.right")
        } else if workoutCount == 0 {
            return ("Combine modules into a workout", "sparkles", AppColors.accentBlue, "arrow.right")
        } else if programCount == 0 && workoutCount >= 3 {
            return ("Ready to build a training program?", "flame.fill", AppColors.accentOrange, "arrow.right")
        } else if programViewModel.activeProgram != nil {
            return ("Program active • Stay consistent", "checkmark.seal.fill", AppColors.success, nil)
        } else {
            return ("Your training library", "books.vertical.fill", AppColors.accentPurple, nil)
        }
    }

    private var totalItems: Int {
        programViewModel.programs.count + workoutViewModel.workouts.count + moduleViewModel.modules.count
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
