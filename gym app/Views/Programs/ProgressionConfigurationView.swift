//
//  ProgressionConfigurationView.swift
//  gym app
//
//  Configure which exercises get automatic progression suggestions
//

import SwiftUI

struct ProgressionConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @EnvironmentObject private var repository: DataRepository

    let program: Program

    @State private var progressionEnabledExercises: Set<UUID>
    @State private var exerciseProgressionOverrides: [UUID: ProgressionRule]
    @State private var defaultProgressionRule: ProgressionRule?
    @State private var progressionPolicy: ProgressionPolicy
    @State private var showingDefaultRuleEditor = false
    @State private var editingExerciseId: UUID?
    @State private var expandedWorkouts: Set<UUID> = []

    init(program: Program) {
        self.program = program
        _progressionEnabledExercises = State(initialValue: program.progressionEnabledExercises)
        _exerciseProgressionOverrides = State(initialValue: program.exerciseProgressionOverrides)
        _defaultProgressionRule = State(initialValue: program.defaultProgressionRule)
        _progressionPolicy = State(initialValue: program.progressionPolicy)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressionModeCard

                    // Default Rule Card
                    defaultRuleCard

                    // Workouts and their exercises
                    workoutsList
                        .opacity(progressionPolicy == .adaptive ? 1.0 : 0.5)
                        .disabled(progressionPolicy != .adaptive)
                }
                .padding()
            }
            .navigationTitle("Configure Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                    }
                }
            }
            .sheet(isPresented: $showingDefaultRuleEditor) {
                ProgressionRuleEditorSheet(
                    rule: defaultProgressionRule,
                    title: "Default Rule"
                ) { newRule in
                    defaultProgressionRule = newRule
                }
            }
            .sheet(item: $editingExerciseId) { exerciseId in
                let currentRule = exerciseProgressionOverrides[exerciseId]
                ProgressionRuleEditorSheet(
                    rule: currentRule,
                    title: "Exercise Override",
                    showUseDefault: true
                ) { newRule in
                    if let rule = newRule {
                        exerciseProgressionOverrides[exerciseId] = rule
                    } else {
                        exerciseProgressionOverrides.removeValue(forKey: exerciseId)
                    }
                }
            }
        }
    }

    // MARK: - Default Rule Card

    private var progressionModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression Mode")
                .font(.headline)

            Picker("Progression Mode", selection: $progressionPolicy) {
                ForEach(ProgressionPolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .pickerStyle(.segmented)

            Text(progressionPolicy.shortDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            if progressionPolicy == .legacy {
                Text("Switch to Adaptive to use per-exercise enablement and overrides below.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var defaultRuleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Default Progression")
                    .font(.headline)

                Spacer()

                Button {
                    showingDefaultRuleEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                }
            }

            if let rule = defaultProgressionRule {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AppColors.success)

                    Text(rule.displayDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No default rule set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Workouts List

    private var workoutsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(workoutsInProgram, id: \.id) { workout in
                workoutSection(workout: workout)
            }

            if workoutsInProgram.isEmpty {
                Text("No workouts in this program")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    private var workoutsInProgram: [Workout] {
        // Get unique workout IDs from program slots
        let workoutIds = Set(program.workoutSlots.map { $0.workoutId })
        return workoutIds.compactMap { id in
            repository.workouts.first { $0.id == id }
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Workout Section

    private func workoutSection(workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Workout header
            Button {
                withAnimation {
                    if expandedWorkouts.contains(workout.id) {
                        expandedWorkouts.remove(workout.id)
                    } else {
                        expandedWorkouts.insert(workout.id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: expandedWorkouts.contains(workout.id) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    Text(workout.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    let stats = exerciseStats(for: workout)
                    Text("\(stats.enabled)/\(stats.total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Module sections (expanded)
            if expandedWorkouts.contains(workout.id) {
                ForEach(modulesForWorkout(workout), id: \.id) { module in
                    moduleSection(module: module, in: workout)
                }
            }
        }
    }

    private func exerciseStats(for workout: Workout) -> (enabled: Int, total: Int) {
        let modules = modulesForWorkout(workout)
        var enabled = 0
        var total = 0

        for module in modules {
            for exercise in module.exercises {
                total += 1
                if progressionEnabledExercises.contains(exercise.id) {
                    enabled += 1
                }
            }
        }

        return (enabled, total)
    }

    private func modulesForWorkout(_ workout: Workout) -> [Module] {
        workout.moduleReferences.compactMap { ref in
            repository.modules.first { $0.id == ref.moduleId }
        }
    }

    // MARK: - Module Section

    private func moduleSection(module: Module, in workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Module header with bulk actions
            HStack {
                Text(module.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("(\(module.type.displayName))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Bulk selection buttons
                Menu {
                    Button("Select All") {
                        selectAll(in: module)
                    }
                    Button("Select None") {
                        selectNone(in: module)
                    }
                    Button("Smart Select") {
                        applySmartDefaults(to: module)
                    }
                } label: {
                    let moduleStats = moduleExerciseStats(for: module)
                    Text(moduleStats.enabled == 0 ? "None" :
                            moduleStats.enabled == moduleStats.total ? "All" :
                            "\(moduleStats.enabled)")
                        .font(.caption)
                        .foregroundColor(AppColors.dominant)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)

            // Exercises
            ForEach(module.exercises) { exercise in
                exerciseRow(exercise: exercise, moduleType: module.type)
            }
        }
        .padding(.leading, 24)
    }

    private func moduleExerciseStats(for module: Module) -> (enabled: Int, total: Int) {
        var enabled = 0
        for exercise in module.exercises {
            if progressionEnabledExercises.contains(exercise.id) {
                enabled += 1
            }
        }
        return (enabled, module.exercises.count)
    }

    // MARK: - Exercise Row

    private func exerciseRow(exercise: ExerciseInstance, moduleType: ModuleType) -> some View {
        let isEnabled = progressionEnabledExercises.contains(exercise.id)
        let hasOverride = exerciseProgressionOverrides[exercise.id] != nil
        let shouldDefaultEnabled = shouldDefaultToProgression(exercise, moduleType: moduleType)

        return HStack(spacing: 12) {
            // Toggle
            Button {
                withAnimation {
                    if isEnabled {
                        progressionEnabledExercises.remove(exercise.id)
                        exerciseProgressionOverrides.removeValue(forKey: exercise.id)
                    } else {
                        progressionEnabledExercises.insert(exercise.id)
                    }
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isEnabled ? AppColors.success : .secondary)
            }
            .buttonStyle(.plain)

            // Exercise name
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline)
                    .foregroundColor(isEnabled ? .primary : .secondary)

                if !shouldDefaultEnabled {
                    Text("Not recommended")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Progression indicator and customize button
            if isEnabled {
                if hasOverride, let override = exerciseProgressionOverrides[exercise.id] {
                    Text("+\(formatPercent(override.percentageIncrease))%")
                        .font(.caption)
                        .foregroundColor(AppColors.dominant)
                } else if let defaultRule = defaultProgressionRule {
                    Text("+\(formatPercent(defaultRule.percentageIncrease))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    editingExerciseId = exercise.id
                } label: {
                    Image(systemName: hasOverride ? "pencil.circle.fill" : "pencil.circle")
                        .font(.body)
                        .foregroundColor(hasOverride ? AppColors.dominant : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Smart Defaults

    private func shouldDefaultToProgression(_ exercise: ExerciseInstance, moduleType: ModuleType) -> Bool {
        // Skip these module types entirely
        if [.warmup, .recovery, .prehab].contains(moduleType) {
            return false
        }

        // Only progress strength-type exercises
        if exercise.exerciseType != .strength {
            return false
        }

        return true
    }

    private func applySmartDefaults(to module: Module) {
        for exercise in module.exercises {
            if shouldDefaultToProgression(exercise, moduleType: module.type) {
                progressionEnabledExercises.insert(exercise.id)
            } else {
                progressionEnabledExercises.remove(exercise.id)
                exerciseProgressionOverrides.removeValue(forKey: exercise.id)
            }
        }
    }

    func applySmartDefaultsToAll() {
        for workout in workoutsInProgram {
            for module in modulesForWorkout(workout) {
                applySmartDefaults(to: module)
            }
        }
    }

    private func selectAll(in module: Module) {
        for exercise in module.exercises {
            progressionEnabledExercises.insert(exercise.id)
        }
    }

    private func selectNone(in module: Module) {
        for exercise in module.exercises {
            progressionEnabledExercises.remove(exercise.id)
            exerciseProgressionOverrides.removeValue(forKey: exercise.id)
        }
    }

    // MARK: - Helpers

    private func formatPercent(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func saveChanges() {
        var updatedProgram = program
        updatedProgram.progressionEnabledExercises = progressionEnabledExercises
        updatedProgram.exerciseProgressionOverrides = exerciseProgressionOverrides
        updatedProgram.defaultProgressionRule = defaultProgressionRule
        updatedProgram.progressionPolicy = progressionPolicy
        updatedProgram.updatedAt = Date()

        programViewModel.saveProgram(updatedProgram)
        dismiss()
    }
}

// MARK: - Progression Rule Editor Sheet

struct ProgressionRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let rule: ProgressionRule?
    let title: String
    var showUseDefault: Bool = false
    let onSave: (ProgressionRule?) -> Void

    @State private var targetMetric: ProgressionMetric
    @State private var strategy: ProgressionStrategy
    @State private var percentageIncrease: Double
    @State private var roundingIncrement: Double
    @State private var minimumIncrease: Double

    private let percentageOptions: [Double] = [1.0, 2.5, 5.0, 7.5, 10.0]
    private let weightRoundingOptions: [Double] = [1.0, 2.5, 5.0, 10.0]
    private let repRoundingOptions: [Double] = [1.0]
    private let weightMinimumOptions: [Double] = [0, 2.5, 5.0, 10.0]
    private let repMinimumOptions: [Double] = [0, 1.0, 2.0]

    init(rule: ProgressionRule?, title: String, showUseDefault: Bool = false, onSave: @escaping (ProgressionRule?) -> Void) {
        self.rule = rule
        self.title = title
        self.showUseDefault = showUseDefault
        self.onSave = onSave

        let defaultRule = rule ?? .conservative
        _targetMetric = State(initialValue: defaultRule.targetMetric)
        _strategy = State(initialValue: defaultRule.strategy)
        _percentageIncrease = State(initialValue: defaultRule.percentageIncrease)
        _roundingIncrement = State(initialValue: defaultRule.roundingIncrement)
        _minimumIncrease = State(initialValue: defaultRule.minimumIncrease ?? 5.0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Target Metric", selection: $targetMetric) {
                        ForEach(ProgressionMetric.allCases) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }

                    if targetMetric == .weight {
                        Picker("Strategy", selection: $strategy) {
                            ForEach(ProgressionStrategy.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }

                    Picker("Percentage Increase", selection: $percentageIncrease) {
                        ForEach(percentageOptions, id: \.self) { value in
                            Text("+\(formatPercent(value))%").tag(value)
                        }
                    }

                    Picker("Round to nearest", selection: $roundingIncrement) {
                        ForEach(roundingOptions, id: \.self) { value in
                            Text("\(formatWeight(value))").tag(value)
                        }
                    }

                    Picker("Minimum increase", selection: $minimumIncrease) {
                        ForEach(minimumOptions, id: \.self) { value in
                            if value == 0 {
                                Text("No minimum").tag(value)
                            } else {
                                Text("\(formatWeight(value))").tag(value)
                            }
                        }
                    }
                } header: {
                    Text("Progression Settings")
                }

                Section {
                    Text("Example: 100 lbs → \(formatWeight(calculateExample()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Preview")
                }

                if showUseDefault {
                    Section {
                        Button("Use Program Default") {
                            onSave(nil)
                            dismiss()
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .onChange(of: targetMetric) { _, newMetric in
                if !roundingOptions.contains(roundingIncrement) {
                    roundingIncrement = roundingOptions.first ?? 1.0
                }
                if !minimumOptions.contains(minimumIncrease) {
                    minimumIncrease = minimumOptions.first ?? 0
                }
                if newMetric != .weight {
                    strategy = .linear
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newRule = ProgressionRule(
                            targetMetric: targetMetric,
                            strategy: targetMetric == .weight ? strategy : .linear,
                            percentageIncrease: percentageIncrease,
                            roundingIncrement: roundingIncrement,
                            minimumIncrease: minimumIncrease > 0 ? minimumIncrease : nil
                        )
                        onSave(newRule)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var roundingOptions: [Double] {
        targetMetric == .weight ? weightRoundingOptions : repRoundingOptions
    }

    private var minimumOptions: [Double] {
        targetMetric == .weight ? weightMinimumOptions : repMinimumOptions
    }

    private func calculateExample() -> Double {
        let base = targetMetric == .weight ? 100.0 : 8.0
        var increase = base * (percentageIncrease / 100.0)
        if minimumIncrease > 0 {
            increase = max(increase, minimumIncrease)
        }
        let rawSuggested = base + increase
        let rounded = round(rawSuggested / roundingIncrement) * roundingIncrement
        return max(rounded, base + roundingIncrement)
    }
}

// MARK: - UUID Extension for Identifiable

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// Preview requires additional setup with view models
