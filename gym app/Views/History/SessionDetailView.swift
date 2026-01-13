//
//  SessionDetailView.swift
//  gym app
//
//  Detailed view of a completed session
//

import SwiftUI

struct SessionDetailView: View {
    let session: Session

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
                            .foregroundStyle(Color(completedModule.moduleType.color))
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

                        // Best set summary
                        if let topSet = exercise.topSet, let formatted = topSet.formattedStrength {
                            Text("Top: \(formatted)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(totalSets) sets")
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
                        ForEach(setGroup.sets) { set in
                            setResultRow(set)
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }

    private var totalSets: Int {
        exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
    }

    @ViewBuilder
    private func setResultRow(_ set: SetData) -> some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            if let formatted = set.formattedStrength ?? set.formattedIsometric ?? set.formattedCardio {
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
    }
}
