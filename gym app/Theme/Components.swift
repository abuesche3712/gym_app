//
//  Components.swift
//  gym app
//
//  Reusable UI components
//

import SwiftUI

// MARK: - Module Card

struct ModuleCard: View {
    let module: Module
    var showExerciseCount: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.moduleColor(module.type).opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: module.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.moduleColor(module.type))
                }

                // Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(module.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.sm) {
                        Text(module.type.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.moduleColor(module.type))

                        if showExerciseCount {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text("\(module.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.moduleColor(module.type).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Card

struct WorkoutCard: View {
    let workout: Workout
    let modules: [Module]
    var onTap: (() -> Void)? = nil
    var onStart: (() -> Void)? = nil

    private var workoutModules: [Module] {
        workout.moduleReferences.compactMap { ref in
            modules.first { $0.id == ref.moduleId }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(workout.name)
                        .font(.title3.bold())
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(workoutModules.count) modules")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button(action: { onStart?() }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppColors.dominant)
                        )
                }
            }

            // Module pills
            if !workoutModules.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(workoutModules) { module in
                            ModulePill(module: module)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppGradients.subtleGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Module Pill

struct ModulePill: View {
    let module: Module

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: module.type.icon)
                .font(.system(size: 10))

            Text(module.name)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundColor(AppColors.moduleColor(module.type))
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(AppColors.moduleColor(module.type).opacity(0.12))
        )
    }
}

// MARK: - Set Timer Ring

struct SetTimerRing: View {
    let timeRemaining: Int
    let totalTime: Int
    var size: CGFloat = 44
    var isActive: Bool = false

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppColors.surfaceTertiary, lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isActive ? AppColors.dominant : AppColors.accent1,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AppAnimation.smooth, value: progress)

            // Time text
            Text(formatTime(timeRemaining))
                .font(.system(size: size * 0.28, weight: .semibold, design: .monospaced))
                .foregroundColor(isActive ? AppColors.dominant : AppColors.textSecondary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 4
    var color: Color = AppColors.dominant

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppColors.surfaceTertiary)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(AppAnimation.smooth, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    var color: Color = AppColors.dominant

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
        )
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "See All"

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.subheadline)
                        .foregroundColor(AppColors.dominant)
                }
            }
        }
    }
}

// MARK: - Draggable Module Card

struct DraggableModuleCard: View {
    let module: Module
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)

            Image(systemName: module.type.icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.moduleColor(module.type))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(AppColors.moduleColor(module.type).opacity(0.12))
                )

            Text(module.name)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("\(module.exercises.count)")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(isDragging ? AppColors.dominant : AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
        .scaleEffect(isDragging ? 1.02 : 1)
        .opacity(isDragging ? 0.8 : 1)
        .animation(AppAnimation.quick, value: isDragging)
    }
}

// MARK: - Time Picker View

struct TimePickerView: View {
    @Binding var totalSeconds: Int
    var maxMinutes: Int = 10
    var maxHours: Int = 0  // Set > 0 to show hours picker (for cardio)
    var label: String = "Time"
    var compact: Bool = false
    var secondsStep: Int = 5  // Step size for seconds (1 for fine control, 5 for quick selection)

    private var showHours: Bool { maxHours > 0 }

    private var hours: Binding<Int> {
        Binding(
            get: { totalSeconds / 3600 },
            set: { totalSeconds = $0 * 3600 + (totalSeconds % 3600) }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { showHours ? (totalSeconds % 3600) / 60 : totalSeconds / 60 },
            set: {
                if showHours {
                    totalSeconds = (totalSeconds / 3600) * 3600 + $0 * 60 + (totalSeconds % 60)
                } else {
                    totalSeconds = $0 * 60 + (totalSeconds % 60)
                }
            }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { totalSeconds % 60 },
            set: {
                if showHours {
                    totalSeconds = (totalSeconds / 3600) * 3600 + ((totalSeconds % 3600) / 60) * 60 + $0
                } else {
                    totalSeconds = (totalSeconds / 60) * 60 + $0
                }
            }
        )
    }

    private var secondsRange: [Int] {
        Array(stride(from: 0, through: 59, by: secondsStep))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !compact {
                Text(label.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
            }

            HStack(spacing: 0) {
                if showHours {
                    // Hours picker
                    Picker("Hours", selection: hours) {
                        ForEach(0...maxHours, id: \.self) { hr in
                            Text("\(hr)").tag(hr)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 50)
                    .clipped()

                    Text("hr")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 25)
                }

                // Minutes picker
                Picker("Minutes", selection: minutes) {
                    ForEach(0..<(showHours ? 60 : maxMinutes + 1), id: \.self) { min in
                        Text(showHours ? String(format: "%02d", min) : "\(min)").tag(min)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: showHours ? 50 : 60)
                .clipped()

                Text("min")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: showHours ? 28 : 30)

                // Seconds picker
                Picker("Seconds", selection: seconds) {
                    ForEach(secondsRange, id: \.self) { sec in
                        Text(String(format: "%02d", sec)).tag(sec)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: showHours ? 50 : 60)
                .clipped()

                Text("sec")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: showHours ? 28 : 30)
            }
            .frame(height: compact ? 100 : 120)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceTertiary)
            )
        }
    }
}

// MARK: - Compact Time Picker (for inline use)

struct CompactTimePicker: View {
    @Binding var totalSeconds: Int
    var maxMinutes: Int = 10

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(formatDurationVerbose(totalSeconds))
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Stepper("", value: $totalSeconds, in: 0...(maxMinutes * 60), step: 15)
                .labelsHidden()
        }
    }
}
