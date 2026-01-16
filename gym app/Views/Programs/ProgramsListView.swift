//
//  ProgramsListView.swift
//  gym app
//
//  List view for displaying and managing training programs
//

import SwiftUI

struct ProgramsListView: View {
    @EnvironmentObject private var programViewModel: ProgramViewModel
    @State private var showingCreateSheet = false
    @State private var selectedProgram: Program?

    var body: some View {
        NavigationStack {
            Group {
                if programViewModel.programs.isEmpty {
                    emptyStateView
                } else {
                    programsList
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateProgramSheet()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Programs Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a training program to auto-schedule\nyour workouts across multiple weeks.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateSheet = true
            } label: {
                Text("Create Program")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }

    private var programsList: some View {
        List {
            // Active Program Section
            if let activeProgram = programViewModel.activeProgram {
                Section {
                    NavigationLink(value: activeProgram) {
                        ProgramRow(program: activeProgram, isActive: true)
                    }
                } header: {
                    Text("Active Program")
                }
            }

            // All Programs Section
            Section {
                ForEach(programViewModel.programs.filter { !$0.isActive }) { program in
                    NavigationLink(value: program) {
                        ProgramRow(program: program, isActive: false)
                    }
                }
                .onDelete(perform: deletePrograms)
            } header: {
                if programViewModel.activeProgram != nil {
                    Text("Other Programs")
                } else {
                    Text("All Programs")
                }
            }
        }
        .navigationDestination(for: Program.self) { program in
            ProgramDetailView(program: program)
        }
    }

    private func deletePrograms(at offsets: IndexSet) {
        let inactivePrograms = programViewModel.programs.filter { !$0.isActive }
        for index in offsets {
            programViewModel.deleteProgram(inactivePrograms[index])
        }
    }
}

// MARK: - Program Row

struct ProgramRow: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .font(.headline)

                if isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label("\(program.durationWeeks) weeks", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(program.workoutSlots.count) slots", systemImage: "figure.run")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let description = program.programDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if isActive, let startDate = program.startDate {
                let progress = programProgress(startDate: startDate, durationWeeks: program.durationWeeks)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func programProgress(startDate: Date, durationWeeks: Int) -> Double {
        let totalDays = Double(durationWeeks * 7)
        let elapsed = Date().timeIntervalSince(startDate) / (24 * 60 * 60)
        return min(max(elapsed / totalDays, 0), 1)
    }
}

#Preview {
    ProgramsListView()
}
