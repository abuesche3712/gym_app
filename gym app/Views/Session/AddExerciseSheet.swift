//
//  AddExerciseSheet.swift
//  gym app
//
//  Sheets for adding exercises and editing individual sets
//

import SwiftUI

// MARK: - Add Exercise to Module Sheet

struct AddExerciseToModuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let moduleName: String
    let onAdd: (String, ExerciseType, CardioTracking, DistanceUnit) -> Void

    @State private var exerciseName: String = ""
    @State private var selectedTemplate: ExerciseTemplate?
    @State private var exerciseType: ExerciseType = .strength
    @State private var cardioMetric: CardioTracking = .timeOnly
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var showingExercisePicker = false

    var body: some View {
        NavigationStack {
            Form {
                moduleInfoSection
                exercisePickerSection
                cardioSettingsSection
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedTemplate: $selectedTemplate,
                    customName: $exerciseName,
                    onSelect: { template in
                        if let template = template {
                            exerciseName = template.name
                            exerciseType = template.exerciseType
                            selectedTemplate = template
                            // Set cardio settings from template
                            if template.exerciseType == .cardio {
                                cardioMetric = template.cardioMetric
                                distanceUnit = template.distanceUnit
                            }
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
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

    private var exercisePickerSection: some View {
        Section("Exercise") {
            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Text("Exercise")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(exerciseName.isEmpty ? "Select exercise..." : exerciseName)
                        .foregroundColor(exerciseName.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !exerciseName.isEmpty {
                HStack {
                    Text("Type")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(exerciseType.displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var cardioSettingsSection: some View {
        if exerciseType == .cardio && !exerciseName.isEmpty {
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
            .foregroundColor(AppColors.dominant)
            .disabled(exerciseName.isEmpty)
        }
    }
}

// MARK: - Edit Individual Set Sheet

struct EditIndividualSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: SetData

    let exerciseType: ExerciseType
    let cardioMetric: CardioTracking
    let mobilityTracking: MobilityTracking
    let distanceUnit: DistanceUnit

    @State private var isCompleted: Bool = false
    @State private var weight: String = ""
    @State private var reps: Int = 0
    @State private var duration: Int = 0
    @State private var distance: String = ""
    @State private var holdTime: Int = 0
    @State private var rpe: Int? = nil
    @State private var showTimePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Toggle("Completed", isOn: $isCompleted)
                        .tint(AppColors.success)
                }

                Section("Set Data") {
                    setFieldsForExerciseType
                }

                if exerciseType == .strength {
                    Section("RPE (Optional)") {
                        Picker("RPE", selection: Binding(
                            get: { rpe ?? 0 },
                            set: { rpe = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Not set").tag(0)
                            ForEach(5...10, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Edit Set \(set.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveChanges() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.dominant)
                }
            }
            .onAppear { loadValues() }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(totalSeconds: $duration, title: "Duration")
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var setFieldsForExerciseType: some View {
        switch exerciseType {
        case .strength:
            HStack {
                Text("Weight")
                Spacer()
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text("lbs")
                    .foregroundColor(.secondary)
            }
            Stepper("Reps: \(reps)", value: $reps, in: 0...100)

        case .cardio:
            if cardioMetric.tracksTime {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(duration > 0 ? formatDuration(duration) : "Not set")
                            .foregroundColor(duration > 0 ? .primary : .secondary)
                    }
                }
            }
            if cardioMetric.tracksDistance {
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("0", text: $distance)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(distanceUnit.abbreviation)
                        .foregroundColor(.secondary)
                }
            }

        case .isometric:
            Stepper("Hold Time: \(holdTime)s", value: $holdTime, in: 0...600, step: 5)

        case .mobility:
            if mobilityTracking.tracksReps {
                Stepper("Reps: \(reps)", value: $reps, in: 0...100)
            }
            if mobilityTracking.tracksDuration {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(duration > 0 ? formatDuration(duration) : "Not set")
                            .foregroundColor(duration > 0 ? .primary : .secondary)
                    }
                }
            }

        case .explosive:
            Stepper("Reps: \(reps)", value: $reps, in: 0...50)

        case .recovery:
            Button {
                showTimePicker = true
            } label: {
                HStack {
                    Text("Duration")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(duration > 0 ? formatDuration(duration) : "Not set")
                        .foregroundColor(duration > 0 ? .primary : .secondary)
                }
            }
        }
    }

    private func loadValues() {
        isCompleted = set.completed
        weight = set.weight.map { formatWeight($0) } ?? ""
        reps = set.reps ?? 0
        duration = set.duration ?? 0
        distance = set.distance.map { formatDistanceValue($0) } ?? ""
        holdTime = set.holdTime ?? 0
        rpe = set.rpe
    }

    private func saveChanges() {
        set.completed = isCompleted
        set.weight = Double(weight)
        set.reps = reps > 0 ? reps : nil
        set.duration = duration > 0 ? duration : nil
        set.distance = Double(distance)
        set.holdTime = holdTime > 0 ? holdTime : nil
        set.rpe = rpe
        dismiss()
    }
}
