//
//  SessionDetailView.swift
//  gym app
//
//  Detailed view of a completed session
//

import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            // Session Summary
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(session.workoutName)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label(session.formattedDate, systemImage: "calendar")

                        if let duration = session.formattedDuration {
                            Label(duration, systemImage: "clock")
                        }

                        if let feeling = session.overallFeeling {
                            Label(feelingText(feeling), systemImage: "face.smiling")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }

            // Notes
            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }

            // Completed Modules
            ForEach(session.completedModules) { completedModule in
                Section {
                    // Module header
                    HStack {
                        Image(systemName: completedModule.moduleType.icon)
                            .foregroundStyle(completedModule.moduleType.color)
                        Text(completedModule.moduleName)
                            .fontWeight(.semibold)

                        Spacer()

                        if completedModule.skipped {
                            Text("Skipped")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if !completedModule.skipped {
                        // Exercises
                        ForEach(completedModule.completedExercises) { exercise in
                            ExerciseResultView(exercise: exercise)
                        }
                    }
                }
            }

            // Statistics
            Section("Statistics") {
                LabeledContent("Total Sets", value: "\(session.totalSetsCompleted)")
                LabeledContent("Total Exercises", value: "\(session.totalExercisesCompleted)")

                let totalVolume = session.completedModules
                    .flatMap { $0.completedExercises }
                    .reduce(0.0) { $0 + $1.totalVolume }

                if totalVolume > 0 {
                    LabeledContent("Total Volume", value: "\(Int(totalVolume)) lbs")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                sessionViewModel.deleteSession(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this workout from your history. This action cannot be undone.")
        }
    }

    private func feelingText(_ feeling: Int) -> String {
        switch feeling {
        case 1: return "Terrible"
        case 2: return "Poor"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "N/A"
        }
    }
}

// MARK: - Exercise Result View

struct ExerciseResultView: View {
    let exercise: SessionExercise

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name and summary
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Summary based on exercise type
                        if let summary = exerciseSummary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(setsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded set details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(exercise.completedSetGroups) { setGroup in
                        if setGroup.isInterval {
                            // Interval set group - show as a single row
                            intervalResultRow(setGroup)
                        } else {
                            ForEach(setGroup.sets) { set in
                                setResultRow(set)
                            }
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Summary Helpers

    private var setsLabel: String {
        let intervalCount = exercise.completedSetGroups.filter { $0.isInterval }.count
        let regularSets = exercise.completedSetGroups.filter { !$0.isInterval }.reduce(0) { $0 + $1.sets.count }

        if intervalCount > 0 && regularSets > 0 {
            return "\(regularSets) sets + \(intervalCount) interval\(intervalCount > 1 ? "s" : "")"
        } else if intervalCount > 0 {
            let totalRounds = exercise.completedSetGroups.filter { $0.isInterval }.reduce(0) { $0 + $1.rounds }
            return "\(totalRounds) rounds"
        } else {
            return "\(regularSets) sets"
        }
    }

    /// Get appropriate summary for the exercise type
    private var exerciseSummary: String? {
        switch exercise.exerciseType {
        case .strength:
            // Show top set for strength
            if exercise.isBodyweight {
                // For bodyweight, show top added weight or just best reps
                if let topSet = exercise.topSet, let reps = topSet.reps {
                    if let weight = topSet.weight, weight > 0 {
                        var result = "Top: BW + \(formatWeight(weight)) × \(reps)"
                        if let rpe = topSet.rpe { result += " @ RPE \(rpe)" }
                        return result
                    } else {
                        // Just bodyweight
                        let allSets = exercise.completedSetGroups.flatMap { $0.sets }
                        if let maxReps = allSets.compactMap({ $0.reps }).max() {
                            return "Best: BW × \(maxReps)"
                        }
                    }
                }
            } else if let topSet = exercise.topSet, let weight = topSet.weight, let reps = topSet.reps {
                var result = "Top: \(formatWeight(weight)) × \(reps)"
                if let rpe = topSet.rpe {
                    result += " @ RPE \(rpe)"
                }
                return result
            }

        case .cardio:
            // Show total distance or best time
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            let totalDistance = allSets.compactMap { $0.distance }.reduce(0, +)
            let totalDuration = allSets.compactMap { $0.duration }.reduce(0, +)

            var parts: [String] = []
            if totalDistance > 0 {
                parts.append("\(formatDistance(totalDistance))\(exercise.distanceUnit.abbreviation)")
            }
            if totalDuration > 0 {
                parts.append(formatDuration(totalDuration))
            }
            return parts.isEmpty ? nil : parts.joined(separator: " in ")

        case .isometric:
            // Show longest hold
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            if let longestHold = allSets.compactMap({ $0.holdTime }).max() {
                return "Best: \(formatDuration(longestHold)) hold"
            }

        case .explosive:
            // Show best height or total reps
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            if let bestHeight = allSets.compactMap({ $0.height }).max() {
                return "Best: \(formatHeight(bestHeight))"
            } else {
                let totalReps = allSets.compactMap { $0.reps }.reduce(0, +)
                if totalReps > 0 {
                    return "\(totalReps) total reps"
                }
            }

        case .mobility:
            // Show total reps
            let totalReps = exercise.completedSetGroups.flatMap { $0.sets }.compactMap { $0.reps }.reduce(0, +)
            if totalReps > 0 {
                return "\(totalReps) total reps"
            }

        case .recovery:
            // Show total time and activity type
            let allSets = exercise.completedSetGroups.flatMap { $0.sets }
            let totalDuration = allSets.compactMap { $0.duration }.reduce(0, +)
            if totalDuration > 0 {
                var result = formatDuration(totalDuration)
                if let activityType = exercise.recoveryActivityType {
                    result = "\(activityType.displayName): \(result)"
                }
                return result
            }
        }

        // Check for intervals
        let intervalGroups = exercise.completedSetGroups.filter { $0.isInterval }
        if !intervalGroups.isEmpty {
            let totalRounds = intervalGroups.reduce(0) { $0 + $1.rounds }
            if let first = intervalGroups.first, let work = first.workDuration, let rest = first.intervalRestDuration {
                return "\(totalRounds) rounds × \(formatDuration(work))/\(formatDuration(rest))"
            }
        }

        return nil
    }

    // MARK: - Row Views

    @ViewBuilder
    private func setResultRow(_ set: SetData) -> some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            if let formatted = formattedSetResult(set) {
                Text(formatted)
                    .font(.caption)
            }

            if !set.completed {
                Text("(incomplete)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func intervalResultRow(_ setGroup: CompletedSetGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Interval")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                Text("\(setGroup.rounds) rounds")
                    .font(.caption)
                    .fontWeight(.medium)

                if let work = setGroup.workDuration, let rest = setGroup.intervalRestDuration {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(formatDuration(work)) work / \(formatDuration(rest)) rest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Formatting

    /// Format set result based on exercise type
    private func formattedSetResult(_ set: SetData) -> String? {
        switch exercise.exerciseType {
        case .strength:
            if exercise.isBodyweight {
                // Bodyweight format: "BW + 25 × 10" or "BW × 10"
                if let reps = set.reps {
                    if let weight = set.weight, weight > 0 {
                        var result = "BW + \(formatWeight(weight)) × \(reps)"
                        if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                        return result
                    } else {
                        var result = "BW × \(reps)"
                        if let rpe = set.rpe { result += " @ RPE \(rpe)" }
                        return result
                    }
                }
                return nil
            }
            // Regular weight format: Weight × reps @ RPE
            if let weight = set.weight, let reps = set.reps {
                var result = "\(formatWeight(weight)) × \(reps)"
                if let rpe = set.rpe {
                    result += " @ RPE \(rpe)"
                }
                return result
            }
            // Fallback to just reps if no weight
            if let reps = set.reps {
                var result = "\(reps) reps"
                if let rpe = set.rpe {
                    result += " @ RPE \(rpe)"
                }
                return result
            }

        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistance(distance))\(exercise.distanceUnit.abbreviation)")
            }
            if let pace = set.pace, pace > 0 {
                parts.append("@ \(formatPace(pace))/\(exercise.distanceUnit.abbreviation)")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " - ")

        case .isometric:
            if let holdTime = set.holdTime {
                var result = formatDuration(holdTime) + " hold"
                if let intensity = set.intensity {
                    result += " @ \(intensity)/10"
                }
                return result
            }

        case .explosive:
            var parts: [String] = []
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if let height = set.height {
                parts.append("@ \(formatHeight(height))")
            }
            if let quality = set.quality {
                parts.append("quality \(quality)/5")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " ")

        case .mobility:
            if let reps = set.reps {
                var result = "\(reps) reps"
                if let duration = set.duration, duration > 0 {
                    result += " (\(formatDuration(duration)))"
                }
                return result
            }

        case .recovery:
            if let duration = set.duration {
                var result = formatDuration(duration)
                if let temp = set.temperature {
                    result += " @ \(temp)°F"
                }
                return result
            }
        }

        return nil
    }

    // formatDistance() and formatWeight() use global FormattingHelpers

    private func formatHeight(_ height: Double) -> String {
        if height == floor(height) {
            return "\(Int(height)) in"
        }
        return String(format: "%.1f in", height)
    }

    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: Session(
            workoutId: UUID(),
            workoutName: "Monday - Lower A",
            duration: 75,
            overallFeeling: 4,
            notes: "Great session, PR on squats!"
        ))
        .environmentObject(SessionViewModel())
    }
}
