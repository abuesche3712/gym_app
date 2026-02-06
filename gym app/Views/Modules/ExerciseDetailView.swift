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

    let instance: ExerciseInstance
    let moduleId: UUID

    @State private var showingEditExercise = false

    private var currentInstance: ExerciseInstance {
        if let module = moduleViewModel.getModule(id: moduleId),
           let inst = module.exercises.first(where: { $0.id == instance.id }) {
            return inst
        }
        return instance
    }

    private var resolved: ResolvedExercise {
        ExerciseResolver.shared.resolve(currentInstance)
    }

    var body: some View {
        List {
            // Exercise Info
            Section("Info") {
                LabeledContent("Name", value: resolved.name)
                LabeledContent("Type", value: resolved.exerciseType.displayName)
            }

            // Muscles
            if !resolved.primaryMuscles.isEmpty || !resolved.secondaryMuscles.isEmpty {
                Section("Muscles") {
                    if !resolved.primaryMuscles.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Primary")
                                .caption(color: AppColors.textSecondary)
                            MuscleGroupsDisplay(muscles: resolved.primaryMuscles, color: AppColors.dominant)
                        }
                    }

                    if !resolved.secondaryMuscles.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Secondary")
                                .caption(color: AppColors.textSecondary)
                            MuscleGroupsDisplay(muscles: resolved.secondaryMuscles, color: AppColors.textSecondary)
                        }
                    }
                }
            }

            // Set Groups
            Section("Sets") {
                if resolved.setGroups.isEmpty {
                    Text("No sets defined")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(resolved.setGroups.enumerated()), id: \.element.id) { index, setGroup in
                        SetGroupRow(setGroup: setGroup, index: index + 1)
                    }
                }
            }

            // Tracking Metrics
            Section("Tracking") {
                FlowLayout(spacing: 8) {
                    ForEach(resolved.trackingMetrics, id: \.self) { metric in
                        Text(metric.displayName)
                            .caption(color: AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.surfaceTertiary)
                            .clipShape(Capsule())
                    }
                }
            }

            // Notes
            if let notes = resolved.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .body(color: AppColors.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(resolved.name)
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
                ExerciseFormView(instance: currentInstance, moduleId: moduleId, sessionExercise: nil, sessionModuleIndex: nil, sessionExerciseIndex: nil, onSessionSave: nil)
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
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.semibold)

                Spacer()

                if let notes = setGroup.notes {
                    Text(notes)
                        .caption(color: AppColors.textSecondary)
                }
            }

            Text(setGroup.formattedTarget)
                .headline(color: AppColors.textPrimary)

            if let rest = setGroup.formattedRest {
                Label(rest, systemImage: "clock")
                    .caption(color: AppColors.textSecondary)
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

struct MuscleGroupsDisplay: View {
    let muscles: [MuscleGroup]
    var color: Color = AppColors.dominant

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(muscles, id: \.self) { muscle in
                Text(muscle.rawValue)
                    .caption(color: color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        // Create a sample ExerciseInstance for preview
        let sampleInstance = ExerciseInstance(
            templateId: UUID(),
            name: "Bench Press",
            exerciseType: .strength,
            setGroups: [SetGroup(sets: 3, targetReps: 10)]
        )
        ExerciseDetailView(
            instance: sampleInstance,
            moduleId: UUID()
        )
        .environmentObject(ModuleViewModel())
    }
}
