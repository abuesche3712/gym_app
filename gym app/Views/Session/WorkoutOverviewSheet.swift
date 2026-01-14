//
//  WorkoutOverviewSheet.swift
//  gym app
//
//  Sheet for viewing and navigating the full workout during a session
//

import SwiftUI

// MARK: - Workout Overview Sheet

struct WorkoutOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session?
    let currentModuleIndex: Int
    let currentExerciseIndex: Int
    let onJumpTo: (Int, Int) -> Void
    let onUpdateSet: (Int, Int, Int, Int, Double?, Int?, Int?, Int?, Int?, Double?) -> Void
    let onAddExercise: (Int, String, ExerciseType, CardioMetric, DistanceUnit) -> Void

    @State private var expandedModules: Set<Int> = []
    @State private var expandedExercises: Set<String> = []
    @State private var editingSetLocation: SetLocation?
    @State private var addExerciseModuleIndex: Int? = nil
    @State private var showAddExerciseSheet = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let session = session {
                        ForEach(Array(session.completedModules.enumerated()), id: \.offset) { moduleIndex, module in
                            Section {
                                moduleHeader(module: module, moduleIndex: moduleIndex)

                                if expandedModules.contains(moduleIndex) {
                                    exercisesList(module: module, moduleIndex: moduleIndex)
                                    addExerciseButton(moduleIndex: moduleIndex)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .onAppear {
                    expandedModules.insert(currentModuleIndex)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo("\(currentModuleIndex)-\(currentExerciseIndex)", anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Workout Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accentBlue)
                }
            }
            .sheet(item: $editingSetLocation) { location in
                EditSetSheet(location: location) { weight, reps, rpe, duration, holdTime, distance in
                    onUpdateSet(location.moduleIndex, location.exerciseIndex, location.setGroupIndex, location.setIndex, weight, reps, rpe, duration, holdTime, distance)
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                if let moduleIndex = addExerciseModuleIndex {
                    AddExerciseToModuleSheet(
                        moduleName: session?.completedModules[moduleIndex].moduleName ?? "Module"
                    ) { name, type, cardioMetric, distanceUnit in
                        onAddExercise(moduleIndex, name, type, cardioMetric, distanceUnit)
                        showAddExerciseSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Module Header

    private func moduleHeader(module: CompletedModule, moduleIndex: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedModules.contains(moduleIndex) {
                    expandedModules.remove(moduleIndex)
                } else {
                    expandedModules.insert(moduleIndex)
                }
            }
        } label: {
            HStack {
                Image(systemName: module.moduleType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.moduleColor(module.moduleType))
                    .frame(width: 24)

                Text(module.moduleName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                let completed = module.completedExercises.filter { exercise in
                    exercise.completedSetGroups.allSatisfy { $0.sets.allSatisfy { $0.completed } }
                }.count
                Text("\(completed)/\(module.completedExercises.count)")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)

                Image(systemName: expandedModules.contains(moduleIndex) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercises List

    private func exercisesList(module: CompletedModule, moduleIndex: Int) -> some View {
        ForEach(Array(module.completedExercises.enumerated()), id: \.offset) { exerciseIndex, exercise in
            let isCurrent = moduleIndex == currentModuleIndex && exerciseIndex == currentExerciseIndex
            let exerciseKey = "\(moduleIndex)-\(exerciseIndex)"

            VStack(alignment: .leading, spacing: 0) {
                exerciseRow(exercise: exercise, moduleIndex: moduleIndex, exerciseIndex: exerciseIndex, isCurrent: isCurrent, exerciseKey: exerciseKey)

                if expandedExercises.contains(exerciseKey) {
                    setsGrid(exercise: exercise, moduleIndex: moduleIndex, exerciseIndex: exerciseIndex)
                }
            }
        }
    }

    private func exerciseRow(exercise: SessionExercise, moduleIndex: Int, exerciseIndex: Int, isCurrent: Bool, exerciseKey: String) -> some View {
        Button {
            onJumpTo(moduleIndex, exerciseIndex)
        } label: {
            HStack(spacing: AppSpacing.md) {
                let allDone = exercise.completedSetGroups.allSatisfy { $0.sets.allSatisfy { $0.completed } }
                ZStack {
                    Circle()
                        .fill(allDone ? AppColors.success.opacity(0.15) : (isCurrent ? AppColors.accentBlue.opacity(0.15) : AppColors.surfaceLight))
                        .frame(width: 28, height: 28)

                    if allDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.success)
                    } else if isCurrent {
                        Circle()
                            .fill(AppColors.accentBlue)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseName)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .foregroundColor(isCurrent ? AppColors.accentBlue : AppColors.textPrimary)

                    Text(exerciseSetSummary(exercise))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedExercises.contains(exerciseKey) {
                            expandedExercises.remove(exerciseKey)
                        } else {
                            expandedExercises.insert(exerciseKey)
                        }
                    }
                } label: {
                    Image(systemName: expandedExercises.contains(exerciseKey) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .padding(.leading, AppSpacing.lg)
        }
        .buttonStyle(.plain)
        .id("\(moduleIndex)-\(exerciseIndex)")
    }

    private func setsGrid(exercise: SessionExercise, moduleIndex: Int, exerciseIndex: Int) -> some View {
        VStack(spacing: 4) {
            var setNumber = 1
            ForEach(Array(exercise.completedSetGroups.enumerated()), id: \.offset) { setGroupIndex, setGroup in
                ForEach(Array(setGroup.sets.enumerated()), id: \.offset) { setIndex, setData in
                    let currentSetNum = setNumber
                    let _ = (setNumber += 1)

                    Button {
                        editingSetLocation = SetLocation(
                            moduleIndex: moduleIndex,
                            exerciseIndex: exerciseIndex,
                            setGroupIndex: setGroupIndex,
                            setIndex: setIndex,
                            exerciseName: exercise.exerciseName,
                            exerciseType: exercise.exerciseType,
                            setData: setData,
                            setNumber: currentSetNum
                        )
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Text("Set \(currentSetNum)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 44, alignment: .leading)

                            if setData.completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.success)

                                Text(formatSetData(setData, exerciseType: exercise.exerciseType))
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Circle()
                                    .stroke(AppColors.textTertiary, lineWidth: 1)
                                    .frame(width: 10, height: 10)

                                Text(formatTargetData(setData, exerciseType: exercise.exerciseType))
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.small)
                                .fill(setData.completed ? AppColors.success.opacity(0.05) : AppColors.surfaceLight.opacity(0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, AppSpacing.lg + 28 + AppSpacing.md)
                }
            }
        }
        .padding(.bottom, AppSpacing.sm)
    }

    private func addExerciseButton(moduleIndex: Int) -> some View {
        Button {
            addExerciseModuleIndex = moduleIndex
            showAddExerciseSheet = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("Add Exercise")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .padding(.leading, AppSpacing.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func exerciseSetSummary(_ exercise: SessionExercise) -> String {
        let totalSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercise.completedSetGroups.reduce(0) { sum, group in
            sum + group.sets.filter { $0.completed }.count
        }
        return "\(completedSets)/\(totalSets) sets"
    }

    private func formatSetData(_ set: SetData, exerciseType: ExerciseType) -> String {
        switch exerciseType {
        case .strength:
            return set.formattedStrength ?? "Done"
        case .isometric:
            return set.formattedIsometric ?? "Done"
        case .cardio:
            return set.formattedCardio ?? "Done"
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "Done"
        }
    }

    private func formatTargetData(_ set: SetData, exerciseType: ExerciseType) -> String {
        switch exerciseType {
        case .strength:
            let w = set.weight.map { "\(Int($0))lbs" } ?? ""
            let r = set.reps.map { "\($0)r" } ?? ""
            return [w, r].filter { !$0.isEmpty }.joined(separator: " × ")
        case .isometric:
            return set.holdTime.map { "\($0)s" } ?? "Hold"
        case .cardio:
            if let d = set.distance { return "\(Int(d))" }
            if let t = set.duration { return "\(t)s" }
            return "—"
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "—"
        }
    }
}

// MARK: - Edit Set Sheet

struct EditSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let location: SetLocation
    let onSave: (Double?, Int?, Int?, Int?, Int?, Double?) -> Void

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: 4) {
                    Text(location.exerciseName)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Set \(location.setNumber)")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                inputFields
                    .padding(AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfaceLight)
                    )

                Spacer()
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            Double(inputWeight),
                            Int(inputReps),
                            inputRPE > 0 ? inputRPE : nil,
                            inputDuration > 0 ? inputDuration : nil,
                            inputHoldTime > 0 ? inputHoldTime : nil,
                            Double(inputDistance)
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
            .onAppear { loadValues() }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var inputFields: some View {
        switch location.exerciseType {
        case .strength:
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WEIGHT")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.textTertiary)
                        TextField("0", text: $inputWeight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.cardBackground))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPS")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.textTertiary)
                        TextField("0", text: $inputReps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.cardBackground))
                    }
                }

                HStack {
                    Text("RPE")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Picker("RPE", selection: $inputRPE) {
                        Text("--").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 80)
                    .clipped()
                }
            }

        case .isometric:
            TimePickerView(totalSeconds: $inputHoldTime, maxMinutes: 5, label: "Hold Time")

        case .cardio:
            VStack(spacing: AppSpacing.md) {
                TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, label: "Duration")

                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.cardBackground))
                }
            }

        case .mobility, .explosive:
            VStack(alignment: .leading, spacing: 4) {
                Text("REPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.cardBackground))
            }
        }
    }

    private func loadValues() {
        let set = location.setData
        inputWeight = set.weight.map { formatWeight($0) } ?? ""
        inputReps = set.reps.map { "\($0)" } ?? ""
        inputRPE = set.rpe ?? 0
        inputDuration = set.duration ?? 0
        inputHoldTime = set.holdTime ?? 0
        inputDistance = set.distance.map { formatDistance($0) } ?? ""
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) { return "\(Int(weight))" }
        return String(format: "%.1f", weight)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance == floor(distance) { return "\(Int(distance))" }
        return String(format: "%.2f", distance)
    }
}
