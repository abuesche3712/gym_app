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
    @State private var expandedExerciseKeys: Set<String> = []
    @State private var editHistory: [EditSnapshot] = []

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
                    editActionsCard
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
        }
    }

    private var initialSnapshot: EditSnapshot {
        EditSnapshot(
            session: session,
            workoutName: session.workoutName,
            sessionDate: session.date,
            duration: session.duration ?? 0,
            overallFeeling: session.overallFeeling,
            notes: session.notes ?? ""
        )
    }

    private var currentSnapshot: EditSnapshot {
        EditSnapshot(
            session: editedSession,
            workoutName: workoutName,
            sessionDate: sessionDate,
            duration: duration,
            overallFeeling: overallFeeling,
            notes: notes
        )
    }

    private var hasUnsavedChanges: Bool {
        currentSnapshot != initialSnapshot
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

    private func pushUndoSnapshot() {
        let snapshot = currentSnapshot
        if editHistory.last != snapshot {
            editHistory.append(snapshot)
            if editHistory.count > 120 {
                editHistory.removeFirst(editHistory.count - 120)
            }
        }
    }

    private func undoLastChange() {
        guard let last = editHistory.popLast() else { return }
        apply(snapshot: last)
    }

    private func revertAllChanges() {
        apply(snapshot: initialSnapshot)
        editHistory.removeAll()
    }

    private func apply(snapshot: EditSnapshot) {
        editedSession = snapshot.session
        workoutName = snapshot.workoutName
        sessionDate = snapshot.sessionDate
        duration = snapshot.duration
        overallFeeling = snapshot.overallFeeling
        notes = snapshot.notes
    }

    private func mutateSession(_ mutate: (inout Session) -> Void) {
        pushUndoSnapshot()
        mutate(&editedSession)
    }

    private var workoutNameBinding: Binding<String> {
        Binding(
            get: { workoutName },
            set: { newValue in
                guard newValue != workoutName else { return }
                pushUndoSnapshot()
                workoutName = newValue
            }
        )
    }

    private var sessionDateBinding: Binding<Date> {
        Binding(
            get: { sessionDate },
            set: { newValue in
                guard newValue != sessionDate else { return }
                pushUndoSnapshot()
                sessionDate = newValue
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { duration },
            set: { newValue in
                guard newValue != duration else { return }
                pushUndoSnapshot()
                duration = max(0, newValue)
            }
        )
    }

    private var overallFeelingBinding: Binding<Int> {
        Binding(
            get: { overallFeeling ?? 0 },
            set: { newValue in
                let mapped: Int? = newValue == 0 ? nil : newValue
                guard mapped != overallFeeling else { return }
                pushUndoSnapshot()
                overallFeeling = mapped
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { notes },
            set: { newValue in
                guard newValue != notes else { return }
                pushUndoSnapshot()
                notes = newValue
            }
        )
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
                    TextField("Session name", text: workoutNameBinding)
                        .multilineTextAlignment(.trailing)
                        .subheadline(color: AppColors.textPrimary)
                }

                Divider()

                DatePicker("Date", selection: sessionDateBinding, displayedComponents: [.date, .hourAndMinute])
                    .tint(AppColors.dominant)
                    .subheadline(color: AppColors.textPrimary)

                Divider()

                HStack(spacing: AppSpacing.md) {
                    Text("Duration")
                        .subheadline(color: AppColors.textPrimary)
                    Spacer()
                    HStack(spacing: AppSpacing.xs) {
                        TextField("0", value: durationBinding, format: .number)
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
                    Picker("", selection: overallFeelingBinding) {
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

    private var editActionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Edit Actions")
                .smallCapsLabel(color: AppColors.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                Button {
                    undoLastChange()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .caption(color: editHistory.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.surfaceTertiary.opacity(0.45))
                        )
                }
                .buttonStyle(.plain)
                .disabled(editHistory.isEmpty)

                Button {
                    revertAllChanges()
                } label: {
                    Label("Revert All", systemImage: "arrow.counterclockwise")
                        .caption(color: hasUnsavedChanges ? AppColors.error : AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.error.opacity(hasUnsavedChanges ? 0.12 : 0.05))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasUnsavedChanges)
            }

            if hasUnsavedChanges {
                Text("Unsaved changes in this session. Save when done.")
                    .caption(color: AppColors.textTertiary)
            }
        }
        .flatCardStyle()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Notes")
                .smallCapsLabel(color: AppColors.textSecondary)

            TextField("Session notes", text: notesBinding, axis: .vertical)
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

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(module.completedExercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                            exerciseEditorCard(
                                moduleIndex: moduleIndex,
                                exerciseIndex: exerciseIndex,
                                exercise: exercise,
                                moduleType: module.moduleType
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

    private func exerciseEditorCard(
        moduleIndex: Int,
        exerciseIndex: Int,
        exercise: SessionExercise,
        moduleType: ModuleType
    ) -> some View {
        let key = exerciseKey(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex)
        let isExpanded = expandedExerciseKeys.contains(key)

        return VStack(spacing: 0) {
            Button {
                withAnimation(AppAnimation.quick) {
                    if isExpanded {
                        expandedExerciseKeys.remove(key)
                    } else {
                        expandedExerciseKeys.insert(key)
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.exerciseName)
                            .subheadline(color: AppColors.textPrimary)
                            .fontWeight(.medium)

                        Text(exerciseSummary(exercise))
                            .caption(color: AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .caption(color: AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(spacing: AppSpacing.sm) {
                    if exercise.exerciseType == .cardio, exercise.cardioMetric.tracksDistance {
                        cardioUnitRow(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, unit: exercise.distanceUnit)
                    }

                    ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.element.id) { groupIndex, group in
                        setGroupEditor(
                            moduleIndex: moduleIndex,
                            exerciseIndex: exerciseIndex,
                            groupIndex: groupIndex,
                            group: group,
                            exercise: exercise,
                            moduleType: moduleType
                        )
                    }
                }
                .padding(AppSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func cardioUnitRow(moduleIndex: Int, exerciseIndex: Int, unit: DistanceUnit) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text("Distance Unit")
                .caption(color: AppColors.textSecondary)

            Spacer()

            Menu {
                ForEach(DistanceUnit.allCases) { candidate in
                    Button {
                        updateDistanceUnit(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, unit: candidate)
                    } label: {
                        if candidate == unit {
                            Label(candidate.displayName, systemImage: "checkmark")
                        } else {
                            Text(candidate.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(unit.displayName)
                        .caption(color: AppColors.dominant)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .caption2(color: AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppColors.dominant.opacity(0.12))
                )
            }
        }
    }

    private func setGroupEditor(
        moduleIndex: Int,
        exerciseIndex: Int,
        groupIndex: Int,
        group: CompletedSetGroup,
        exercise: SessionExercise,
        moduleType: ModuleType
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Text("Set Group \(groupIndex + 1)")
                    .caption(color: AppColors.textSecondary)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: AppSpacing.xs) {
                    Button {
                        removeLastSet(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, groupIndex: groupIndex)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .subheadline(color: AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRemoveSet(from: group))

                    Text("\(logicalSetCount(in: group))")
                        .caption(color: AppColors.textSecondary)
                        .frame(minWidth: 18)

                    Button {
                        addSet(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, groupIndex: groupIndex)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .subheadline(color: AppColors.dominant)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(group.sets.enumerated()), id: \.element.id) { setIndex, _ in
                inlineSetEditorRow(
                    moduleIndex: moduleIndex,
                    exerciseIndex: exerciseIndex,
                    groupIndex: groupIndex,
                    setIndex: setIndex,
                    exercise: exercise,
                    moduleType: moduleType
                )
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.surfaceTertiary.opacity(0.35))
        )
    }

    private func inlineSetEditorRow(
        moduleIndex: Int,
        exerciseIndex: Int,
        groupIndex: Int,
        setIndex: Int,
        exercise: SessionExercise,
        moduleType: ModuleType
    ) -> some View {
        let setBinding = binding(moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, groupIndex: groupIndex, setIndex: setIndex)
        let set = setBinding.wrappedValue
        let warnings = validationWarnings(for: set, exercise: exercise)

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(set.completed ? AppColors.moduleColor(moduleType).opacity(0.15) : AppColors.surfaceTertiary)
                        .frame(width: 26, height: 26)

                    if set.completed {
                        Image(systemName: "checkmark")
                            .caption2(color: AppColors.moduleColor(moduleType))
                            .fontWeight(.bold)
                    } else {
                        Text("\(set.setNumber)")
                            .caption(color: AppColors.textSecondary)
                            .fontWeight(.semibold)
                    }
                }

                Text("Set \(set.setNumber)")
                    .caption(color: AppColors.textSecondary)

                if let side = set.side {
                    Text(side.abbreviation)
                        .caption(color: side == .left ? AppColors.dominant : AppColors.accent2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Toggle("", isOn: completedBinding(setBinding))
                    .labelsHidden()
                    .tint(AppColors.success)
                    .scaleEffect(0.86)
            }

            setInputs(for: exercise, setBinding: setBinding)

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .caption(color: AppColors.warning)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.small)
                .fill(AppColors.surfacePrimary)
        )
    }

    @ViewBuilder
    private func setInputs(for exercise: SessionExercise, setBinding: Binding<SetData>) -> some View {
        switch exercise.exerciseType {
        case .strength:
            HStack(spacing: AppSpacing.sm) {
                compactDoubleField(
                    title: exercise.isBodyweight ? "ADD WT" : "WEIGHT",
                    value: optionalDoubleBinding(setBinding, keyPath: \.weight),
                    unit: "lb"
                )
                compactIntField(title: "REPS", value: optionalIntBinding(setBinding, keyPath: \.reps))

                VStack(alignment: .leading, spacing: 2) {
                    Text("RPE")
                        .caption2(color: AppColors.textTertiary)
                    Picker("RPE", selection: optionalIntBinding(setBinding, keyPath: \.rpe, defaultValue: 0, nilWhenZero: true)) {
                        Text("--").tag(0)
                        ForEach(1...10, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

        case .cardio:
            HStack(spacing: AppSpacing.sm) {
                if exercise.cardioMetric.tracksTime {
                    compactIntField(title: "TIME", value: optionalIntBinding(setBinding, keyPath: \.duration), unit: "sec")
                }
                if exercise.cardioMetric.tracksDistance {
                    compactDoubleField(
                        title: "DIST",
                        value: optionalDoubleBinding(setBinding, keyPath: \.distance),
                        unit: exercise.distanceUnit.abbreviation
                    )
                }
            }

        case .isometric:
            HStack(spacing: AppSpacing.sm) {
                compactIntField(title: "HOLD", value: optionalIntBinding(setBinding, keyPath: \.holdTime), unit: "sec")
                compactIntField(title: "INT", value: optionalIntBinding(setBinding, keyPath: \.intensity))
            }

        case .explosive:
            HStack(spacing: AppSpacing.sm) {
                compactIntField(title: "REPS", value: optionalIntBinding(setBinding, keyPath: \.reps))
                compactDoubleField(title: "HEIGHT", value: optionalDoubleBinding(setBinding, keyPath: \.height), unit: "in")
            }

        case .mobility:
            HStack(spacing: AppSpacing.sm) {
                if exercise.mobilityTracking.tracksReps {
                    compactIntField(title: "REPS", value: optionalIntBinding(setBinding, keyPath: \.reps))
                }
                if exercise.mobilityTracking.tracksDuration {
                    compactIntField(title: "TIME", value: optionalIntBinding(setBinding, keyPath: \.duration), unit: "sec")
                }
            }

        case .recovery:
            HStack(spacing: AppSpacing.sm) {
                compactIntField(title: "TIME", value: optionalIntBinding(setBinding, keyPath: \.duration), unit: "sec")
                compactIntField(title: "TEMP", value: optionalIntBinding(setBinding, keyPath: \.temperature), unit: "F")
            }
        }
    }

    private func compactIntField(title: String, value: Binding<Int>, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .caption2(color: AppColors.textTertiary)
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                if let unit {
                    Text(unit)
                        .caption2(color: AppColors.textTertiary)
                }
            }
        }
    }

    private func compactDoubleField(title: String, value: Binding<Double>, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .caption2(color: AppColors.textTertiary)
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                if let unit {
                    Text(unit)
                        .caption2(color: AppColors.textTertiary)
                }
            }
        }
    }

    private func completedBinding(_ setBinding: Binding<SetData>) -> Binding<Bool> {
        Binding(
            get: { setBinding.wrappedValue.completed },
            set: { newValue in
                var updated = setBinding.wrappedValue
                updated.completed = newValue
                setBinding.wrappedValue = updated
            }
        )
    }

    private func optionalIntBinding(
        _ setBinding: Binding<SetData>,
        keyPath: WritableKeyPath<SetData, Int?>,
        defaultValue: Int = 0,
        nilWhenZero: Bool = true
    ) -> Binding<Int> {
        Binding(
            get: { setBinding.wrappedValue[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                var updated = setBinding.wrappedValue
                let mapped = nilWhenZero && newValue == 0 ? nil : max(0, newValue)
                updated[keyPath: keyPath] = mapped
                setBinding.wrappedValue = updated
            }
        )
    }

    private func optionalDoubleBinding(
        _ setBinding: Binding<SetData>,
        keyPath: WritableKeyPath<SetData, Double?>,
        defaultValue: Double = 0,
        nilWhenZero: Bool = true
    ) -> Binding<Double> {
        Binding(
            get: { setBinding.wrappedValue[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                var updated = setBinding.wrappedValue
                let sanitized = max(0, newValue)
                updated[keyPath: keyPath] = nilWhenZero && sanitized == 0 ? nil : sanitized
                setBinding.wrappedValue = updated
            }
        )
    }

    private func validationWarnings(for set: SetData, exercise: SessionExercise) -> [String] {
        var warnings: [String] = []

        if set.completed && !set.hasAnyMetricData {
            warnings.append("Completed set has no logged data.")
        }

        if let rpe = set.rpe, !(1...10).contains(rpe) {
            warnings.append("RPE should be between 1 and 10.")
        }

        switch exercise.exerciseType {
        case .strength:
            if set.completed, set.reps == nil {
                warnings.append("Strength set should usually include reps.")
            }

        case .cardio:
            let duration = set.duration ?? 0
            let distance = set.distance ?? 0
            if set.completed && duration <= 0 && distance <= 0 {
                warnings.append("Cardio set should include time, distance, or both.")
            }
            if distance > 0 {
                switch exercise.distanceUnit {
                case .miles where distance > 30:
                    warnings.append("Distance is high for miles. Check unit mismatch.")
                case .kilometers where distance > 50:
                    warnings.append("Distance is high for kilometers. Check unit mismatch.")
                case .meters where distance > 50_000:
                    warnings.append("Distance is high for meters. Check unit mismatch.")
                case .yards where distance > 55_000:
                    warnings.append("Distance is high for yards. Check unit mismatch.")
                default:
                    break
                }
            }

        case .isometric:
            if set.completed && (set.holdTime ?? 0) <= 0 {
                warnings.append("Isometric set should include hold time.")
            }

        case .explosive:
            if set.completed && (set.reps ?? 0) <= 0 {
                warnings.append("Explosive set should include reps.")
            }

        case .mobility:
            if set.completed && (set.reps ?? 0) <= 0 && (set.duration ?? 0) <= 0 {
                warnings.append("Mobility set should include reps or duration.")
            }

        case .recovery:
            if set.completed && (set.duration ?? 0) <= 0 {
                warnings.append("Recovery set should include duration.")
            }
        }

        return warnings
    }

    private func binding(moduleIndex: Int, exerciseIndex: Int, groupIndex: Int, setIndex: Int) -> Binding<SetData> {
        Binding(
            get: {
                guard editedSession.completedModules.indices.contains(moduleIndex),
                      editedSession.completedModules[moduleIndex].completedExercises.indices.contains(exerciseIndex),
                      editedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups.indices.contains(groupIndex),
                      editedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[groupIndex].sets.indices.contains(setIndex) else {
                    return SetData(setNumber: 1)
                }

                return editedSession.completedModules[moduleIndex]
                    .completedExercises[exerciseIndex]
                    .completedSetGroups[groupIndex]
                    .sets[setIndex]
            },
            set: { newValue in
                mutateSession { updatedSession in
                    guard updatedSession.completedModules.indices.contains(moduleIndex),
                          updatedSession.completedModules[moduleIndex].completedExercises.indices.contains(exerciseIndex),
                          updatedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups.indices.contains(groupIndex),
                          updatedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[groupIndex].sets.indices.contains(setIndex) else {
                        return
                    }

                    updatedSession.completedModules[moduleIndex]
                        .completedExercises[exerciseIndex]
                        .completedSetGroups[groupIndex]
                        .sets[setIndex] = newValue
                }
            }
        )
    }

    private func exerciseKey(moduleIndex: Int, exerciseIndex: Int) -> String {
        "\(moduleIndex)-\(exerciseIndex)"
    }

    private func logicalSetCount(in group: CompletedSetGroup) -> Int {
        if group.isUnilateral {
            return Set(group.sets.map(\.setNumber)).count
        }
        return group.sets.count
    }

    private func canRemoveSet(from group: CompletedSetGroup) -> Bool {
        logicalSetCount(in: group) > 1
    }

    private func addSet(moduleIndex: Int, exerciseIndex: Int, groupIndex: Int) {
        mutateSession { updatedSession in
            guard updatedSession.completedModules.indices.contains(moduleIndex),
                  updatedSession.completedModules[moduleIndex].completedExercises.indices.contains(exerciseIndex),
                  updatedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups.indices.contains(groupIndex) else {
                return
            }

            var group = updatedSession.completedModules[moduleIndex]
                .completedExercises[exerciseIndex]
                .completedSetGroups[groupIndex]

            let nextSetNumber = (group.sets.map(\.setNumber).max() ?? 0) + 1

            if group.isUnilateral {
                let leftTemplate = group.sets.last(where: { $0.side == .left }) ?? group.sets.last
                let rightTemplate = group.sets.last(where: { $0.side == .right }) ?? group.sets.last
                group.sets.append(makeNewSet(from: leftTemplate, setNumber: nextSetNumber, side: .left))
                group.sets.append(makeNewSet(from: rightTemplate, setNumber: nextSetNumber, side: .right))
            } else {
                group.sets.append(makeNewSet(from: group.sets.last, setNumber: nextSetNumber, side: nil))
            }

            updatedSession.completedModules[moduleIndex]
                .completedExercises[exerciseIndex]
                .completedSetGroups[groupIndex] = group
        }
    }

    private func removeLastSet(moduleIndex: Int, exerciseIndex: Int, groupIndex: Int) {
        mutateSession { updatedSession in
            guard updatedSession.completedModules.indices.contains(moduleIndex),
                  updatedSession.completedModules[moduleIndex].completedExercises.indices.contains(exerciseIndex),
                  updatedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups.indices.contains(groupIndex) else {
                return
            }

            var group = updatedSession.completedModules[moduleIndex]
                .completedExercises[exerciseIndex]
                .completedSetGroups[groupIndex]

            if group.isUnilateral {
                let logicalNumbers = Array(Set(group.sets.map(\.setNumber))).sorted()
                guard logicalNumbers.count > 1, let lastNumber = logicalNumbers.last else { return }
                group.sets.removeAll { $0.setNumber == lastNumber }
            } else {
                guard group.sets.count > 1 else { return }
                group.sets.removeLast()
            }

            updatedSession.completedModules[moduleIndex]
                .completedExercises[exerciseIndex]
                .completedSetGroups[groupIndex] = group
        }
    }

    private func updateDistanceUnit(moduleIndex: Int, exerciseIndex: Int, unit: DistanceUnit) {
        mutateSession { updatedSession in
            guard updatedSession.completedModules.indices.contains(moduleIndex),
                  updatedSession.completedModules[moduleIndex].completedExercises.indices.contains(exerciseIndex) else {
                return
            }

            updatedSession.completedModules[moduleIndex].completedExercises[exerciseIndex].distanceUnit = unit
        }
    }

    private func makeNewSet(from template: SetData?, setNumber: Int, side: Side?) -> SetData {
        var newSet = template ?? SetData(setNumber: setNumber, completed: false)
        newSet.id = UUID()
        newSet.setNumber = setNumber
        newSet.completed = false
        newSet.side = side
        return newSet
    }

    private func exerciseSummary(_ exercise: SessionExercise) -> String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }.count
        return "\(completedSets)/\(totalSets) sets"
    }
}

private struct EditSnapshot: Equatable {
    let session: Session
    let workoutName: String
    let sessionDate: Date
    let duration: Int
    let overallFeeling: Int?
    let notes: String
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
