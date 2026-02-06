//
//  ProgramDetailView.swift
//  gym app
//
//  Detail view for editing a training program's weekly schedule
//

import SwiftUI

struct ProgramDetailView: View {
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @Environment(\.dismiss) private var dismiss

    let program: Program

    @State private var showingActivateSheet = false
    @State private var showingDeactivateAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingAddSlotSheet = false
    @State private var showingEditSheet = false
    @State private var showingProgressionConfig = false
    @State private var selectedDayOfWeek: Int?
    @State private var showingShareSheet = false
    @State private var showingPostToFeed = false

    private var currentProgram: Program {
        programViewModel.getProgram(id: program.id) ?? program
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Editable Header Card
                editableHeaderCard

                // Progress Section (only when active)
                if currentProgram.isActive, let startDate = currentProgram.startDate {
                    progressCard(startDate: startDate)
                }

                // Weekly Schedule Grid
                weeklyScheduleSection

                // Action Buttons
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle("Edit Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    Button {
                        showingPostToFeed = true
                    } label: {
                        Label("Post to Feed", systemImage: "rectangle.stack")
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share with Friend", systemImage: "paperplane")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Program", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingActivateSheet) {
            ActivateProgramSheet(program: currentProgram)
        }
        .sheet(isPresented: $showingAddSlotSheet) {
            if let dayOfWeek = selectedDayOfWeek {
                AddWorkoutSlotSheet(program: currentProgram, dayOfWeek: dayOfWeek)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProgramSheet(program: currentProgram)
        }
        .sheet(isPresented: $showingProgressionConfig) {
            ProgressionConfigurationView(program: currentProgram)
        }
        .alert("Deactivate Program?", isPresented: $showingDeactivateAlert) {
            Button("Keep Schedule") {
                programViewModel.deactivateProgram(currentProgram, removeFutureScheduled: false)
            }
            Button("Remove Future Workouts", role: .destructive) {
                programViewModel.deactivateProgram(currentProgram, removeFutureScheduled: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Would you like to keep the scheduled workouts or remove future ones?")
        }
        .alert("Delete Program?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                programViewModel.deleteProgram(currentProgram)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the program. Scheduled workouts will be kept.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareWithFriendSheet(content: currentProgram) { conversationWithProfile in
                let chatViewModel = ChatViewModel(
                    conversation: conversationWithProfile.conversation,
                    otherParticipant: conversationWithProfile.otherParticipant,
                    otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                )
                let content = try currentProgram.createMessageContent()
                try await chatViewModel.sendSharedContent(content)
            }
        }
        .sheet(isPresented: $showingPostToFeed) {
            ComposePostSheet(content: currentProgram)
        }
    }

    // MARK: - Editable Header Card

    private var editableHeaderCard: some View {
        Button {
            showingEditSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(currentProgram.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        if currentProgram.isActive {
                            Text("ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accent2)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 16) {
                        Label("\(currentProgram.durationWeeks) weeks", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label("\(currentProgram.workoutSlots.filter { $0.scheduleType == .weekly }.count) workouts/week", systemImage: "figure.run")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let description = currentProgram.programDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accent2)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Card

    private func progressCard(startDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let progress = programProgress(startDate: startDate)
            let currentWeek = Int(progress * Double(currentProgram.durationWeeks)) + 1
            let weeksRemaining = currentProgram.durationWeeks - currentWeek + 1

            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text("Week \(min(currentWeek, currentProgram.durationWeeks)) of \(currentProgram.durationWeeks)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(max(weeksRemaining, 0)) weeks remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            AnimatedProgressBar(
                progress: progress,
                gradient: AppGradients.programGradient,
                height: 8
            )

            HStack {
                Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let endDate = currentProgram.endDate {
                    Text("Ends \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .gradientCard(accent: AppColors.accent2)
    }

    private func programProgress(startDate: Date) -> Double {
        let totalDays = Double(currentProgram.durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }

    // MARK: - Weekly Schedule Section

    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Schedule")
                .font(.headline)

            Text("Tap + to add a workout or module, tap X to remove")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgramWeeklyGridView(
                program: currentProgram,
                onDayTapped: { dayOfWeek in
                    selectedDayOfWeek = dayOfWeek
                    showingAddSlotSheet = true
                },
                onSlotRemove: { slotId in
                    programViewModel.removeWorkoutSlot(slotId, from: currentProgram)
                    // If program is active, update the schedule
                    if currentProgram.isActive {
                        programViewModel.updateActiveProgramSchedule(currentProgram)
                    }
                },
                onModuleSlotRemove: { slotId in
                    programViewModel.removeModuleSlot(slotId, from: currentProgram)
                    // If program is active, update the schedule
                    if currentProgram.isActive {
                        programViewModel.updateActiveProgramSchedule(currentProgram)
                    }
                }
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Progression configuration (only show if progression is enabled)
            if currentProgram.progressionEnabled {
                Button {
                    showingProgressionConfig = true
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Configure Progression")
                        Spacer()

                        // Show count of exercises with progression
                        let count = currentProgram.progressionEnabledExercises.count
                        Text("\(count) exercise\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if currentProgram.isActive {
                Button {
                    showingDeactivateAlert = true
                } label: {
                    Label("Deactivate Program", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingActivateSheet = true
                } label: {
                    Label("Activate Program", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent2)
                .disabled(currentProgram.workoutSlots.isEmpty && currentProgram.moduleSlots.isEmpty)

                if currentProgram.workoutSlots.isEmpty && currentProgram.moduleSlots.isEmpty {
                    Text("Add workouts or modules to the weekly schedule before activating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Edit Program Sheet

struct EditProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel

    let program: Program

    @State private var name: String
    @State private var description: String
    @State private var durationWeeks: Int

    private let durationOptions = [2, 4, 6, 8, 10, 12, 16]

    init(program: Program) {
        self.program = program
        _name = State(initialValue: program.name)
        _description = State(initialValue: program.programDescription ?? "")
        _durationWeeks = State(initialValue: program.durationWeeks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Program Name", text: $name)

                    Picker("Duration", selection: $durationWeeks) {
                        ForEach(durationOptions, id: \.self) { weeks in
                            Text("\(weeks) weeks").tag(weeks)
                        }
                    }
                } header: {
                    Text("Program Details")
                }

                Section {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                }

                if program.isActive {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.dominant)

                            Text("Changes to duration will update the program end date. The scheduled workouts will be adjusted accordingly.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Program")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        var updatedProgram = program
        updatedProgram.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProgram.programDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)

        let durationChanged = updatedProgram.durationWeeks != durationWeeks
        updatedProgram.durationWeeks = durationWeeks

        // Recalculate end date if active and duration changed
        if updatedProgram.isActive, let startDate = updatedProgram.startDate, durationChanged {
            updatedProgram.endDate = Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: startDate)
        }

        programViewModel.saveProgram(updatedProgram)

        // If active and duration changed, update the schedule
        if updatedProgram.isActive && durationChanged {
            programViewModel.updateActiveProgramSchedule(updatedProgram)
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProgramDetailView(program: Program(
            name: "8-Week Hypertrophy",
            programDescription: "Focus on muscle growth with progressive overload",
            durationWeeks: 8
        ))
    }
}
