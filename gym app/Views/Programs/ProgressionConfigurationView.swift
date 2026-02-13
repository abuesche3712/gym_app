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
    @ObservedObject private var repository = DataRepository.shared

    let program: Program

    @State private var progressionEnabledExercises: Set<UUID>
    @State private var exerciseProgressionOverrides: [UUID: ProgressionRule]
    @State private var exerciseProgressionStates: [UUID: ExerciseProgressionState]
    @State private var defaultProgressionProfile: ProgressionProfile
    @State private var exerciseProgressionProfiles: [UUID: ProgressionProfile]
    @State private var defaultProgressionRule: ProgressionRule?
    @State private var progressionPolicy: ProgressionPolicy
    @State private var showingDefaultRuleEditor = false
    @State private var editingExerciseId: UUID?
    @State private var expandedWorkouts: Set<UUID> = []

    private enum QuickRulePreset: String, CaseIterable, Identifiable {
        case compound
        case dumbbell
        case repBuilder

        var id: String { rawValue }

        var title: String {
            switch self {
            case .compound: return "Compound"
            case .dumbbell: return "Dumbbell"
            case .repBuilder: return "Rep Builder"
            }
        }

        var subtitle: String {
            switch self {
            case .compound: return "+5%, 5 lb steps"
            case .dumbbell: return "+2.5%, 2.5 lb steps"
            case .repBuilder: return "Reps +5%"
            }
        }

        var rule: ProgressionRule {
            switch self {
            case .compound: return .moderate
            case .dumbbell: return .fineGrained
            case .repBuilder: return .repProgression
            }
        }
    }

    private enum ProfilePreset: String, CaseIterable, Identifiable {
        case conservative
        case balanced
        case aggressive

        var id: String { rawValue }

        var title: String {
            switch self {
            case .conservative: return "Conservative"
            case .balanced: return "Balanced"
            case .aggressive: return "Aggressive"
            }
        }

        var profile: ProgressionProfile {
            switch self {
            case .conservative:
                return ProgressionProfile(
                    preferredMetric: nil,
                    readinessGate: ProgressionReadinessGate(
                        minimumCompletedSetRatio: 0.8,
                        minimumCompletedSets: 2,
                        staleAfterDays: 35
                    ),
                    decisionPolicy: ProgressionDecisionPolicy(
                        progressThreshold: 0.75,
                        regressThreshold: 0.35,
                        completionWeight: 0.35,
                        performanceWeight: 0.25,
                        effortWeight: 0.20,
                        confidenceWeight: 0.10,
                        streakWeight: 0.10
                    ),
                    guardrails: ProgressionGuardrails(
                        maxProgressPercent: 5,
                        maxRegressPercent: 8,
                        floorValue: 0,
                        ceilingValue: nil,
                        minimumAbsoluteStep: nil
                    )
                )
            case .balanced:
                return .strengthDefault
            case .aggressive:
                return ProgressionProfile(
                    preferredMetric: nil,
                    readinessGate: ProgressionReadinessGate(
                        minimumCompletedSetRatio: 0.65,
                        minimumCompletedSets: 1,
                        staleAfterDays: 49
                    ),
                    decisionPolicy: ProgressionDecisionPolicy(
                        progressThreshold: 0.62,
                        regressThreshold: 0.42,
                        completionWeight: 0.25,
                        performanceWeight: 0.35,
                        effortWeight: 0.10,
                        confidenceWeight: 0.15,
                        streakWeight: 0.15
                    ),
                    guardrails: ProgressionGuardrails(
                        maxProgressPercent: 12,
                        maxRegressPercent: 12,
                        floorValue: 0,
                        ceilingValue: nil,
                        minimumAbsoluteStep: nil
                    )
                )
            }
        }
    }

    init(program: Program) {
        self.program = program
        _progressionEnabledExercises = State(initialValue: program.progressionEnabledExercises)
        _exerciseProgressionOverrides = State(initialValue: program.exerciseProgressionOverrides)
        _exerciseProgressionStates = State(initialValue: program.exerciseProgressionStates)
        _defaultProgressionProfile = State(initialValue: program.defaultProgressionProfile ?? .strengthDefault)
        _exerciseProgressionProfiles = State(initialValue: program.exerciseProgressionProfiles)
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

                    quickPresetsCard
                    quickTuningCard
                    profileControlsCard
                    selectionToolsCard
                    learnedStateCard
                    subtleSignalsCard

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

    private var quickPresetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Presets")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(QuickRulePreset.allCases) { preset in
                    Button {
                        applyQuickPreset(preset.rule)
                    } label: {
                        VStack(spacing: 3) {
                            Text(preset.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(preset.subtitle)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var quickTuningCard: some View {
        let rule = defaultProgressionRule ?? .conservative

        return VStack(alignment: .leading, spacing: 10) {
            Text("Quick Tuning")
                .font(.headline)

            HStack(spacing: 8) {
                Menu {
                    ForEach(availableTargetMetrics) { metric in
                        Button(metric.displayName) {
                            updateDefaultRule { current in
                                current.targetMetric = metric
                                if metric != .weight {
                                    current.strategy = .linear
                                }
                                let nextRounding = roundingOptions(for: current).first ?? 1
                                if !roundingOptions(for: current).contains(current.roundingIncrement) {
                                    current.roundingIncrement = nextRounding
                                }
                                let nextMinimum = minimumOptions(for: current).first ?? 0
                                if let minIncrease = current.minimumIncrease {
                                    if !minimumOptions(for: current).contains(minIncrease) {
                                        current.minimumIncrease = nextMinimum > 0 ? nextMinimum : nil
                                    }
                                } else if nextMinimum > 0 {
                                    current.minimumIncrease = nextMinimum
                                }
                            }
                        }
                    }
                } label: {
                    tuningChip(title: "Metric", value: rule.targetMetric.displayName)
                }

                if rule.targetMetric == .weight {
                    Menu {
                        ForEach(ProgressionStrategy.allCases) { strategy in
                            Button(strategy.displayName) {
                                updateDefaultRule { current in
                                    current.strategy = strategy
                                }
                            }
                        }
                    } label: {
                        tuningChip(title: "Strategy", value: rule.strategy.displayName)
                    }
                }
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(percentageOptions, id: \.self) { value in
                        Button("+\(formatPercent(value))%") {
                            updateDefaultRule { current in
                                current.percentageIncrease = value
                            }
                        }
                    }
                } label: {
                    tuningChip(title: "Increase", value: "+\(formatPercent(rule.percentageIncrease))%")
                }

                Menu {
                    ForEach(roundingOptions(for: rule), id: \.self) { value in
                        Button(formatTuningValue(value, metric: rule.targetMetric)) {
                            updateDefaultRule { current in
                                current.roundingIncrement = value
                            }
                        }
                    }
                } label: {
                    tuningChip(
                        title: "Round",
                        value: formatTuningValue(rule.roundingIncrement, metric: rule.targetMetric)
                    )
                }

                Menu {
                    ForEach(minimumOptions(for: rule), id: \.self) { value in
                        let label = value == 0 ? "No min" : formatTuningValue(value, metric: rule.targetMetric)
                        Button(label) {
                            updateDefaultRule { current in
                                current.minimumIncrease = value > 0 ? value : nil
                            }
                        }
                    }
                } label: {
                    tuningChip(
                        title: "Min",
                        value: rule.minimumIncrease.map { formatTuningValue($0, metric: rule.targetMetric) } ?? "No min"
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var profileControlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Decision Profile")
                .font(.headline)

            Picker("Preset", selection: profilePresetSelection) {
                ForEach(ProfilePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Stepper(
                    "Progress cap \(Int((defaultProgressionProfile.guardrails.maxProgressPercent ?? 10).rounded()))%",
                    value: Binding(
                        get: { Int((defaultProgressionProfile.guardrails.maxProgressPercent ?? 10).rounded()) },
                        set: { value in
                            defaultProgressionProfile.guardrails.maxProgressPercent = Double(max(1, value))
                        }
                    ),
                    in: 1...20
                )

                Stepper(
                    "Regress cap \(Int((defaultProgressionProfile.guardrails.maxRegressPercent ?? 12).rounded()))%",
                    value: Binding(
                        get: { Int((defaultProgressionProfile.guardrails.maxRegressPercent ?? 12).rounded()) },
                        set: { value in
                            defaultProgressionProfile.guardrails.maxRegressPercent = Double(max(1, value))
                        }
                    ),
                    in: 1...25
                )
            }
            .font(.caption)

            HStack(spacing: 8) {
                Stepper(
                    "Completion \(Int((defaultProgressionProfile.readinessGate.minimumCompletedSetRatio * 100).rounded()))%",
                    value: Binding(
                        get: { Int((defaultProgressionProfile.readinessGate.minimumCompletedSetRatio * 100).rounded()) },
                        set: { value in
                            defaultProgressionProfile.readinessGate.minimumCompletedSetRatio = Double(max(50, min(95, value))) / 100.0
                        }
                    ),
                    in: 50...95,
                    step: 5
                )

                Stepper(
                    "Stale \(defaultProgressionProfile.readinessGate.staleAfterDays)d",
                    value: Binding(
                        get: { defaultProgressionProfile.readinessGate.staleAfterDays },
                        set: { value in
                            defaultProgressionProfile.readinessGate.staleAfterDays = max(14, value)
                        }
                    ),
                    in: 14...120,
                    step: 7
                )
            }
            .font(.caption)

            HStack(spacing: 8) {
                Button("Apply to Enabled") {
                    applyProfileToEnabledExercises()
                }
                .buttonStyle(.bordered)

                Button("Clear Exercise Overrides") {
                    exerciseProgressionProfiles.removeAll()
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(progressionPolicy == .adaptive ? 1.0 : 0.5)
        .disabled(progressionPolicy != .adaptive)
    }

    private var profilePresetSelection: Binding<ProfilePreset> {
        Binding(
            get: { preset(for: defaultProgressionProfile) },
            set: { defaultProgressionProfile = $0.profile }
        )
    }

    private func tuningChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var selectionToolsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selection Tools")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Smart Select All") {
                    applySmartDefaultsToAll()
                }
                .buttonStyle(.bordered)

                Button("Enable Strength+Cardio") {
                    selectAllPrimaryExercises()
                }
                .buttonStyle(.bordered)

                Button("Clear All") {
                    clearAllSelections()
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(progressionPolicy == .adaptive ? 1.0 : 0.5)
        .disabled(progressionPolicy != .adaptive)
    }

    private var learnedStateCard: some View {
        let learnedCount = exerciseProgressionStates.count
        let acceptanceRates = exerciseProgressionStates.values.compactMap(\.acceptanceRate)
        let averageAcceptance = acceptanceRates.isEmpty
            ? nil
            : acceptanceRates.reduce(0, +) / Double(acceptanceRates.count)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Learned State")
                .font(.headline)

            if learnedCount == 0 {
                Text("No exercises have learned progression history yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(learnedCount) exercise\(learnedCount == 1 ? "" : "s") have learned progression history.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let averageAcceptance {
                    Text("Average acceptance \(Int((averageAcceptance * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button("Reset Learned State") {
                    exerciseProgressionStates.removeAll()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var subtleSignalsCard: some View {
        let lowAcceptanceIds = lowAcceptanceExerciseIds
        let oscillatingIds = oscillatingExerciseIds
        let cardioWithoutProfileIds = enabledCardioExerciseIds.filter { exerciseProgressionProfiles[$0] == nil }
        let hasSignals = !lowAcceptanceIds.isEmpty || !oscillatingIds.isEmpty || !cardioWithoutProfileIds.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            Text("Signals")
                .font(.headline)

            if !hasSignals {
                Text("No notable progression signals yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                if !lowAcceptanceIds.isEmpty {
                    subtleSignalRow(
                        title: "Low acceptance on \(lowAcceptanceIds.count) exercise\(lowAcceptanceIds.count == 1 ? "" : "s").",
                        detail: "Suggestions are frequently overridden. Consider a lower progression ceiling."
                    ) {
                        Button("Apply Conservative") {
                            applyConservativeProfile(to: lowAcceptanceIds)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }

                if !oscillatingIds.isEmpty {
                    subtleSignalRow(
                        title: "Outcome direction is oscillating on \(oscillatingIds.count) exercise\(oscillatingIds.count == 1 ? "" : "s").",
                        detail: "A slightly stricter readiness gate can reduce back-and-forth jumps."
                    ) {
                        Button("Tighten Readiness") {
                            tightenReadinessGate(for: oscillatingIds)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }

                if !cardioWithoutProfileIds.isEmpty {
                    subtleSignalRow(
                        title: "Cardio progression is enabled on \(cardioWithoutProfileIds.count) exercise\(cardioWithoutProfileIds.count == 1 ? "" : "s") without a cardio profile.",
                        detail: "You can apply a cardio-tuned profile while keeping per-exercise control."
                    ) {
                        Button("Apply Cardio Profile") {
                            applyCardioProfile(to: cardioWithoutProfileIds)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(progressionPolicy == .adaptive ? 1.0 : 0.5)
        .disabled(progressionPolicy != .adaptive)
    }

    @ViewBuilder
    private func subtleSignalRow<Actions: View>(
        title: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
            actions()
        }
        .padding(.vertical, 2)
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
        let hasProfileOverride = exerciseProgressionProfiles[exercise.id] != nil
        let shouldDefaultEnabled = shouldDefaultToProgression(exercise, moduleType: moduleType)

        return HStack(spacing: 12) {
            // Toggle
            Button {
                withAnimation {
                    if isEnabled {
                        progressionEnabledExercises.remove(exercise.id)
                        exerciseProgressionOverrides.removeValue(forKey: exercise.id)
                        exerciseProgressionStates.removeValue(forKey: exercise.id)
                        exerciseProgressionProfiles.removeValue(forKey: exercise.id)
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
                } else if isEnabled, let summary = stateSummary(for: exercise.id) {
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if isEnabled, hasProfileOverride {
                    Text("Profile override")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

                Button {
                    withAnimation {
                        if hasProfileOverride {
                            exerciseProgressionProfiles.removeValue(forKey: exercise.id)
                        } else {
                            exerciseProgressionProfiles[exercise.id] = defaultProgressionProfile
                        }
                    }
                } label: {
                    Image(systemName: hasProfileOverride ? "slider.horizontal.3.circle.fill" : "slider.horizontal.3.circle")
                        .font(.body)
                        .foregroundColor(hasProfileOverride ? AppColors.dominant : .secondary)
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

        // Progress strength and cardio exercises by default
        if exercise.exerciseType != .strength && exercise.exerciseType != .cardio {
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
                exerciseProgressionStates.removeValue(forKey: exercise.id)
                exerciseProgressionProfiles.removeValue(forKey: exercise.id)
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

    private func selectAllPrimaryExercises() {
        for workout in workoutsInProgram {
            for module in modulesForWorkout(workout) {
                for exercise in module.exercises where exercise.exerciseType == .strength || exercise.exerciseType == .cardio {
                    progressionEnabledExercises.insert(exercise.id)
                }
            }
        }
    }

    private func clearAllSelections() {
        progressionEnabledExercises.removeAll()
        exerciseProgressionOverrides.removeAll()
        exerciseProgressionStates.removeAll()
        exerciseProgressionProfiles.removeAll()
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
            exerciseProgressionStates.removeValue(forKey: exercise.id)
            exerciseProgressionProfiles.removeValue(forKey: exercise.id)
        }
    }

    // MARK: - Helpers

    private let percentageOptions: [Double] = [1.0, 2.5, 5.0, 7.5, 10.0]
    private let weightRoundingOptions: [Double] = [1.0, 2.5, 5.0, 10.0]
    private let repRoundingOptions: [Double] = [1.0]
    private let durationRoundingOptions: [Double] = [15.0, 30.0, 60.0, 120.0]
    private let distanceRoundingOptions: [Double] = [0.05, 0.10, 0.25, 0.50]
    private let weightMinimumOptions: [Double] = [0, 2.5, 5.0, 10.0]
    private let repMinimumOptions: [Double] = [0, 1.0, 2.0]
    private let durationMinimumOptions: [Double] = [0, 15.0, 30.0, 60.0, 120.0]
    private let distanceMinimumOptions: [Double] = [0, 0.05, 0.10, 0.25]

    private func formatPercent(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var availableTargetMetrics: [ProgressionMetric] {
        var metrics: [ProgressionMetric] = [.weight, .reps]
        if exerciseLookupById.values.contains(where: { $0.exerciseType == .cardio }) {
            metrics.append(.duration)
            metrics.append(.distance)
        }
        return metrics
    }

    private func roundingOptions(for rule: ProgressionRule) -> [Double] {
        switch rule.targetMetric {
        case .weight:
            return weightRoundingOptions
        case .reps:
            return repRoundingOptions
        case .duration:
            return durationRoundingOptions
        case .distance:
            return distanceRoundingOptions
        }
    }

    private func minimumOptions(for rule: ProgressionRule) -> [Double] {
        switch rule.targetMetric {
        case .weight:
            return weightMinimumOptions
        case .reps:
            return repMinimumOptions
        case .duration:
            return durationMinimumOptions
        case .distance:
            return distanceMinimumOptions
        }
    }

    private func formatTuningValue(_ value: Double, metric: ProgressionMetric) -> String {
        switch metric {
        case .weight:
            return "\(formatWeight(value)) lbs"
        case .reps:
            return "\(Int(value.rounded())) reps"
        case .duration:
            return formatDuration(Int(value.rounded()))
        case .distance:
            return "\(formatDistanceValue(value)) mi"
        }
    }

    private var exerciseLookupById: [UUID: ExerciseInstance] {
        var lookup: [UUID: ExerciseInstance] = [:]
        for workout in workoutsInProgram {
            for module in modulesForWorkout(workout) {
                for exercise in module.exercises {
                    lookup[exercise.id] = exercise
                }
            }
        }
        return lookup
    }

    private var enabledCardioExerciseIds: [UUID] {
        progressionEnabledExercises
            .filter { exerciseLookupById[$0]?.exerciseType == .cardio }
            .sorted { lhs, rhs in
                let lhsName = exerciseLookupById[lhs]?.name ?? ""
                let rhsName = exerciseLookupById[rhs]?.name ?? ""
                return lhsName < rhsName
            }
    }

    private var lowAcceptanceExerciseIds: [UUID] {
        exerciseProgressionStates
            .filter { exerciseId, state in
                guard progressionEnabledExercises.contains(exerciseId),
                      state.suggestionsPresented >= 4,
                      let acceptanceRate = state.acceptanceRate else {
                    return false
                }
                return acceptanceRate < 0.45
            }
            .map(\.key)
            .sorted { lhs, rhs in
                let lhsName = exerciseLookupById[lhs]?.name ?? ""
                let rhsName = exerciseLookupById[rhs]?.name ?? ""
                return lhsName < rhsName
            }
    }

    private var oscillatingExerciseIds: [UUID] {
        exerciseProgressionStates
            .filter { exerciseId, state in
                guard progressionEnabledExercises.contains(exerciseId),
                      state.recentOutcomes.count >= 2 else {
                    return false
                }
                return state.recentOutcomes[0] != state.recentOutcomes[1]
            }
            .map(\.key)
            .sorted { lhs, rhs in
                let lhsName = exerciseLookupById[lhs]?.name ?? ""
                let rhsName = exerciseLookupById[rhs]?.name ?? ""
                return lhsName < rhsName
            }
    }

    private func applyQuickPreset(_ preset: ProgressionRule) {
        defaultProgressionRule = preset
    }

    private func applyProfileToEnabledExercises() {
        for exerciseId in progressionEnabledExercises {
            exerciseProgressionProfiles[exerciseId] = defaultProgressionProfile
        }
    }

    private func applyConservativeProfile(to exerciseIds: [UUID]) {
        for exerciseId in exerciseIds {
            let isCardio = exerciseLookupById[exerciseId]?.exerciseType == .cardio
            exerciseProgressionProfiles[exerciseId] = isCardio ? conservativeCardioProfile : ProfilePreset.conservative.profile
        }
    }

    private func tightenReadinessGate(for exerciseIds: [UUID]) {
        for exerciseId in exerciseIds {
            var profile = exerciseProgressionProfiles[exerciseId] ?? defaultProgressionProfile
            profile.readinessGate.minimumCompletedSetRatio = min(
                0.95,
                profile.readinessGate.minimumCompletedSetRatio + 0.05
            )
            profile.readinessGate.minimumCompletedSets = min(
                5,
                max(profile.readinessGate.minimumCompletedSets + 1, 1)
            )
            exerciseProgressionProfiles[exerciseId] = profile
        }
    }

    private func applyCardioProfile(to exerciseIds: [UUID]) {
        for exerciseId in exerciseIds {
            exerciseProgressionProfiles[exerciseId] = conservativeCardioProfile
        }
    }

    private var conservativeCardioProfile: ProgressionProfile {
        var profile = ProgressionProfile.cardioDefault
        profile.readinessGate.minimumCompletedSetRatio = max(
            profile.readinessGate.minimumCompletedSetRatio,
            0.85
        )
        profile.decisionPolicy.progressThreshold = max(profile.decisionPolicy.progressThreshold, 0.74)
        profile.guardrails.maxProgressPercent = min(profile.guardrails.maxProgressPercent ?? 8, 6)
        return profile
    }

    private func preset(for profile: ProgressionProfile) -> ProfilePreset {
        if let maxProgress = profile.guardrails.maxProgressPercent {
            if maxProgress <= 6 { return .conservative }
            if maxProgress >= 11 { return .aggressive }
        }
        return .balanced
    }

    private func updateDefaultRule(_ mutate: (inout ProgressionRule) -> Void) {
        var updated = defaultProgressionRule ?? .conservative
        mutate(&updated)
        defaultProgressionRule = updated
    }

    private func stateSummary(for exerciseId: UUID) -> String? {
        guard let state = exerciseProgressionStates[exerciseId] else { return nil }
        let acceptance = state.acceptanceRate.map { Int(($0 * 100).rounded()) }

        if state.successStreak > 0 {
            if let acceptance {
                return "Success streak \(state.successStreak) · \(acceptance)% accept"
            }
            return "Success streak \(state.successStreak) · \(Int((state.confidence * 100).rounded()))%"
        }
        if state.failStreak > 0 {
            if let acceptance {
                return "Fail streak \(state.failStreak) · \(acceptance)% accept"
            }
            return "Fail streak \(state.failStreak) · \(Int((state.confidence * 100).rounded()))%"
        }
        if let acceptance {
            return "Acceptance \(acceptance)% · Confidence \(Int((state.confidence * 100).rounded()))%"
        }
        return "Confidence \(Int((state.confidence * 100).rounded()))%"
    }

    private func saveChanges() {
        var updatedProgram = program
        updatedProgram.progressionEnabledExercises = progressionEnabledExercises
        updatedProgram.exerciseProgressionOverrides = exerciseProgressionOverrides
        updatedProgram.exerciseProgressionStates = exerciseProgressionStates
        updatedProgram.defaultProgressionRule = defaultProgressionRule
        updatedProgram.defaultProgressionProfile = defaultProgressionProfile
        updatedProgram.exerciseProgressionProfiles = exerciseProgressionProfiles.filter {
            progressionEnabledExercises.contains($0.key)
        }
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
    private let durationRoundingOptions: [Double] = [15.0, 30.0, 60.0, 120.0]
    private let distanceRoundingOptions: [Double] = [0.05, 0.10, 0.25, 0.50]
    private let weightMinimumOptions: [Double] = [0, 2.5, 5.0, 10.0]
    private let repMinimumOptions: [Double] = [0, 1.0, 2.0]
    private let durationMinimumOptions: [Double] = [0, 15.0, 30.0, 60.0, 120.0]
    private let distanceMinimumOptions: [Double] = [0, 0.05, 0.10, 0.25]

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
        _minimumIncrease = State(initialValue: defaultRule.minimumIncrease ?? 0)
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
                            Text(formatValue(value, metric: targetMetric)).tag(value)
                        }
                    }

                    Picker("Minimum increase", selection: $minimumIncrease) {
                        ForEach(minimumOptions, id: \.self) { value in
                            if value == 0 {
                                Text("No minimum").tag(value)
                            } else {
                                Text(formatValue(value, metric: targetMetric)).tag(value)
                            }
                        }
                    }
                } header: {
                    Text("Progression Settings")
                }

                Section {
                    Text(exampleText)
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
        switch targetMetric {
        case .weight:
            return weightRoundingOptions
        case .reps:
            return repRoundingOptions
        case .duration:
            return durationRoundingOptions
        case .distance:
            return distanceRoundingOptions
        }
    }

    private var minimumOptions: [Double] {
        switch targetMetric {
        case .weight:
            return weightMinimumOptions
        case .reps:
            return repMinimumOptions
        case .duration:
            return durationMinimumOptions
        case .distance:
            return distanceMinimumOptions
        }
    }

    private func formatValue(_ value: Double, metric: ProgressionMetric) -> String {
        switch metric {
        case .weight:
            return "\(formatWeight(value)) lbs"
        case .reps:
            return "\(Int(value.rounded())) reps"
        case .duration:
            return formatDuration(Int(value.rounded()))
        case .distance:
            return "\(formatDistanceValue(value)) mi"
        }
    }

    private var exampleText: String {
        switch targetMetric {
        case .weight:
            return "Example: 100 lbs → \(formatWeight(calculateExample())) lbs"
        case .reps:
            return "Example: 8 reps → \(Int(calculateExample().rounded())) reps"
        case .duration:
            return "Example: 20:00 → \(formatDuration(Int(calculateExample().rounded())))"
        case .distance:
            return "Example: 2.00 mi → \(formatDistanceValue(calculateExample())) mi"
        }
    }

    private func calculateExample() -> Double {
        let base: Double
        switch targetMetric {
        case .weight:
            base = 100.0
        case .reps:
            base = 8.0
        case .duration:
            base = 1200.0
        case .distance:
            base = 2.0
        }
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
