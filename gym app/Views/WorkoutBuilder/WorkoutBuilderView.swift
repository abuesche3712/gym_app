
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

    @State private var showingNewModule = false
    @State private var showingNewWorkout = false
    @State private var showingNewProgram = false

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

                    // Program Calendar (if active program exists)
                    if let activeProgram = programViewModel.activeProgram {
                        activeProgramCalendar(program: activeProgram)
                    }

                    // Quick Actions
                    quickActionsSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewModule) {
                NavigationStack {
                    ModuleFormView(module: nil)
                }
            }
            .sheet(isPresented: $showingNewWorkout) {
                NavigationStack {
                    WorkoutFormView(workout: nil)
                }
            }
            .sheet(isPresented: $showingNewProgram) {
                NavigationStack {
                    ProgramFormView(program: nil)
                }
            }
        }
    }

    // MARK: - Header

    private var builderHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Top label row
            HStack(alignment: .center) {
                Text("TRAINING HUB")
                    .elegantLabel(color: AppColors.dominant)

                Spacer()

                // Show active program indicator if exists
                if programViewModel.activeProgram != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.programAccent)
                            .frame(width: 6, height: 6)
                        Text("Program active")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.programAccent)
                    }
                }
            }
        }
    }

    // MARK: - Active Program Calendar

    private func activeProgramCalendar(program: Program) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE PROGRAM")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.programAccent)
                        .tracking(1.2)

                    Text(program.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                // Week progress
                if let startDate = program.startDate {
                    let currentWeek = getCurrentWeek(startDate: startDate, durationWeeks: program.durationWeeks)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Week \(currentWeek)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.dominant)

                        Text("of \(program.durationWeeks)")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            // Weekly calendar grid
            programWeekGrid(program: program)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.programAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func programWeekGrid(program: Program) -> some View {
        let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
        let today = Calendar.current.component(.weekday, from: Date()) - 1 // 0-indexed

        return VStack(spacing: AppSpacing.sm) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Text(dayNames[day])
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(day == today ? AppColors.dominant : AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells with workouts
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    let slots = program.allSlotsForDay(day)
                    programDayCell(day: day, slots: slots, isToday: day == today)
                }
            }
        }
    }

    private func programDayCell(day: Int, slots: [ProgramSlot], isToday: Bool) -> some View {
        VStack(spacing: 3) {
            if slots.isEmpty {
                // Rest day
                Text("Rest")
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxHeight: .infinity)
            } else {
                // Show slot indicators
                ForEach(slots.prefix(3)) { slot in
                    slotIndicator(slot: slot)
                }
                if slots.count > 3 {
                    Text("+\(slots.count - 3)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(isToday ? AppColors.dominant.opacity(0.1) : AppColors.surfaceTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.small)
                        .stroke(isToday ? AppColors.dominant.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }

    private func slotIndicator(slot: ProgramSlot) -> some View {
        let color: Color = {
            if let moduleType = slot.content.moduleType {
                return AppColors.moduleColor(moduleType)
            }
            // Hash-based color for workouts
            let hash = slot.displayName.hashValue
            let hue = Double(abs(hash) % 360) / 360.0
            return Color(hue: hue, saturation: 0.5, brightness: 0.7)
        }()

        return HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)

            Text(abbreviatedSlotName(slot.displayName))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func abbreviatedSlotName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(2).map { String($0.prefix(1)) }.joined()
        } else if name.count > 4 {
            return String(name.prefix(4))
        }
        return name
    }

    private func getCurrentWeek(startDate: Date, durationWeeks: Int) -> Int {
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear], from: startDate, to: Date()).weekOfYear ?? 0
        return min(max(weeks + 1, 1), durationWeeks)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("QUICK CREATE")
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                quickActionButton(
                    icon: "square.stack.3d.up.fill",
                    label: "Module",
                    color: AppColors.accent3
                ) {
                    showingNewModule = true
                }

                Spacer()

                quickActionButton(
                    icon: "figure.strengthtraining.traditional",
                    label: "Workout",
                    color: AppColors.dominant
                ) {
                    showingNewWorkout = true
                }

                Spacer()

                quickActionButton(
                    icon: "calendar.badge.plus",
                    label: "Program",
                    color: AppColors.programAccent
                ) {
                    showingNewProgram = true
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Builder Cards

    private var programsCard: some View {
        NavigationLink {
            ProgramsListView()
        } label: {
            BuilderCard(
                icon: "calendar.badge.plus",
                iconColor: AppColors.programAccent,
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
                iconColor: AppColors.dominant,
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
                iconColor: AppColors.accent3,
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
                            colors: [iconColor.opacity(0.12), iconColor.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(iconColor.opacity(0.15), lineWidth: 0.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor.opacity(0.8))
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
                                    colors: [AppColors.programAccent, AppColors.programAccent.opacity(0.8)],
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
