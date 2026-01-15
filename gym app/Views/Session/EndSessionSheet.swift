//
//  EndSessionSheet.swift
//  gym app
//
//  Sheet for finishing a workout session with exercise review
//

import SwiftUI

struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var session: Session?
    let onSave: (Int?, String?) -> Void

    @State private var feeling: Int = 5
    @State private var notes: String = ""
    @State private var expandedExercises: Set<UUID> = []
    @State private var editingSet: EditingSetInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Rating section
                    ratingSection

                    // Exercises review section
                    if let session = session {
                        exercisesSection(session: session)
                    }

                    // Notes section
                    notesSection
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(feeling, notes.isEmpty ? nil : notes)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
            .sheet(item: $editingSet) { editing in
                SetEditSheet(
                    setData: binding(for: editing),
                    exerciseType: editing.exerciseType,
                    isBodyweight: editing.isBodyweight,
                    distanceUnit: editing.distanceUnit
                )
            }
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("How did you feel?")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            // 1-10 rating buttons in two rows
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(1...5, id: \.self) { value in
                        ratingButton(value)
                    }
                }
                HStack(spacing: AppSpacing.sm) {
                    ForEach(6...10, id: \.self) { value in
                        ratingButton(value)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .fill(AppColors.cardBackground)
        )
    }

    private func ratingButton(_ value: Int) -> some View {
        Button {
            withAnimation(AppAnimation.quick) {
                feeling = value
            }
        } label: {
            Text("\(value)")
                .font(.headline)
                .foregroundColor(feeling == value ? .white : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(feeling == value ? ratingColor(value) : AppColors.surfaceLight)
                )
        }
        .buttonStyle(.plain)
    }

    private func ratingColor(_ value: Int) -> Color {
        switch value {
        case 1...3: return AppColors.error
        case 4...5: return AppColors.warning
        case 6...7: return AppColors.accentBlue
        case 8...10: return AppColors.success
        default: return AppColors.accentBlue
        }
    }

    // MARK: - Exercises Section

    private func exercisesSection(session: Session) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            ForEach(session.completedModules) { module in
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    // Module header
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: module.moduleType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.moduleColor(module.moduleType))
                        Text(module.moduleName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Exercises in this module
                    ForEach(module.completedExercises) { exercise in
                        exerciseCard(exercise: exercise, moduleId: module.id)
                    }
                }
            }
        }
    }

    private func exerciseCard(exercise: SessionExercise, moduleId: UUID) -> some View {
        VStack(spacing: 0) {
            // Exercise header - tappable to expand
            Button {
                withAnimation(AppAnimation.quick) {
                    if expandedExercises.contains(exercise.id) {
                        expandedExercises.remove(exercise.id)
                    } else {
                        expandedExercises.insert(exercise.id)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        // Set summary
                        let completedSets = exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }
                        Text("\(completedSets.count) sets completed")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: expandedExercises.contains(exercise.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
            }
            .buttonStyle(.plain)

            // Expanded content
            if expandedExercises.contains(exercise.id) {
                VStack(spacing: AppSpacing.sm) {
                    Divider()
                        .background(AppColors.border.opacity(0.5))

                    // Sets list
                    ForEach(exercise.completedSetGroups) { setGroup in
                        ForEach(setGroup.sets) { set in
                            setRow(set: set, exercise: exercise, setGroupId: setGroup.id, moduleId: moduleId)
                        }
                    }

                    Divider()
                        .background(AppColors.border.opacity(0.5))

                    // Progression buttons
                    progressionButtons(exercise: exercise, moduleId: moduleId)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func setRow(set: SetData, exercise: SessionExercise, setGroupId: UUID, moduleId: UUID) -> some View {
        Button {
            editingSet = EditingSetInfo(
                moduleId: moduleId,
                exerciseId: exercise.id,
                setGroupId: setGroupId,
                setId: set.id,
                exerciseType: exercise.exerciseType,
                isBodyweight: exercise.isBodyweight,
                distanceUnit: exercise.distanceUnit
            )
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Set number
                Text("\(set.setNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(AppColors.surfaceLight))

                // Set data formatted
                Text(formatSetData(set: set, exercise: exercise))
                    .font(.subheadline)
                    .foregroundColor(set.completed ? AppColors.textPrimary : AppColors.textTertiary)

                Spacer()

                // Edit indicator
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatSetData(set: SetData, exercise: SessionExercise) -> String {
        switch exercise.exerciseType {
        case .strength:
            var parts: [String] = []
            if exercise.isBodyweight {
                if let weight = set.weight, weight > 0 {
                    parts.append("BW+\(formatWeight(weight))")
                } else {
                    parts.append("BW")
                }
            } else if let weight = set.weight {
                parts.append("\(formatWeight(weight)) lbs")
            }
            if let reps = set.reps {
                parts.append("× \(reps)")
            }
            if let rpe = set.rpe {
                parts.append("@ RPE \(rpe)")
            }
            return parts.joined(separator: " ")

        case .isometric:
            var parts: [String] = []
            if let holdTime = set.holdTime {
                parts.append(formatDuration(holdTime) + " hold")
            }
            if let intensity = set.intensity {
                parts.append("@ \(intensity)/10")
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " ")

        case .cardio:
            var parts: [String] = []
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            if let distance = set.distance, distance > 0 {
                parts.append("\(formatDistance(distance)) \(exercise.distanceUnit.abbreviation)")
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " / ")

        case .explosive:
            var parts: [String] = []
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if let height = set.height {
                parts.append("@ \(formatHeight(height))")
            }
            if let quality = set.quality {
                parts.append("(\(quality)/5)")
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " ")

        case .mobility:
            var parts: [String] = []
            if let reps = set.reps {
                parts.append("\(reps) reps")
            }
            if let duration = set.duration, duration > 0 {
                parts.append(formatDuration(duration))
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " / ")

        case .recovery:
            var parts: [String] = []
            if let duration = set.duration {
                parts.append(formatDuration(duration))
            }
            if let temp = set.temperature {
                parts.append("@ \(temp)°F")
            }
            return parts.isEmpty ? "–" : parts.joined(separator: " ")
        }
    }

    private func progressionButtons(exercise: SessionExercise, moduleId: UUID) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Next session:")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(ProgressionRecommendation.allCases) { recommendation in
                    progressionButton(recommendation, exercise: exercise, moduleId: moduleId)
                }
            }
        }
    }

    private func progressionButton(_ recommendation: ProgressionRecommendation, exercise: SessionExercise, moduleId: UUID) -> some View {
        let isSelected = exercise.progressionRecommendation == recommendation
        let color = Color(recommendation.color)

        return Button {
            updateProgression(moduleId: moduleId, exerciseId: exercise.id, recommendation: recommendation)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: recommendation.icon)
                    .font(.system(size: 12))
                Text(recommendation.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    private func updateProgression(moduleId: UUID, exerciseId: UUID, recommendation: ProgressionRecommendation) {
        guard var currentSession = session else { return }

        for moduleIndex in currentSession.completedModules.indices {
            if currentSession.completedModules[moduleIndex].id == moduleId {
                for exerciseIndex in currentSession.completedModules[moduleIndex].completedExercises.indices {
                    if currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].id == exerciseId {
                        // Toggle: if already selected, deselect; otherwise select
                        let current = currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].progressionRecommendation
                        currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].progressionRecommendation = current == recommendation ? nil : recommendation
                        break
                    }
                }
                break
            }
        }

        session = currentSession
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Notes (optional)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textSecondary)

            TextEditor(text: $notes)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.md)
                .frame(minHeight: 80)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.cardBackground)
                )
        }
    }

    // MARK: - Set Editing Helpers

    private func binding(for editing: EditingSetInfo) -> Binding<SetData> {
        Binding(
            get: {
                guard let session = session else { return SetData(setNumber: 1) }
                for module in session.completedModules where module.id == editing.moduleId {
                    for exercise in module.completedExercises where exercise.id == editing.exerciseId {
                        for setGroup in exercise.completedSetGroups where setGroup.id == editing.setGroupId {
                            if let set = setGroup.sets.first(where: { $0.id == editing.setId }) {
                                return set
                            }
                        }
                    }
                }
                return SetData(setNumber: 1)
            },
            set: { newValue in
                guard var currentSession = session else { return }
                for moduleIndex in currentSession.completedModules.indices {
                    if currentSession.completedModules[moduleIndex].id == editing.moduleId {
                        for exerciseIndex in currentSession.completedModules[moduleIndex].completedExercises.indices {
                            if currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].id == editing.exerciseId {
                                for setGroupIndex in currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups.indices {
                                    if currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[setGroupIndex].id == editing.setGroupId {
                                        for setIndex in currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[setGroupIndex].sets.indices {
                                            if currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[setGroupIndex].sets[setIndex].id == editing.setId {
                                                currentSession.completedModules[moduleIndex].completedExercises[exerciseIndex].completedSetGroups[setGroupIndex].sets[setIndex] = newValue
                                                session = currentSession
                                                return
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Editing Set Info

struct EditingSetInfo: Identifiable {
    let id = UUID()
    let moduleId: UUID
    let exerciseId: UUID
    let setGroupId: UUID
    let setId: UUID
    let exerciseType: ExerciseType
    let isBodyweight: Bool
    let distanceUnit: DistanceUnit
}

// MARK: - Set Edit Sheet

struct SetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var setData: SetData
    let exerciseType: ExerciseType
    let isBodyweight: Bool
    let distanceUnit: DistanceUnit

    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var rpe: Int = 0
    @State private var duration: Int = 0
    @State private var holdTime: Int = 0
    @State private var distance: String = ""
    @State private var height: String = ""
    @State private var quality: Int = 0
    @State private var intensity: Int = 0
    @State private var temperature: String = ""

    var body: some View {
        NavigationStack {
            Form {
                switch exerciseType {
                case .strength:
                    if !isBodyweight {
                        TextField("Weight (lbs)", text: $weight)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    Picker("RPE", selection: $rpe) {
                        Text("None").tag(0)
                        ForEach(5...10, id: \.self) { Text("\($0)").tag($0) }
                    }

                case .isometric:
                    TimePickerView(totalSeconds: $holdTime, maxMinutes: 5, label: "Hold Time")
                    Picker("Intensity", selection: $intensity) {
                        Text("None").tag(0)
                        ForEach(1...10, id: \.self) { Text("\($0)/10").tag($0) }
                    }

                case .cardio:
                    TimePickerView(totalSeconds: $duration, maxMinutes: 60, label: "Duration")
                    HStack {
                        TextField("Distance", text: $distance)
                            .keyboardType(.decimalPad)
                        Text(distanceUnit.abbreviation)
                            .foregroundColor(.secondary)
                    }

                case .explosive:
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    TextField("Height (inches)", text: $height)
                        .keyboardType(.decimalPad)
                    Picker("Quality", selection: $quality) {
                        Text("None").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0)/5").tag($0) }
                    }

                case .mobility:
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    TimePickerView(totalSeconds: $duration, maxMinutes: 10, label: "Duration")

                case .recovery:
                    TimePickerView(totalSeconds: $duration, maxMinutes: 60, label: "Duration")
                    TextField("Temperature (°F)", text: $temperature)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Set \(setData.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear { loadData() }
        }
        .presentationDetents([.medium])
    }

    private func loadData() {
        weight = setData.weight.map { formatWeight($0) } ?? ""
        reps = setData.reps.map { "\($0)" } ?? ""
        rpe = setData.rpe ?? 0
        duration = setData.duration ?? 0
        holdTime = setData.holdTime ?? 0
        distance = setData.distance.map { formatDistance($0) } ?? ""
        height = setData.height.map { String(format: "%.1f", $0) } ?? ""
        quality = setData.quality ?? 0
        intensity = setData.intensity ?? 0
        temperature = setData.temperature.map { "\($0)" } ?? ""
    }

    private func saveChanges() {
        setData.weight = Double(weight)
        setData.reps = Int(reps)
        setData.rpe = rpe > 0 ? rpe : nil
        setData.duration = duration > 0 ? duration : nil
        setData.holdTime = holdTime > 0 ? holdTime : nil
        setData.distance = Double(distance)
        setData.height = Double(height)
        setData.quality = quality > 0 ? quality : nil
        setData.intensity = intensity > 0 ? intensity : nil
        setData.temperature = Int(temperature)
    }
}
