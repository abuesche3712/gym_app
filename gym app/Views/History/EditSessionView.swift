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
    @State private var workoutName: String
    @State private var sessionDate: Date
    @State private var duration: Int
    @State private var overallFeeling: Int?
    @State private var notes: String
    @State private var selectedExerciseTarget: ExerciseEditTarget?

    init(session: Session) {
        self.session = session
        _editedSession = State(initialValue: session)
        _workoutName = State(initialValue: session.workoutName)
        _sessionDate = State(initialValue: session.date)
        _duration = State(initialValue: session.duration ?? 0)
        _overallFeeling = State(initialValue: session.overallFeeling)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    sessionInfoCard
                    notesCard
                    modulesCard
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
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
            .sheet(item: $selectedExerciseTarget) { target in
                EditExerciseSheet(
                    exercise: target.exercise,
                    moduleIndex: target.moduleIndex,
                    exerciseIndex: target.exerciseIndex,
                    onSave: { moduleIndex, exerciseIndex, updatedExercise in
                        editedSession.completedModules[moduleIndex].completedExercises[exerciseIndex] = updatedExercise
                    }
                )
            }
        }
    }

    private func saveChanges() {
        var updated = editedSession
        updated.workoutName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? session.workoutName
            : workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.date = sessionDate
        updated.duration = duration > 0 ? duration : nil
        updated.overallFeeling = overallFeeling
        updated.notes = notes.isEmpty ? nil : notes

        sessionViewModel.updateSession(updated)
        dismiss()
    }

    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Session Info")
                .smallCapsLabel(color: AppColors.textSecondary)

            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Text("Name")
                        .subheadline(color: AppColors.textPrimary)
                    Spacer()
                    TextField("Session name", text: $workoutName)
                        .multilineTextAlignment(.trailing)
                        .subheadline(color: AppColors.textPrimary)
                }

                Divider()

                DatePicker("Date", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                    .tint(AppColors.dominant)
                    .subheadline(color: AppColors.textPrimary)

                Divider()

                HStack(spacing: AppSpacing.md) {
                    Text("Duration")
                        .subheadline(color: AppColors.textPrimary)
                    Spacer()
                    HStack(spacing: AppSpacing.xs) {
                        TextField("0", value: $duration, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                            .subheadline(color: AppColors.textPrimary)
                        Text("min")
                            .caption(color: AppColors.textTertiary)
                    }
                }

                Divider()

                HStack(spacing: AppSpacing.md) {
                    Text("Feeling")
                        .subheadline(color: AppColors.textPrimary)
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
                    .tint(AppColors.dominant)
                }
            }
        }
        .flatCardStyle()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Notes")
                .smallCapsLabel(color: AppColors.textSecondary)

            TextField("Session notes", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceTertiary.opacity(0.45))
                )
                .subheadline(color: AppColors.textPrimary)
        }
        .flatCardStyle()
    }

    private var modulesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Exercises")
                .smallCapsLabel(color: AppColors.textSecondary)

            ForEach(Array(editedSession.completedModules.enumerated()), id: \.element.id) { moduleIndex, module in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: module.moduleType.icon)
                            .subheadline(color: AppColors.moduleColor(module.moduleType))
                        Text(module.moduleName)
                            .subheadline(color: AppColors.textPrimary)
                            .fontWeight(.semibold)
                    }

                    VStack(spacing: AppSpacing.xs) {
                        ForEach(Array(module.completedExercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                            EditableExerciseRow(
                                exercise: exercise,
                                onTap: {
                                    selectedExerciseTarget = ExerciseEditTarget(
                                        moduleIndex: moduleIndex,
                                        exerciseIndex: exerciseIndex,
                                        exercise: exercise
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceTertiary.opacity(0.4))
                )
            }
        }
        .flatCardStyle()
    }
}

private struct ExerciseEditTarget: Identifiable {
    let moduleIndex: Int
    let exerciseIndex: Int
    let exercise: SessionExercise

    var id: String {
        "\(moduleIndex)-\(exerciseIndex)-\(exercise.id)"
    }
}

// MARK: - Editable Exercise Row

struct EditableExerciseRow: View {
    let exercise: SessionExercise
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .subheadline(color: AppColors.textPrimary)
                        .fontWeight(.medium)

                    Text(exerciseSummary)
                        .caption(color: AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .caption(color: AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.surfacePrimary)
        )
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
        overallFeeling: 8,
        notes: "Great session!"
    ))
    .environmentObject(SessionViewModel())
}
