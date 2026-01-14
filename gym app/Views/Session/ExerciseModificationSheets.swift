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
    let onSubstitute: (String, ExerciseType, CardioMetric, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioMetric = .time
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
                Picker("Track By", selection: $cardioMetric) {
                    ForEach(CardioMetric.allCases) { metric in
                        Text(metric.rawValue.capitalized).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Distance Unit", selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.rawValue.capitalized).tag(unit)
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
        }
    }
}

// MARK: - Add Exercise to Module Sheet

struct AddExerciseToModuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let moduleName: String
    let onAdd: (String, ExerciseType, CardioMetric, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioMetric = .time
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
                Picker("Track By", selection: $cardioMetric) {
                    ForEach(CardioMetric.allCases) { metric in
                        Text(metric.rawValue.capitalized).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Distance Unit", selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.rawValue.capitalized).tag(unit)
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
