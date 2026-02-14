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
    @Binding var session: Session?
    let currentModuleIndex: Int
    let currentExerciseIndex: Int
    let onJumpTo: (Int, Int) -> Void
    let onUpdateSet: (Int, Int, Int, Int, Double?, Int?, Int?, Int?, Int?, Double?, Bool) -> Void
    let onAddExercise: (Int, String, ExerciseType, CardioMetric, DistanceUnit) -> Void
    let onReorderExercise: ((Int, Int, Int) -> Void)?  // moduleIndex, fromIndex, toIndex
    let onDeleteExercise: ((Int, Int) -> Void)?  // moduleIndex, exerciseIndex

    @State private var expandedModules: Set<Int> = []
    @State private var expandedExercises: Set<String> = []
    @State private var editingSetLocation: SetLocation?
    @State private var addExerciseModuleIndex: Int? = nil
    @State private var showAddExerciseSheet = false

    private var progressionSuggestionCount: Int {
        guard let session else { return 0 }
        return session.completedModules.reduce(0) { moduleSum, module in
            moduleSum + module.completedExercises.filter { $0.progressionSuggestion != nil }.count
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let session = session {
                        Section {
                            progressionSummaryRow
                        }

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
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                        .foregroundColor(AppColors.dominant)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.dominant)
                }
            }
            .sheet(item: $editingSetLocation) { location in
                EditSetSheet(location: location) { weight, reps, rpe, duration, holdTime, distance in
                    // Mark as completed when saving values from the edit sheet
                    onUpdateSet(location.moduleIndex, location.exerciseIndex, location.setGroupIndex, location.setIndex, weight, reps, rpe, duration, holdTime, distance, true)
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

    private var progressionSummaryRow: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: progressionSuggestionCount > 0 ? "arrow.up.right.circle.fill" : "info.circle")
                .subheadline(color: progressionSuggestionCount > 0 ? AppColors.success : AppColors.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(progressionSuggestionCount > 0 ? "Progression suggestions ready" : "No progression suggestions yet")
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.semibold)
                Text(summaryDetailText)
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var summaryDetailText: String {
        if progressionSuggestionCount > 0 {
            return "\(progressionSuggestionCount) exercise\(progressionSuggestionCount == 1 ? "" : "s") include recommended targets."
        }
        return "Complete this workout once to seed recommendations for next time."
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
                    .subheadline(color: AppColors.moduleColor(module.moduleType))
                    .frame(width: 24)

                Text(module.moduleName)
                    .headline(color: AppColors.textPrimary)

                Spacer()

                let completed = module.completedExercises.filter { exercise in
                    exercise.completedSetGroups.allSatisfy { $0.sets.allSatisfy { $0.completed } }
                }.count
                Text("\(completed)/\(module.completedExercises.count)")
                    .caption(color: AppColors.textTertiary)

                Image(systemName: expandedModules.contains(moduleIndex) ? "chevron.down" : "chevron.right")
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.medium)
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
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if module.completedExercises.count > 1 {  // Don't allow deleting last exercise
                    Button(role: .destructive) {
                        onDeleteExercise?(moduleIndex, exerciseIndex)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .onMove { source, destination in
            moveExercise(in: moduleIndex, from: source, to: destination)
        }
        .onDelete { indexSet in
            // Only allow if more than 1 exercise
            if module.completedExercises.count > 1 {
                for index in indexSet {
                    onDeleteExercise?(moduleIndex, index)
                }
            }
        }
    }

    private func moveExercise(in moduleIndex: Int, from source: IndexSet, to destination: Int) {
        guard let fromIndex = source.first else { return }
        // Adjust destination if moving down (List uses insert-before semantics)
        let toIndex = fromIndex < destination ? destination - 1 : destination
        onReorderExercise?(moduleIndex, fromIndex, toIndex)
    }

    private func exerciseRow(exercise: SessionExercise, moduleIndex: Int, exerciseIndex: Int, isCurrent: Bool, exerciseKey: String) -> some View {
        Button {
            onJumpTo(moduleIndex, exerciseIndex)
        } label: {
            HStack(spacing: AppSpacing.md) {
                let allDone = exercise.completedSetGroups.allSatisfy { $0.sets.allSatisfy { $0.completed } }
                ZStack {
                    Circle()
                        .fill(allDone ? AppColors.success.opacity(0.15) : (isCurrent ? AppColors.dominant.opacity(0.15) : AppColors.surfaceTertiary))
                        .frame(width: 28, height: 28)

                    if allDone {
                        Image(systemName: "checkmark")
                            .caption2(color: AppColors.success)
                            .fontWeight(.bold)
                    } else if isCurrent {
                        Circle()
                            .fill(AppColors.dominant)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseName)
                        .subheadline(color: isCurrent ? AppColors.dominant : AppColors.textPrimary)
                        .fontWeight(isCurrent ? .semibold : .regular)

                    Text(exerciseSetSummary(exercise))
                        .caption(color: AppColors.textTertiary)

                    if let suggestion = exercise.progressionSuggestion {
                        HStack(spacing: 4) {
                            if let expected = expectedRecommendation(from: suggestion) {
                                Image(systemName: expected.icon)
                                    .caption2(color: expected.color)
                            } else {
                                Image(systemName: "sparkles")
                                    .caption2(color: AppColors.dominant)
                            }

                            Text("Suggested: \(suggestion.formattedSuggestion)")
                                .caption(color: AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
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
                        .caption2(color: AppColors.textTertiary)
                        .fontWeight(.medium)
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
                                .caption(color: AppColors.textTertiary)
                                .frame(width: 44, alignment: .leading)

                            if setData.completed {
                                Image(systemName: "checkmark")
                                    .caption2(color: AppColors.success)
                                    .fontWeight(.bold)

                                Text(formatSetData(setData, exerciseType: exercise.exerciseType))
                                    .caption(color: AppColors.textSecondary)
                            } else {
                                Circle()
                                    .stroke(AppColors.textTertiary, lineWidth: 1)
                                    .frame(width: 10, height: 10)

                                Text(formatTargetData(setData, exerciseType: exercise.exerciseType))
                                    .caption(color: AppColors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "pencil")
                                .caption2(color: AppColors.textTertiary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.small)
                                .fill(setData.completed ? AppColors.success.opacity(0.05) : AppColors.surfaceTertiary.opacity(0.5))
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
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.medium)
                Text("Add Exercise")
                    .subheadline(color: AppColors.textTertiary)
                    .fontWeight(.medium)
            }
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

    private func expectedRecommendation(from suggestion: ProgressionSuggestion) -> ProgressionRecommendation? {
        if let applied = suggestion.appliedOutcome { return applied }
        if suggestion.suggestedValue > suggestion.baseValue + 0.0001 { return .progress }
        if suggestion.suggestedValue < suggestion.baseValue - 0.0001 { return .regress }
        return .stay
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
        case .recovery:
            return set.formattedRecovery ?? "Done"
        }
    }

    private func formatTargetData(_ set: SetData, exerciseType: ExerciseType) -> String {
        switch exerciseType {
        case .strength:
            let w = set.weight.map { "\(formatWeight($0))lbs" } ?? ""
            let r = set.reps.map { "\($0)r" } ?? ""
            return [w, r].filter { !$0.isEmpty }.joined(separator: " × ")
        case .isometric:
            return set.holdTime.map { formatDuration($0) } ?? "Hold"
        case .cardio:
            // Show both time and distance targets if they exist
            var parts: [String] = []
            if let t = set.duration, t > 0 { parts.append(formatDuration(t)) }
            if let d = set.distance, d > 0 { parts.append(formatDistanceValue(d)) }
            return parts.isEmpty ? "—" : parts.joined(separator: " / ")
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "—"
        case .recovery:
            return set.duration.map { formatDuration($0) } ?? "—"
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
                        .headline(color: AppColors.textPrimary)
                    Text("Set \(location.setNumber)")
                        .subheadline(color: AppColors.textSecondary)
                }

                inputFields
                    .padding(AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfaceTertiary)
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
                    .foregroundColor(AppColors.dominant)
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
                            .statLabel(color: AppColors.textTertiary)
                        TextField("0", text: $inputWeight)
                            .keyboardType(.decimalPad)
                            .font(.displayMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPS")
                            .statLabel(color: AppColors.textTertiary)
                        TextField("0", text: $inputReps)
                            .keyboardType(.numberPad)
                            .font(.displayMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                    }
                }

                HStack {
                    Text("RPE")
                        .subheadline(color: AppColors.textSecondary)
                        .fontWeight(.medium)
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
                TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, maxHours: 4, label: "Duration")

                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE")
                        .statLabel(color: AppColors.textTertiary)
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.displayMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                }
            }

        case .mobility, .explosive:
            VStack(alignment: .leading, spacing: 4) {
                Text("REPS")
                    .statLabel(color: AppColors.textTertiary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.displayMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
            }

        case .recovery:
            VStack(alignment: .leading, spacing: 4) {
                Text("DURATION")
                    .statLabel(color: AppColors.textTertiary)
                Text(inputDuration > 0 ? formatDuration(inputDuration) : "--")
                    .displayMedium(color: AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
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
        inputDistance = set.distance.map { formatDistanceValue($0) } ?? ""
    }
}
