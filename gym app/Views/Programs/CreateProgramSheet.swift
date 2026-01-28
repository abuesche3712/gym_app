//
//  CreateProgramSheet.swift
//  gym app
//
//  Sheet for creating a new training program
//

import SwiftUI

struct CreateProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programViewModel: ProgramViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var durationWeeks = 4

    private let durationOptions = [2, 4, 6, 8, 10, 12, 16]

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
                } footer: {
                    Text("Add a brief description of your program's goals or focus.")
                }

                Section {
                    infoRow(icon: "calendar", title: "Schedule Workouts", description: "Add workouts to specific days of the week")
                    infoRow(icon: "play.fill", title: "Activate", description: "Choose a start date to auto-populate your calendar")
                    infoRow(icon: "arrow.triangle.2.circlepath", title: "Repeating", description: "Weekly workouts repeat throughout the program")
                } header: {
                    Text("How Programs Work")
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProgram()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.programAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func createProgram() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let _ = programViewModel.createProgram(
            name: trimmedName,
            durationWeeks: durationWeeks,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription
        )

        dismiss()
    }
}

#Preview {
    CreateProgramSheet()
}
