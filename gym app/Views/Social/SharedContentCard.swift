//
//  SharedContentCard.swift
//  gym app
//
//  Card component for displaying shared content in chat messages
//  Uses consistent patterns with PostCard attachments
//

import SwiftUI

struct SharedContentCard: View {
    let content: MessageContent
    let isFromCurrentUser: Bool
    let onImport: (() -> Void)?
    let onView: (() -> Void)?

    init(content: MessageContent, isFromCurrentUser: Bool, onImport: (() -> Void)? = nil, onView: (() -> Void)? = nil) {
        self.content = content
        self.isFromCurrentUser = isFromCurrentUser
        self.onImport = onImport
        self.onView = onView
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header with icon and type
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                Text(contentType)
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(typeColor)

            // Content name
            Text(contentName)
                .font(.headline.weight(.semibold))
                .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                .lineLimit(2)

            // Subtitle if available
            if let subtitle = contentSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : AppColors.textSecondary)
            }

            // Stats for workouts/sessions
            if let stats = contentStats {
                HStack(spacing: AppSpacing.md) {
                    ForEach(stats.indices, id: \.self) { index in
                        let stat = stats[index]
                        HStack(spacing: 4) {
                            Text(stat.value)
                                .font(.subheadline.weight(.semibold))
                            Text(stat.label)
                                .font(.caption)
                        }
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.9) : AppColors.textSecondary)
                    }
                }
                .padding(.top, 2)
            }

            // Action buttons (only for received messages with importable content)
            if !isFromCurrentUser && content.isImportable {
                HStack(spacing: AppSpacing.sm) {
                    if let onView = onView {
                        Button(action: onView) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                Text("View")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.dominant)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(AppColors.dominant.opacity(0.12))
                            .cornerRadius(AppCorners.small)
                        }
                    }

                    if let onImport = onImport {
                        Button(action: onImport) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(AppColors.dominant)
                            .cornerRadius(AppCorners.small)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    // MARK: - Background

    private var cardBackground: some View {
        Group {
            if isFromCurrentUser {
                AppColors.dominant
            } else {
                typeColor.opacity(0.06)
            }
        }
    }

    private var borderColor: Color {
        if isFromCurrentUser {
            return AppColors.dominant.opacity(0.8)
        } else {
            return typeColor.opacity(0.15)
        }
    }

    private var typeColor: Color {
        if isFromCurrentUser { return .white.opacity(0.9) }

        switch content {
        case .sharedProgram:
            return AppColors.dominant
        case .sharedWorkout:
            return AppColors.dominant
        case .sharedModule:
            return AppColors.accent3
        case .sharedSession:
            return AppColors.success
        case .sharedExercise:
            return AppColors.dominant
        case .sharedSet(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot), bundle.isPR {
                return AppColors.warning
            }
            return AppColors.accent2
        case .sharedCompletedModule:
            return AppColors.success
        case .text:
            return AppColors.textSecondary
        }
    }

    // MARK: - Icon

    private var iconName: String {
        switch content {
        case .sharedProgram:
            return "doc.text.fill"
        case .sharedWorkout:
            return "figure.run"
        case .sharedModule:
            return "square.stack.3d.up.fill"
        case .sharedSession:
            return "checkmark.circle.fill"
        case .sharedExercise:
            return "dumbbell.fill"
        case .sharedSet(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot), bundle.isPR {
                return "trophy.fill"
            }
            return "flame.fill"
        case .sharedCompletedModule:
            return "checkmark.circle.fill"
        case .text:
            return "text.bubble"
        }
    }

    // MARK: - Content Type

    private var contentType: String {
        switch content {
        case .sharedProgram:
            return "PROGRAM"
        case .sharedWorkout:
            return "WORKOUT"
        case .sharedModule:
            return "MODULE"
        case .sharedSession:
            return "COMPLETED"
        case .sharedExercise:
            return "EXERCISE"
        case .sharedSet(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot), bundle.isPR {
                return "NEW PR"
            }
            return "SET"
        case .sharedCompletedModule:
            return "MODULE"
        case .text:
            return "MESSAGE"
        }
    }

    // MARK: - Content Name

    private var contentName: String {
        switch content {
        case .sharedProgram(_, let name, _):
            return name
        case .sharedWorkout(_, let name, _):
            return name
        case .sharedModule(_, let name, _):
            return name
        case .sharedSession(_, let workoutName, _, _):
            return workoutName
        case .sharedExercise(let snapshot):
            if let bundle = try? ExerciseShareBundle.decode(from: snapshot) {
                return bundle.exerciseName
            }
            return "Exercise"
        case .sharedSet(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot) {
                return bundle.exerciseName
            }
            return "Set"
        case .sharedCompletedModule(let snapshot):
            if let bundle = try? CompletedModuleShareBundle.decode(from: snapshot) {
                return bundle.module.moduleName
            }
            return "Module"
        case .text(let text):
            return text
        }
    }

    // MARK: - Content Subtitle

    private var contentSubtitle: String? {
        switch content {
        case .sharedProgram(_, _, let snapshot):
            if let bundle = try? ProgramShareBundle.decode(from: snapshot) {
                return "\(bundle.program.durationWeeks) weeks · \(bundle.workouts.count) workouts"
            }
            return nil
        case .sharedWorkout(_, _, let snapshot):
            if let bundle = try? WorkoutShareBundle.decode(from: snapshot) {
                let exerciseCount = bundle.modules.reduce(0) { $0 + $1.exercises.count }
                return "\(bundle.modules.count) modules · \(exerciseCount) exercises"
            }
            return nil
        case .sharedModule(_, _, let snapshot):
            if let bundle = try? ModuleShareBundle.decode(from: snapshot) {
                return "\(bundle.module.exercises.count) exercises"
            }
            return nil
        case .sharedSession(_, _, let date, _):
            return date.formatted(date: .abbreviated, time: .omitted)
        case .sharedExercise(let snapshot):
            if let bundle = try? ExerciseShareBundle.decode(from: snapshot) {
                return "\(bundle.setData.count) sets · \(bundle.date.formatted(date: .abbreviated, time: .omitted))"
            }
            return nil
        case .sharedSet(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot) {
                return formatSetData(bundle.setData)
            }
            return nil
        case .sharedCompletedModule(let snapshot):
            if let bundle = try? CompletedModuleShareBundle.decode(from: snapshot) {
                let exerciseCount = bundle.module.completedExercises.count
                return "\(exerciseCount) exercises · \(bundle.date.formatted(date: .abbreviated, time: .omitted))"
            }
            return nil
        case .text:
            return nil
        }
    }

    // MARK: - Content Stats

    private var contentStats: [(value: String, label: String)]? {
        switch content {
        case .sharedSession(_, _, _, let snapshot):
            if let bundle = try? SessionShareBundle.decode(from: snapshot) {
                let session = bundle.session
                var stats: [(String, String)] = []

                let setCount = session.completedModules.reduce(0) { moduleTotal, module in
                    moduleTotal + module.completedExercises.reduce(0) { exerciseTotal, exercise in
                        exerciseTotal + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
                    }
                }
                stats.append(("\(setCount)", "sets"))

                let exerciseCount = session.completedModules.reduce(0) { $0 + $1.completedExercises.count }
                stats.append(("\(exerciseCount)", "exercises"))

                if let duration = session.duration {
                    stats.append(("\(duration)", "min"))
                }

                return stats
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private func formatSetData(_ setData: SetData) -> String {
        var parts: [String] = []

        if let weight = setData.weight, let reps = setData.reps {
            parts.append("\(Int(weight)) × \(reps)")
        } else if let duration = setData.duration {
            let minutes = duration / 60
            let seconds = duration % 60
            if minutes > 0 {
                parts.append("\(minutes)m \(seconds)s")
            } else {
                parts.append("\(seconds)s")
            }
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Previews

#Preview("Sent Program") {
    VStack {
        SharedContentCard(
            content: .sharedProgram(id: UUID(), name: "Push Pull Legs", snapshot: Data()),
            isFromCurrentUser: true
        )
        .padding()
    }
    .background(AppColors.background)
}

#Preview("Received Workout") {
    VStack {
        SharedContentCard(
            content: .sharedWorkout(id: UUID(), name: "Monday Upper", snapshot: Data()),
            isFromCurrentUser: false,
            onImport: {},
            onView: {}
        )
        .padding()
    }
    .background(AppColors.background)
}
