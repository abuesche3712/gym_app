//
//  ActiveSessionView.swift
//  gym app
//
//  Main view for logging an active workout session
//

import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var showingFeelingPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Header
                sessionProgressHeader

                // Main Content
                if let currentModule = sessionViewModel.currentModule,
                   let currentExercise = sessionViewModel.currentExercise {

                    ScrollView {
                        VStack(spacing: 20) {
                            // Module indicator
                            moduleIndicator(currentModule)

                            // Exercise Card
                            exerciseCard(currentExercise)

                            // Set Input
                            setInputSection

                            // Previous Performance
                            previousPerformanceSection(exerciseName: currentExercise.exerciseName)
                        }
                        .padding()
                    }
                } else {
                    // Workout complete
                    workoutCompleteView
                }

                // Rest Timer (if running)
                if sessionViewModel.isRestTimerRunning {
                    restTimerBar
                }

                // Bottom Action Bar
                bottomActionBar
            }
            .navigationTitle(sessionViewModel.currentSession?.workoutName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCancelConfirmation = true
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Finish") {
                        showingEndConfirmation = true
                    }
                }
            }
            .confirmationDialog("Cancel Workout", isPresented: $showingCancelConfirmation) {
                Button("Cancel Workout", role: .destructive) {
                    sessionViewModel.cancelSession()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to cancel? Your progress will not be saved.")
            }
            .sheet(isPresented: $showingEndConfirmation) {
                EndSessionSheet { feeling, notes in
                    sessionViewModel.endSession(feeling: feeling, notes: notes)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Progress Header

    private var sessionProgressHeader: some View {
        VStack(spacing: 8) {
            // Timer
            Text(formatTime(sessionViewModel.sessionElapsedSeconds))
                .font(.system(size: 36, weight: .bold, design: .monospaced))

            // Progress bar
            if let session = sessionViewModel.currentSession {
                let totalModules = session.completedModules.count
                let progress = Double(sessionViewModel.currentModuleIndex) / Double(max(totalModules, 1))

                ProgressView(value: progress)
                    .tint(.green)

                Text("Module \(sessionViewModel.currentModuleIndex + 1) of \(totalModules)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Module Indicator

    private func moduleIndicator(_ module: CompletedModule) -> some View {
        HStack {
            Image(systemName: module.moduleType.icon)
                .foregroundStyle(Color(module.moduleType.color))

            Text(module.moduleName)
                .font(.headline)

            Spacer()

            Button {
                sessionViewModel.skipModule()
            } label: {
                Text("Skip Module")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(module.moduleType.color).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    sessionViewModel.skipExercise()
                } label: {
                    Text("Skip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Set progress
            if let setGroup = sessionViewModel.currentSetGroup {
                HStack {
                    Text("Set \(sessionViewModel.currentSetIndex + 1) of \(setGroup.sets.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Set group indicator
                    if sessionViewModel.currentExercise?.completedSetGroups.count ?? 0 > 1 {
                        Text("Group \(sessionViewModel.currentSetGroupIndex + 1)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Set Input Section

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: String = ""
    @State private var inputHoldTime: String = ""

    private var setInputSection: some View {
        VStack(spacing: 16) {
            if let exercise = sessionViewModel.currentExercise {
                switch exercise.exerciseType {
                case .strength:
                    strengthInput
                case .isometric:
                    isometricInput
                case .cardio:
                    cardioInput
                case .mobility, .explosive:
                    simpleRepsInput
                }
            }

            // Log Set Button
            Button {
                logCurrentSet()
            } label: {
                Label(sessionViewModel.isLastSet ? "Finish Exercise" : "Log Set & Rest",
                      systemImage: sessionViewModel.isLastSet ? "checkmark.circle.fill" : "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            loadSetDefaults()
        }
        .onChange(of: sessionViewModel.currentSetIndex) { _, _ in
            loadSetDefaults()
        }
    }

    private var strengthInput: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Weight
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight (\(appState.weightUnit.abbreviation))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $inputWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Reps
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $inputReps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // RPE
            VStack(alignment: .leading, spacing: 8) {
                Text("RPE (Rate of Perceived Exertion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { rpe in
                        Button {
                            inputRPE = rpe
                        } label: {
                            Text("\(rpe)")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(inputRPE == rpe ? Color.blue : Color(.systemBackground))
                                .foregroundStyle(inputRPE == rpe ? .white : .primary)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
    }

    private var isometricInput: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hold Time (seconds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0", text: $inputHoldTime)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var cardioInput: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration (seconds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0", text: $inputDuration)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var simpleRepsInput: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Previous Performance

    private func previousPerformanceSection(exerciseName: String) -> some View {
        Group {
            if let lastData = sessionViewModel.getLastSessionData(for: exerciseName) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Session")
                        .font(.headline)

                    ForEach(lastData.completedSetGroups) { setGroup in
                        ForEach(setGroup.sets) { set in
                            if let formatted = set.formattedStrength ?? set.formattedIsometric ?? set.formattedCardio {
                                Text("Set \(set.setNumber): \(formatted)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Rest Timer Bar

    private var restTimerBar: some View {
        HStack {
            Text("Rest")
                .font(.headline)

            Spacer()

            Text(formatTime(sessionViewModel.restTimerSeconds))
                .font(.system(size: 24, weight: .bold, design: .monospaced))

            Spacer()

            Button {
                sessionViewModel.stopRestTimer()
            } label: {
                Text("Skip")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.2))
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Quick weight buttons
            ForEach([-10, -5, 5, 10], id: \.self) { delta in
                Button {
                    adjustWeight(by: delta)
                } label: {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 50, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Workout Complete View

    private var workoutCompleteView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Workout Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("Great job! Tap Finish to save your session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func loadSetDefaults() {
        if let set = sessionViewModel.currentSet {
            inputWeight = set.weight.map { String(format: "%.0f", $0) } ?? ""
            inputReps = set.reps.map { "\($0)" } ?? ""
            inputRPE = set.rpe ?? 0
            inputDuration = set.duration.map { "\($0)" } ?? ""
            inputHoldTime = set.holdTime.map { "\($0)" } ?? ""
        }
    }

    private func adjustWeight(by delta: Int) {
        let current = Double(inputWeight) ?? 0
        inputWeight = String(format: "%.0f", max(0, current + Double(delta)))
    }

    private func logCurrentSet() {
        let weight = Double(inputWeight)
        let reps = Int(inputReps)
        let duration = Int(inputDuration)
        let holdTime = Int(inputHoldTime)

        sessionViewModel.logSet(
            weight: weight,
            reps: reps,
            rpe: inputRPE > 0 ? inputRPE : nil,
            duration: duration,
            holdTime: holdTime,
            completed: true
        )

        // Start rest timer if there are more sets
        if !sessionViewModel.isLastSet, let setGroup = sessionViewModel.currentSetGroup,
           let restPeriod = setGroup.sets.first?.restAfter ?? appState.defaultRestTime as Int? {
            sessionViewModel.startRestTimer(seconds: restPeriod > 0 ? restPeriod : appState.defaultRestTime)
        }

        // Clear inputs for next set
        inputRPE = 0
    }
}

// MARK: - End Session Sheet

struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Int?, String?) -> Void

    @State private var feeling: Int = 3
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("How did you feel?") {
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                feeling = value
                            } label: {
                                VStack {
                                    Text(feelingEmoji(value))
                                        .font(.largeTitle)
                                    Text("\(value)")
                                        .font(.caption)
                                }
                                .padding(8)
                                .background(feeling == value ? Color.blue.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(feeling, notes.isEmpty ? nil : notes)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "💪"
        default: return "😐"
        }
    }
}

#Preview {
    ActiveSessionView()
        .environmentObject(SessionViewModel())
        .environmentObject(AppState.shared)
}
