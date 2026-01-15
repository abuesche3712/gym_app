//
//  ExerciseModificationSheets.swift
//  gym app
//
//  Sheets for modifying exercises during a live session
//

import SwiftUI

// MARK: - Substitute Exercise Sheet

struct SubstituteExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentExercise: SessionExercise?
    let onSubstitute: (String, ExerciseType, CardioTracking, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioTracking = .timeOnly
    @State private var distanceUnit: DistanceUnit = .meters

    var body: some View {
        NavigationStack {
            Form {
                currentExerciseSection
                newExerciseSection
                cardioSettingsSection
                suggestionsSection
            }
            .navigationTitle("Substitute Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { loadDefaults() }
        }
    }

    @ViewBuilder
    private var currentExerciseSection: some View {
        if let current = currentExercise {
            Section {
                HStack {
                    Text("Replacing")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(current.isSubstitution ? (current.originalExerciseName ?? current.exerciseName) : current.exerciseName)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private var newExerciseSection: some View {
        Section("New Exercise") {
            TextField("Exercise Name", text: $exerciseName)
            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases) { type in
                    Label(type.rawValue.capitalized, systemImage: type.icon).tag(type)
                }
            }
        }
    }

    @ViewBuilder
    private var cardioSettingsSection: some View {
        if exerciseType == .cardio {
            Section("Cardio Settings") {
                Picker("Track", selection: $cardioMetric) {
                    Text("Time").tag(CardioTracking.timeOnly)
                    Text("Distance").tag(CardioTracking.distanceOnly)
                    Text("Both").tag(CardioTracking.both)
                }
                .pickerStyle(.segmented)

                if cardioMetric.tracksDistance {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        Section("Or Pick from Library") {
            ForEach(suggestedExercises, id: \.name) { suggestion in
                Button {
                    exerciseName = suggestion.name
                    exerciseType = suggestion.type
                } label: {
                    suggestionRow(suggestion)
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: (name: String, type: ExerciseType)) -> some View {
        HStack {
            Image(systemName: suggestion.type.icon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24)
            Text(suggestion.name)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(suggestion.type.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Substitute") {
                onSubstitute(exerciseName, exerciseType, cardioMetric, distanceUnit)
            }
            .fontWeight(.semibold)
            .foregroundColor(AppColors.accentBlue)
            .disabled(exerciseName.isEmpty)
        }
    }

    private func loadDefaults() {
        if let current = currentExercise {
            exerciseType = current.exerciseType
            cardioMetric = current.cardioMetric
            distanceUnit = current.distanceUnit
        }
    }

    private var suggestedExercises: [(name: String, type: ExerciseType)] {
        guard let current = currentExercise else { return [] }
        switch current.exerciseType {
        case .strength:
            return [
                ("Bench Press", .strength),
                ("Overhead Press", .strength),
                ("Dumbbell Press", .strength),
                ("Squat", .strength),
                ("Leg Press", .strength),
                ("Deadlift", .strength),
                ("Rows", .strength),
                ("Lat Pulldown", .strength),
                ("Pull-ups", .strength),
                ("Dips", .strength)
            ]
        case .cardio:
            return [
                ("Treadmill Run", .cardio),
                ("Stationary Bike", .cardio),
                ("Rowing Machine", .cardio),
                ("Elliptical", .cardio),
                ("Jump Rope", .cardio)
            ]
        case .isometric:
            return [
                ("Plank", .isometric),
                ("Wall Sit", .isometric),
                ("Dead Hang", .isometric),
                ("L-Sit", .isometric)
            ]
        case .mobility:
            return [
                ("Hip Stretches", .mobility),
                ("Shoulder Stretches", .mobility),
                ("Foam Rolling", .mobility)
            ]
        case .explosive:
            return [
                ("Box Jumps", .explosive),
                ("Jump Squats", .explosive),
                ("Medicine Ball Throws", .explosive)
            ]
        case .recovery:
            return [
                ("Stretching", .recovery),
                ("Foam Rolling", .recovery),
                ("Cool Down Walk", .recovery),
                ("Breathing Exercises", .recovery)
            ]
        }
    }
}

// MARK: - Add Exercise to Module Sheet

// MARK: - Edit Exercise Sheet

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: SessionExercise
    let moduleIndex: Int
    let exerciseIndex: Int
    let onSave: (Int, Int, SessionExercise) -> Void

    // Editable fields
    @State private var restPeriod: Int = 90
    @State private var numberOfSets: Int = 3
    @State private var targetWeight: Double = 0
    @State private var targetReps: Int = 10
    @State private var targetDuration: Int = 0
    @State private var targetHoldTime: Int = 0
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioTracking = .timeOnly
    @State private var distanceUnit: DistanceUnit = .meters

    var body: some View {
        NavigationStack {
            Form {
                // Current exercise info
                Section {
                    HStack {
                        Text("Exercise")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(exercise.exerciseName)
                            .fontWeight(.medium)
                    }
                }

                // Rest Period
                Section("Rest Between Sets") {
                    restPeriodPicker
                }

                // Set Scheme
                Section("Set Scheme") {
                    Stepper("Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)

                    if exerciseType == .strength {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("0", value: $targetWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("lbs")
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)
                    } else if exerciseType == .isometric {
                        HStack {
                            Text("Hold Time")
                            Spacer()
                            Text(formatDuration(targetHoldTime))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Stepper("Seconds: \(targetHoldTime)", value: $targetHoldTime, in: 5...300, step: 5)
                    } else if exerciseType == .cardio {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(formatDuration(targetDuration))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Stepper("Seconds: \(targetDuration)", value: $targetDuration, in: 0...3600, step: 30)
                    }
                }

                // Exercise Type
                Section("Exercise Type") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases) { type in
                            Label(type.rawValue.capitalized, systemImage: type.icon).tag(type)
                        }
                    }
                }

                // Cardio Settings
                if exerciseType == .cardio {
                    Section("Cardio Settings") {
                        Picker("Track", selection: $cardioMetric) {
                            Text("Time").tag(CardioTracking.timeOnly)
                            Text("Distance").tag(CardioTracking.distanceOnly)
                            Text("Both").tag(CardioTracking.both)
                        }
                        .pickerStyle(.segmented)

                        if cardioMetric.tracksDistance {
                            Picker("Distance Unit", selection: $distanceUnit) {
                                ForEach(DistanceUnit.allCases) { unit in
                                    Text(unit.rawValue.capitalized).tag(unit)
                                }
                            }
                        }
                    }
                }

                // Info about preserving completed sets
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.accentBlue)
                        Text("Completed sets will be preserved. Changes apply to remaining sets.")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
            .onAppear { loadCurrentValues() }
        }
    }

    // MARK: - Rest Period Picker

    private var restPeriodPicker: some View {
        Picker("Rest", selection: $restPeriod) {
            Text("30s").tag(30)
            Text("45s").tag(45)
            Text("60s").tag(60)
            Text("90s").tag(90)
            Text("2 min").tag(120)
            Text("3 min").tag(180)
            Text("4 min").tag(240)
            Text("5 min").tag(300)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Load Current Values

    private func loadCurrentValues() {
        exerciseType = exercise.exerciseType
        cardioMetric = exercise.cardioMetric
        distanceUnit = exercise.distanceUnit

        // Count total sets
        numberOfSets = exercise.completedSetGroups.reduce(0) { $0 + $1.sets.count }

        // Get rest period from first set group
        if let firstGroup = exercise.completedSetGroups.first {
            restPeriod = firstGroup.restPeriod ?? 90
        }

        // Get targets from first uncompleted set, or first set
        let allSets = exercise.completedSetGroups.flatMap { $0.sets }
        let targetSet = allSets.first { !$0.completed } ?? allSets.first

        if let set = targetSet {
            targetWeight = set.weight ?? 0
            targetReps = set.reps ?? 10
            targetDuration = set.duration ?? 0
            targetHoldTime = set.holdTime ?? 0
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        var updatedExercise = exercise
        updatedExercise.exerciseType = exerciseType
        updatedExercise.cardioMetric = cardioMetric
        updatedExercise.distanceUnit = distanceUnit

        // Count completed sets
        let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
        let completedCount = completedSets.count

        // Build new set groups with updated targets
        var newSetGroups: [CompletedSetGroup] = []

        if completedCount > 0 {
            // Keep completed sets in their original set group structure
            var preservedSets: [SetData] = []
            for setGroup in exercise.completedSetGroups {
                for set in setGroup.sets where set.completed {
                    preservedSets.append(set)
                }
            }

            // Create a set group for completed sets
            if !preservedSets.isEmpty {
                let completedGroup = CompletedSetGroup(
                    setGroupId: UUID(),
                    restPeriod: restPeriod,
                    sets: preservedSets
                )
                newSetGroups.append(completedGroup)
            }
        }

        // Add remaining sets with new targets
        let remainingSets = numberOfSets - completedCount
        if remainingSets > 0 {
            var newSets: [SetData] = []
            for i in 0..<remainingSets {
                let setNumber = completedCount + i + 1
                newSets.append(SetData(
                    setNumber: setNumber,
                    weight: exerciseType == .strength ? targetWeight : nil,
                    reps: exerciseType == .strength || exerciseType == .explosive || exerciseType == .mobility ? targetReps : nil,
                    completed: false,
                    duration: exerciseType == .cardio ? targetDuration : nil,
                    holdTime: exerciseType == .isometric ? targetHoldTime : nil
                ))
            }

            let remainingGroup = CompletedSetGroup(
                setGroupId: UUID(),
                restPeriod: restPeriod,
                sets: newSets
            )
            newSetGroups.append(remainingGroup)
        }

        updatedExercise.completedSetGroups = newSetGroups

        onSave(moduleIndex, exerciseIndex, updatedExercise)
        dismiss()
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return "\(mins):\(String(format: "%02d", secs))"
            }
            return "\(mins) min"
        }
        return "\(seconds)s"
    }
}

// MARK: - Add Exercise to Module Sheet

struct AddExerciseToModuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let moduleName: String
    let onAdd: (String, ExerciseType, CardioTracking, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioTracking = .timeOnly
    @State private var distanceUnit: DistanceUnit = .meters

    var body: some View {
        NavigationStack {
            Form {
                moduleInfoSection
                exerciseDetailsSection
                cardioSettingsSection
                quickAddSection
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    private var moduleInfoSection: some View {
        Section {
            HStack {
                Text("Adding to")
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(moduleName)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private var exerciseDetailsSection: some View {
        Section("Exercise Details") {
            TextField("Exercise Name", text: $exerciseName)
            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases) { type in
                    Label(type.rawValue.capitalized, systemImage: type.icon).tag(type)
                }
            }
        }
    }

    @ViewBuilder
    private var cardioSettingsSection: some View {
        if exerciseType == .cardio {
            Section("Cardio Settings") {
                Picker("Track", selection: $cardioMetric) {
                    Text("Time").tag(CardioTracking.timeOnly)
                    Text("Distance").tag(CardioTracking.distanceOnly)
                    Text("Both").tag(CardioTracking.both)
                }
                .pickerStyle(.segmented)

                if cardioMetric.tracksDistance {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                }
            }
        }
    }

    private var quickAddSection: some View {
        Section("Quick Add") {
            ForEach(suggestedExercises, id: \.name) { suggestion in
                Button {
                    exerciseName = suggestion.name
                    exerciseType = suggestion.type
                } label: {
                    suggestionRow(suggestion)
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: (name: String, type: ExerciseType)) -> some View {
        HStack {
            Image(systemName: suggestion.type.icon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24)
            Text(suggestion.name)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(suggestion.type.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                onAdd(exerciseName, exerciseType, cardioMetric, distanceUnit)
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundColor(AppColors.accentBlue)
            .disabled(exerciseName.isEmpty)
        }
    }

    private var suggestedExercises: [(name: String, type: ExerciseType)] {
        [
            ("Bench Press", .strength),
            ("Squat", .strength),
            ("Deadlift", .strength),
            ("Overhead Press", .strength),
            ("Pull-ups", .strength),
            ("Rows", .strength),
            ("Lunges", .strength),
            ("Dumbbell Curls", .strength),
            ("Plank", .isometric),
            ("Treadmill Run", .cardio),
            ("Stretching", .mobility)
        ]
    }
}
