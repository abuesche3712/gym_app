//
//  SharedContentCard.swift
//  gym app
//
//  Card component for displaying shared content in chat messages
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
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : AppColors.dominant)

            // Content name
            Text(contentName)
                .headline(color: isFromCurrentUser ? .white : AppColors.textPrimary)

            // Subtitle if available
            if let subtitle = contentSubtitle {
                Text(subtitle)
                    .caption(color: isFromCurrentUser ? .white.opacity(0.7) : AppColors.textSecondary)
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
                            .background(AppColors.dominant.opacity(0.15))
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
                .padding(.top, 4)
            }
        }
        .padding(AppSpacing.md)
        .background(cardBackground)
        .cornerRadius(AppCorners.medium)
    }

    private var cardBackground: some View {
        Group {
            if isFromCurrentUser {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.dominant.opacity(0.8))
            } else {
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .stroke(AppColors.dominant.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

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
        case .sharedSet:
            return "flame.fill"
        case .sharedCompletedModule:
            return "square.stack.3d.up.fill"
        case .text:
            return "text.bubble"
        }
    }

    private var contentType: String {
        switch content {
        case .sharedProgram:
            return "PROGRAM"
        case .sharedWorkout:
            return "WORKOUT"
        case .sharedModule:
            return "MODULE"
        case .sharedSession:
            return "COMPLETED WORKOUT"
        case .sharedExercise:
            return "EXERCISE"
        case .sharedSet:
            return "PERSONAL BEST"
        case .sharedCompletedModule:
            return "COMPLETED MODULE"
        case .text:
            return "MESSAGE"
        }
    }

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

    private var contentSubtitle: String? {
        switch content {
        case .sharedProgram(_, _, let snapshot):
            if let bundle = try? ProgramShareBundle.decode(from: snapshot) {
                let count = bundle.workouts.count
                return "\(count) workout\(count == 1 ? "" : "s")"
            }
            return nil
        case .sharedWorkout(_, _, let snapshot):
            if let bundle = try? WorkoutShareBundle.decode(from: snapshot) {
                let count = bundle.modules.count
                return "\(count) module\(count == 1 ? "" : "s")"
            }
            return nil
        case .sharedModule(_, _, let snapshot):
            if let bundle = try? ModuleShareBundle.decode(from: snapshot) {
                let count = bundle.module.exercises.count
                return "\(count) exercise\(count == 1 ? "" : "s")"
            }
            return nil
        case .sharedSession(_, _, let date, _):
            return date.formatted(date: .abbreviated, time: .omitted)
        case .sharedExercise(let snapshot):
            if let bundle = try? ExerciseShareBundle.decode(from: snapshot) {
                return "\(bundle.setData.count) sets"
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
                return "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
            }
            return nil
        case .text:
            return nil
        }
    }

    private func formatSetData(_ setData: SetData) -> String {
        var parts: [String] = []

        if let weight = setData.weight {
            parts.append("\(Int(weight)) lbs")
        }
        if let reps = setData.reps {
            parts.append("\(reps) reps")
        }
        if let duration = setData.duration {
            let minutes = duration / 60
            let seconds = duration % 60
            if minutes > 0 {
                parts.append("\(minutes)m \(seconds)s")
            } else {
                parts.append("\(seconds)s")
            }
        }

        return parts.joined(separator: " × ")
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
