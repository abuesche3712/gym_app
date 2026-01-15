//
//  ExerciseDetailView.swift
//  gym app
//
//  Detailed view of an exercise
//

import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var moduleViewModel: ModuleViewModel
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let moduleId: UUID

    @State private var showingEditExercise = false

    private var currentExercise: Exercise {
        if let module = moduleViewModel.getModule(id: moduleId),
           let ex = module.exercises.first(where: { $0.id == exercise.id }) {
            return ex
        }
        return exercise
    }

    var body: some View {
        List {
            // Exercise Info
            Section("Info") {
                LabeledContent("Name", value: currentExercise.name)
                LabeledContent("Type", value: currentExercise.exerciseType.displayName)

                if currentExercise.progressionType != .none {
                    LabeledContent("Progression", value: currentExercise.progressionType.displayName)
                }
            }

            // Muscles & Equipment
            if !currentExercise.muscleGroupIds.isEmpty || !currentExercise.implementIds.isEmpty {
                Section("Muscles & Equipment") {
                    if !currentExercise.muscleGroupIds.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Muscles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ExerciseMuscleGroupsDisplay(muscleGroupIds: currentExercise.muscleGroupIds)
                        }
                    }

                    if !currentExercise.implementIds.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Equipment")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ExerciseImplementsDisplay(implementIds: currentExercise.implementIds)
                        }
                    }
                }
            }

            // Set Groups
            Section("Sets") {
                if currentExercise.setGroups.isEmpty {
                    Text("No sets defined")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(currentExercise.setGroups.enumerated()), id: \.element.id) { index, setGroup in
                        SetGroupRow(setGroup: setGroup, index: index + 1)
                    }
                }
            }

            // Tracking Metrics
            Section("Tracking") {
                FlowLayout(spacing: 8) {
                    ForEach(currentExercise.trackingMetrics, id: \.self) { metric in
                        Text(metric.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }

            // Notes
            if let notes = currentExercise.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(currentExercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditExercise = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditExercise) {
            NavigationStack {
                ExerciseFormView(exercise: currentExercise, moduleId: moduleId)
            }
        }
    }
}

// MARK: - Set Group Row

struct SetGroupRow: View {
    let setGroup: SetGroup
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Group \(index)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let notes = setGroup.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(setGroup.formattedTarget)
                .font(.headline)

            if let rest = setGroup.formattedRest {
                Label(rest, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Muscle Groups Display

struct ExerciseMuscleGroupsDisplay: View {
    let muscleGroupIds: Set<UUID>
    @StateObject private var libraryService = LibraryService.shared

    private var muscleNames: [String] {
        muscleGroupIds.compactMap { id in
            libraryService.getMuscleGroup(id: id)?.name
        }.sorted()
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(muscleNames, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Implements Display

struct ExerciseImplementsDisplay: View {
    let implementIds: Set<UUID>
    @StateObject private var libraryService = LibraryService.shared

    private var implementNames: [String] {
        implementIds.compactMap { id in
            libraryService.getImplement(id: id)?.name
        }.sorted()
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(implementNames, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.15))
                    .foregroundColor(.teal)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(
            exercise: Module.sampleStrength.exercises[0],
            moduleId: UUID()
        )
        .environmentObject(ModuleViewModel())
    }
}
