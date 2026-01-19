//
//  EditSessionView.swift
//  gym app
//
//  View for editing a completed session (within 30 days)
//

import SwiftUI

struct EditSessionView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @State private var editedSession: Session
    @State private var sessionDate: Date
    @State private var duration: Int
    @State private var overallFeeling: Int?
    @State private var notes: String

    init(session: Session) {
        self.session = session
        _editedSession = State(initialValue: session)
        _sessionDate = State(initialValue: session.date)
        _duration = State(initialValue: session.duration ?? 0)
        _overallFeeling = State(initialValue: session.overallFeeling)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                // Session Info Section
                Section("Session Info") {
                    DatePicker("Date", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("Minutes", value: $duration, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("min")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Feeling")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { overallFeeling ?? 0 },
                            set: { overallFeeling = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Not set").tag(0)
                            ForEach(1...10, id: \.self) { value in
                                Text("\(value)/10").tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Notes Section
                Section("Notes") {
                    TextField("Session notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Exercises Section
                ForEach(Array(editedSession.completedModules.enumerated()), id: \.element.id) { moduleIndex, module in
                    Section {
                        HStack {
                            Image(systemName: module.moduleType.icon)
                                .foregroundStyle(module.moduleType.color)
                            Text(module.moduleName)
                                .fontWeight(.semibold)
                        }

                        ForEach(Array(module.completedExercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                            EditableExerciseRow(
                                exercise: exercise,
                                onChange: { updatedExercise in
                                    editedSession.completedModules[moduleIndex].completedExercises[exerciseIndex] = updatedExercise
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        var updated = editedSession
        updated.date = sessionDate
        updated.duration = duration > 0 ? duration : nil
        updated.overallFeeling = overallFeeling
        updated.notes = notes.isEmpty ? nil : notes

        sessionViewModel.updateSession(updated)
        dismiss()
    }
}

// MARK: - Editable Exercise Row

struct EditableExerciseRow: View {
    let exercise: SessionExercise
    let onChange: (SessionExercise) -> Void

    @State private var showEditSheet = false

    var body: some View {
        Button {
            showEditSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(exerciseSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .sheet(isPresented: $showEditSheet) {
            EditExerciseSheet(
                exercise: exercise,
                moduleIndex: 0,  // Not used for history editing
                exerciseIndex: 0,  // Not used for history editing
                onSave: { _, _, updatedExercise in
                    onChange(updatedExercise)
                }
            )
        }
    }

    private var exerciseSummary: String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }.count

        switch exercise.exerciseType {
        case .strength:
            let firstSet = exercise.completedSetGroups.flatMap { $0.sets }.first { $0.completed }
            if let weight = firstSet?.weight, let reps = firstSet?.reps {
                return "\(completedSets)/\(totalSets) sets · \(formatWeight(weight)) lbs × \(reps)"
            }
            return "\(completedSets)/\(totalSets) sets"
        case .cardio:
            let firstSet = exercise.completedSetGroups.flatMap { $0.sets }.first { $0.completed }
            if let duration = firstSet?.duration, duration > 0 {
                return "\(completedSets)/\(totalSets) sets · \(formatDuration(duration))"
            }
            return "\(completedSets)/\(totalSets) sets"
        case .isometric:
            let firstSet = exercise.completedSetGroups.flatMap { $0.sets }.first { $0.completed }
            if let holdTime = firstSet?.holdTime, holdTime > 0 {
                return "\(completedSets)/\(totalSets) sets · \(holdTime)s hold"
            }
            return "\(completedSets)/\(totalSets) sets"
        default:
            return "\(completedSets)/\(totalSets) sets completed"
        }
    }
}

#Preview {
    EditSessionView(session: Session(
        workoutId: UUID(),
        workoutName: "Monday - Lower A",
        duration: 75,
        overallFeeling: 4,
        notes: "Great session!"
    ))
    .environmentObject(SessionViewModel())
}
