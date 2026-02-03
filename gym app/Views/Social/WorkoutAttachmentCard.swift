//
//  WorkoutAttachmentCard.swift
//  gym app
//
//  Elevated workout card - the hero content in feed posts
//

import SwiftUI

struct WorkoutAttachmentCard: View {
    let session: Session

    // MARK: - Computed Stats

    private var totalSets: Int {
        session.completedModules.filter { !$0.skipped }.reduce(0) { total, module in
            total + module.completedExercises.reduce(0) { $0 + $1.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count } }
        }
    }

    private var totalExercises: Int {
        session.completedModules.filter { !$0.skipped }.reduce(0) { $0 + $1.completedExercises.count }
    }

    private var totalVolume: Double {
        session.completedModules.filter { !$0.skipped }.reduce(0) { moduleTotal, module in
            moduleTotal + module.completedExercises.reduce(0) { $0 + $1.totalVolume }
        }
    }

    private var formattedVolume: String {
        if totalVolume >= 10000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return String(format: "%.0f", totalVolume)
    }

    private var formattedDuration: String {
        guard let duration = session.duration else { return "—" }
        let hours = duration / 60
        let minutes = duration % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: session.date)
    }

    private var topLifts: [(exerciseName: String, topWeight: Double, topReps: Int)] {
        var lifts: [(exerciseName: String, topWeight: Double, topReps: Int)] = []

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises where exercise.exerciseType == .strength {
                let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
                if let topSet = completedSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
                   let weight = topSet.weight, weight > 0,
                   let reps = topSet.reps, reps > 0 {
                    lifts.append((exercise.exerciseName, weight, reps))
                }
            }
        }

        return lifts.sorted { $0.topWeight > $1.topWeight }.prefix(3).map { $0 }
    }

    // Cardio exercises with duration/distance
    private var cardioHighlights: [(exerciseName: String, duration: Int?, distance: Double?, distanceUnit: DistanceUnit)] {
        var highlights: [(exerciseName: String, duration: Int?, distance: Double?, distanceUnit: DistanceUnit)] = []

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises where exercise.exerciseType == .cardio {
                let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
                let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
                let totalDistance = completedSets.compactMap { $0.distance }.reduce(0, +)

                if totalDuration > 0 || totalDistance > 0 {
                    highlights.append((exercise.exerciseName, totalDuration > 0 ? totalDuration : nil, totalDistance > 0 ? totalDistance : nil, exercise.distanceUnit))
                }
            }
        }

        return Array(highlights.prefix(3))
    }

    // Isometric exercises with hold times
    private var isometricHighlights: [(exerciseName: String, holdTime: Int)] {
        var highlights: [(exerciseName: String, holdTime: Int)] = []

        for module in session.completedModules where !module.skipped {
            for exercise in module.completedExercises where exercise.exerciseType == .isometric {
                let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
                let totalHoldTime = completedSets.compactMap { $0.holdTime }.reduce(0, +)

                if totalHoldTime > 0 {
                    highlights.append((exercise.exerciseName, totalHoldTime))
                }
            }
        }

        return Array(highlights.prefix(3))
    }

    // Check if there are any highlights to show
    private var hasHighlights: Bool {
        !topLifts.isEmpty || !cardioHighlights.isEmpty || !isometricHighlights.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header row
            headerRow

            // Stats row
            statsRow

            // Exercise highlights sections
            if !topLifts.isEmpty {
                topLiftsSection
            }

            if !cardioHighlights.isEmpty {
                cardioSection
            }

            if !isometricHighlights.isEmpty {
                isometricSection
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.large)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName.uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)
                    .kerning(0.5)

                HStack(spacing: AppSpacing.xs) {
                    Text(formattedDuration)
                        .caption(color: AppColors.textTertiary)
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text(formattedDate)
                        .caption(color: AppColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            miniStat(value: "\(totalSets)", label: "SETS")
            miniStat(value: "\(totalExercises)", label: "EXERCISES")
            miniStat(value: formattedVolume, label: "VOLUME")
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .displayMedium(color: AppColors.dominant)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .statLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.dominant.opacity(0.08))
        )
    }

    // MARK: - Top Lifts Section

    private var topLiftsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("TOP LIFTS")
                .statLabel(color: AppColors.textTertiary)

            ForEach(topLifts, id: \.exerciseName) { lift in
                HStack {
                    Text(lift.exerciseName)
                        .subheadline(color: AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: AppSpacing.xs) {
                        Text(formatWeight(lift.topWeight))
                            .monoSmall()
                        Text("×")
                            .caption(color: AppColors.textTertiary)
                        Text("\(lift.topReps)")
                            .monoSmall()
                    }
                }
            }
        }
    }

    // MARK: - Cardio Section

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CARDIO")
                .statLabel(color: AppColors.textTertiary)

            ForEach(cardioHighlights, id: \.exerciseName) { item in
                HStack {
                    Text(item.exerciseName)
                        .subheadline(color: AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: AppSpacing.sm) {
                        if let duration = item.duration, duration > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(formatDurationSeconds(duration))
                                    .monoSmall()
                            }
                            .foregroundColor(AppColors.accent3)
                        }

                        if let distance = item.distance, distance > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "figure.run")
                                    .font(.caption2)
                                Text(formatDistance(distance, unit: item.distanceUnit))
                                    .monoSmall()
                            }
                            .foregroundColor(AppColors.accent1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Isometric Section

    private var isometricSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("HOLDS")
                .statLabel(color: AppColors.textTertiary)

            ForEach(isometricHighlights, id: \.exerciseName) { item in
                HStack {
                    Text(item.exerciseName)
                        .subheadline(color: AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text(formatDurationSeconds(item.holdTime))
                            .monoSmall()
                    }
                    .foregroundColor(AppColors.accent2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    private func formatDurationSeconds(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)h \(mins)m"
        } else if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(mins)m \(secs)s"
            }
            return "\(mins)m"
        } else {
            return "\(seconds)s"
        }
    }

    private func formatDistance(_ distance: Double, unit: DistanceUnit) -> String {
        if distance.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(distance)) \(unit.abbreviation)"
        }
        return String(format: "%.1f %@", distance, unit.abbreviation)
    }
}

#Preview {
    WorkoutAttachmentCard(session: Session(
        workoutId: UUID(),
        workoutName: "Full Body Moderate",
        completedModules: [],
        duration: 94
    ))
    .padding()
    .background(AppColors.background)
}
