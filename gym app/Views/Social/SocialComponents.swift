//
//  SocialComponents.swift
//  gym app
//
//  Shared components for social feed views
//

import SwiftUI

// MARK: - Session Post Content

struct SessionPostContent: View {
    let workoutName: String
    let date: Date
    let snapshot: Data

    private var bundle: SessionShareBundle? {
        try? SessionShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            let session = bundle.session
            let completedSets = countCompletedSets(session)
            let duration = session.duration ?? 0
            let hasHighlights = (bundle.highlightedExerciseIds?.isEmpty == false) || (bundle.highlightedSetIds?.isEmpty == false)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.subheadline)
                        .foregroundColor(AppColors.dominant)

                    Text(workoutName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                        .lineLimit(1)
                }

                // Stats row
                HStack(spacing: AppSpacing.md) {
                    if duration > 0 {
                        Label(formatDuration(TimeInterval(duration * 60)), systemImage: "clock.fill")
                    }

                    if completedSets > 0 {
                        Label("\(completedSets) sets", systemImage: "flame.fill")
                    }

                    let exerciseCount = countExercises(session)
                    if exerciseCount > 0 {
                        Label("\(exerciseCount) exercises", systemImage: "dumbbell.fill")
                    }
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

                // Show highlights if user selected any, otherwise show top exercises
                if hasHighlights {
                    highlightsSection(bundle: bundle, session: session)
                } else {
                    topExercisesSection(session: session)
                }

                // Tap hint
                HStack(spacing: AppSpacing.xs) {
                    Spacer()
                    Text("Tap to view full workout")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .flatCardStyle()
        }
    }

    // MARK: - Highlights Section

