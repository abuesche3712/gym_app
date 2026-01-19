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

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(exercise.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(totalSets) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded set editing
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.element.id) { groupIndex, setGroup in
                        if setGroup.isInterval {
                            // Interval sets (simplified view)
                            HStack {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Interval: \(setGroup.rounds) rounds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            ForEach(Array(setGroup.sets.enumerated()), id: \.element.id) { setIndex, setData in
                                EditableSetRow(
                                    setData: setData,
                                    exerciseType: exercise.exerciseType,
                                    isBodyweight: exercise.isBodyweight,
                                    distanceUnit: exercise.distanceUnit,
                                    onChange: { updatedSet in
                                        var updatedExercise = exercise
                                        updatedExercise.completedSetGroups[groupIndex].sets[setIndex] = updatedSet
                                        onChange(updatedExercise)
                                    }
                                )
                            }
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
}

// MARK: - Editable Set Row

struct EditableSetRow: View {
    let setData: SetData
    let exerciseType: ExerciseType
    let isBodyweight: Bool
    let distanceUnit: DistanceUnit
    let onChange: (SetData) -> Void

    @State private var weight: Double
    @State private var reps: Int
    @State private var rpe: Int?
    @State private var duration: Int
    @State private var holdTime: Int
    @State private var distance: Double

    init(setData: SetData, exerciseType: ExerciseType, isBodyweight: Bool, distanceUnit: DistanceUnit, onChange: @escaping (SetData) -> Void) {
        self.setData = setData
        self.exerciseType = exerciseType
        self.isBodyweight = isBodyweight
        self.distanceUnit = distanceUnit
        self.onChange = onChange

        _weight = State(initialValue: setData.weight ?? 0)
        _reps = State(initialValue: setData.reps ?? 0)
        _rpe = State(initialValue: setData.rpe)
        _duration = State(initialValue: setData.duration ?? 0)
        _holdTime = State(initialValue: setData.holdTime ?? 0)
        _distance = State(initialValue: setData.distance ?? 0)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Set number badge
            Text("\(setData.setNumber)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(.systemGray5)))

            // Fields based on exercise type
            switch exerciseType {
            case .strength:
                strengthFields
            case .cardio:
                cardioFields
            case .isometric:
                isometricFields
            case .explosive:
                explosiveFields
            case .mobility:
                mobilityFields
            case .recovery:
                recoveryFields
            }

            // Completed indicator
            if setData.completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .onChange(of: weight) { _, _ in updateSet() }
        .onChange(of: reps) { _, _ in updateSet() }
        .onChange(of: rpe) { _, _ in updateSet() }
        .onChange(of: duration) { _, _ in updateSet() }
        .onChange(of: holdTime) { _, _ in updateSet() }
        .onChange(of: distance) { _, _ in updateSet() }
    }

    @ViewBuilder
    private var strengthFields: some View {
        if !isBodyweight {
            compactTextField("Weight", value: $weight, unit: "lbs")
        }
        compactIntField("Reps", value: $reps)
        compactIntPicker("RPE", value: Binding(
            get: { rpe ?? 0 },
            set: { rpe = $0 == 0 ? nil : $0 }
        ), range: 0...10)
    }

    @ViewBuilder
    private var cardioFields: some View {
        compactIntField("Time", value: $duration, unit: "s")
        compactTextField("Dist", value: $distance, unit: distanceUnit.abbreviation)
    }

    @ViewBuilder
    private var isometricFields: some View {
        compactIntField("Hold", value: $holdTime, unit: "s")
    }

    @ViewBuilder
    private var explosiveFields: some View {
        compactIntField("Reps", value: $reps)
    }

    @ViewBuilder
    private var mobilityFields: some View {
        compactIntField("Reps", value: $reps)
        compactIntField("Time", value: $duration, unit: "s")
    }

    @ViewBuilder
    private var recoveryFields: some View {
        compactIntField("Time", value: $duration, unit: "s")
    }

    private func compactTextField(_ label: String, value: Binding<Double>, unit: String? = nil) -> some View {
        HStack(spacing: 2) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            if let unit = unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func compactIntField(_ label: String, value: Binding<Int>, unit: String? = nil) -> some View {
        HStack(spacing: 2) {
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 40)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            if let unit = unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func compactIntPicker(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Picker(label, selection: value) {
            Text("-").tag(0)
            ForEach(Array(range.dropFirst()), id: \.self) { val in
                Text("\(val)").tag(val)
            }
        }
        .pickerStyle(.menu)
        .font(.caption)
    }

    private func updateSet() {
        var updated = setData
        updated.weight = weight > 0 ? weight : nil
        updated.reps = reps > 0 ? reps : nil
        updated.rpe = rpe
        updated.duration = duration > 0 ? duration : nil
        updated.holdTime = holdTime > 0 ? holdTime : nil
        updated.distance = distance > 0 ? distance : nil
        onChange(updated)
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
