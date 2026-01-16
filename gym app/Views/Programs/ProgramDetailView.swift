//
//  ProgramDetailView.swift
//  gym app
//
//  Detail view for a training program showing weekly schedule
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
    @State private var selectedDayOfWeek: Int?
    @State private var editMode: EditMode = .inactive

    private var currentProgram: Program {
        programViewModel.getProgram(id: program.id) ?? program
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                programHeaderCard

                // Weekly Schedule Grid
                weeklyScheduleSection

                // Action Buttons
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle(currentProgram.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        editMode = editMode == .active ? .inactive : .active
                    } label: {
                        Label(editMode == .active ? "Done Editing" : "Edit Slots",
                              systemImage: editMode == .active ? "checkmark" : "pencil")
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
    }

    // MARK: - Header Card

    private var programHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if currentProgram.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }

                    Text("\(currentProgram.durationWeeks) Week Program")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(currentProgram.workoutSlots.filter { $0.scheduleType == .weekly }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("workouts/week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let description = currentProgram.programDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if currentProgram.isActive, let startDate = currentProgram.startDate {
                Divider()
                programProgressSection(startDate: startDate)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func programProgressSection(startDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let progress = programProgress(startDate: startDate)
            let currentWeek = Int(progress * Double(currentProgram.durationWeeks)) + 1
            let weeksRemaining = currentProgram.durationWeeks - currentWeek + 1

            HStack {
                Text("Week \(min(currentWeek, currentProgram.durationWeeks)) of \(currentProgram.durationWeeks)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(weeksRemaining) weeks remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)

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
    }

    private func programProgress(startDate: Date) -> Double {
        let totalDays = Double(currentProgram.durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }

    // MARK: - Weekly Schedule Section

    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Schedule")
                    .font(.headline)

                Spacer()

                if editMode == .active {
                    Text("Tap day to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ProgramWeeklyGridView(
                program: currentProgram,
                editMode: $editMode,
                onDayTapped: { dayOfWeek in
                    selectedDayOfWeek = dayOfWeek
                    showingAddSlotSheet = true
                },
                onSlotRemove: { slotId in
                    programViewModel.removeWorkoutSlot(slotId, from: currentProgram)
                }
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
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
                .disabled(currentProgram.workoutSlots.isEmpty)
            }
        }
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