    @ViewBuilder
    private func highlightsSection(bundle: SessionShareBundle, session: Session) -> some View {
        let highlightedExercises = getHighlightedExercises(session: session, ids: bundle.highlightedExerciseIds ?? [])
        let highlightedSets = getHighlightedSets(session: session, ids: bundle.highlightedSetIds ?? [])

        if !highlightedExercises.isEmpty || !highlightedSets.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Highlighted exercises
                ForEach(highlightedExercises, id: \.id) { exercise in
                    exerciseHighlightRow(exercise: exercise)
                }

                // Highlighted sets
                ForEach(highlightedSets, id: \.set.id) { highlight in
                    setHighlightRow(highlight: highlight)
                }
            }
            .padding(.top, 4)
        }
    }

    private func exerciseHighlightRow(exercise: SessionExercise) -> some View {
        let completedSets = exercise.completedSetGroups.flatMap { $0.sets.filter(\.completed) }
        let summary = exerciseSummary(exercise: exercise, completedSets: completedSets)

        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: exercise.exerciseType.icon)
                .font(.caption)
                .foregroundColor(exerciseTypeColor(exercise.exerciseType))
                .frame(width: 16)

            Text(exercise.exerciseName)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(summary)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func setHighlightRow(highlight: SetHighlight) -> some View {
        let summary = setSummary(set: highlight.set, exerciseType: highlight.exerciseType, distanceUnit: highlight.distanceUnit)

        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: highlight.exerciseType.icon)
                .font(.caption)
                .foregroundColor(exerciseTypeColor(highlight.exerciseType))
                .frame(width: 16)

            Text(highlight.exerciseName)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(summary)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func exerciseTypeColor(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return AppColors.dominant
        case .cardio: return AppColors.warning
        case .mobility: return AppColors.accent1
        case .isometric: return AppColors.dominant
        case .explosive: return AppColors.accent2
        case .recovery: return AppColors.accent1
        }
    }

    // MARK: - Top Exercises Section (fallback when no highlights selected)

    @ViewBuilder
    private func topExercisesSection(session: Session) -> some View {
        let exercises = getTopExercises(session, limit: 3)
        if !exercises.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(exercises, id: \.name) { exercise in
                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(AppColors.dominant.opacity(0.3))
                            .frame(width: 6, height: 6)

                        Text(exercise.name)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)

                        if let summary = exercise.summary {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)

                            Text(summary)
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private struct SetHighlight {
        let set: SetData
        let exerciseName: String
        let exerciseType: ExerciseType
        let distanceUnit: DistanceUnit
    }

    private func getHighlightedExercises(session: Session, ids: [UUID]) -> [SessionExercise] {
        guard !ids.isEmpty else { return [] }
        var result: [SessionExercise] = []
        for module in session.completedModules {
            for exercise in module.completedExercises {
                if ids.contains(exercise.id) {
                    result.append(exercise)
                }
            }
        }
        return result
    }

    private func getHighlightedSets(session: Session, ids: [UUID]) -> [SetHighlight] {
        guard !ids.isEmpty else { return [] }
        var result: [SetHighlight] = []
        for module in session.completedModules {
            for exercise in module.completedExercises {
                for setGroup in exercise.completedSetGroups {
                    for set in setGroup.sets where set.completed {
                        if ids.contains(set.id) {
                            result.append(SetHighlight(
                                set: set,
                                exerciseName: exercise.exerciseName,
                                exerciseType: exercise.exerciseType,
                                distanceUnit: exercise.distanceUnit
                            ))
                        }
                    }
                }
            }
        }
        return result
    }

    private func exerciseSummary(exercise: SessionExercise, completedSets: [SetData]) -> String {
        guard !completedSets.isEmpty else { return "" }

        switch exercise.exerciseType {
        case .strength:
            if let topSet = completedSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
               let weight = topSet.weight, weight > 0 {
                return "\(completedSets.count) sets · Top: \(Int(weight)) lbs"
            } else {
                return "\(completedSets.count) sets"
            }

        case .cardio:
            let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
            let totalDistance = completedSets.compactMap { $0.distance }.reduce(0, +)
            var parts: [String] = []
            if totalDuration > 0 {
                parts.append(formatDurationSeconds(totalDuration))
            }
            if totalDistance > 0 {
                parts.append(formatDistance(totalDistance, unit: exercise.distanceUnit))
            }
            if parts.isEmpty {
                return "\(completedSets.count) sets"
            }
            return parts.joined(separator: " · ")

        case .isometric:
            let totalHold = completedSets.compactMap { $0.holdTime }.reduce(0, +)
            if totalHold > 0 {
                return "Total: \(formatDurationSeconds(totalHold))"
            }
            return "\(completedSets.count) sets"

        case .mobility:
            let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
            if totalDuration > 0 {
                return formatDurationSeconds(totalDuration)
            }
            return "\(completedSets.count) sets"

        case .explosive:
            if let topSet = completedSets.max(by: { ($0.height ?? 0) < ($1.height ?? 0) }),
               let height = topSet.height, height > 0 {
                return "\(completedSets.count) sets · \(Int(height)) in"
            }
            return "\(completedSets.count) sets"

        case .recovery:
            let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
            if totalDuration > 0 {
                return formatDurationSeconds(totalDuration)
            }
            return "\(completedSets.count) sets"
        }
    }

    private func setSummary(set: SetData, exerciseType: ExerciseType, distanceUnit: DistanceUnit) -> String {
        switch exerciseType {
        case .strength:
            if let weight = set.weight, let reps = set.reps, weight > 0 {
                return "\(Int(weight)) lbs × \(reps)"
            } else if let reps = set.reps {
                return "\(reps) reps"
            }

        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDurationSeconds(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append(formatDistance(distance, unit: distanceUnit))
            }
            return parts.joined(separator: " · ")

        case .isometric:
            if let holdTime = set.holdTime, holdTime > 0 {
                return formatDurationSeconds(holdTime)
            }

        case .mobility:
            if let duration = set.duration, duration > 0 {
                return formatDurationSeconds(duration)
            }

        case .explosive:
            if let height = set.height, let quality = set.quality {
                return "\(Int(height)) in · \(quality)/5"
            } else if let height = set.height {
                return "\(Int(height)) in"
            } else if let reps = set.reps {
                return "\(reps) reps"
            }

        case .recovery:
            if let duration = set.duration, duration > 0 {
                return formatDurationSeconds(duration)
            }
        }

        return ""
    }

    private func countCompletedSets(_ session: Session) -> Int {
        session.completedModules.reduce(0) { total, module in
            total + module.completedExercises.reduce(0) { exerciseTotal, exercise in
                exerciseTotal + exercise.completedSetGroups.reduce(0) { groupTotal, group in
                    groupTotal + group.sets.filter(\.completed).count
                }
            }
        }
    }

    private func countExercises(_ session: Session) -> Int {
        session.completedModules.reduce(0) { $0 + $1.completedExercises.count }
    }

    private struct ExerciseSummaryItem {
        let name: String
        let summary: String?
    }

    private func getTopExercises(_ session: Session, limit: Int) -> [ExerciseSummaryItem] {
        var exercises: [ExerciseSummaryItem] = []

        for module in session.completedModules {
            for exercise in module.completedExercises {
                let completedSets = exercise.completedSetGroups.flatMap { $0.sets.filter(\.completed) }
                guard !completedSets.isEmpty else { continue }

                // Generate summary based on first completed set
                var summary: String? = nil
                if let firstSet = completedSets.first {
                    if let weight = firstSet.weight, let reps = firstSet.reps, weight > 0 {
                        summary = "\(completedSets.count)×\(Int(weight))lbs"
                    } else if let reps = firstSet.reps, reps > 0 {
                        summary = "\(completedSets.count)×\(reps)"
                    }
                }

                exercises.append(ExerciseSummaryItem(name: exercise.exerciseName, summary: summary))

                if exercises.count >= limit {
                    return exercises
                }
            }
        }

        return exercises
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        } else {
            let minutes = totalSeconds / 60
            return "\(minutes)m"
        }
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
