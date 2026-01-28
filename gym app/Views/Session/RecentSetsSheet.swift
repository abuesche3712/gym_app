//
//  RecentSetsSheet.swift
//  gym app
//
//  Sheet for viewing and editing recently logged sets
//

import SwiftUI

// MARK: - Recent Sets Sheet

struct RecentSetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recentSets: [RecentSet]
    let onUpdate: (RecentSet, Double?, Int?, Int?, Int?, Int?, Double?) -> Void

    @State private var editingSet: RecentSet?

    var body: some View {
        NavigationStack {
            List {
                if recentSets.isEmpty {
                    Text("No sets logged yet")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(recentSets) { recentSet in
                        Button {
                            editingSet = recentSet
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.success.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.success)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recentSet.exerciseName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(formatSetData(recentSet))
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recent Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.dominant)
                }
            }
            .sheet(item: $editingSet) { recentSet in
                EditRecentSetSheet(recentSet: recentSet) { weight, reps, rpe, duration, holdTime, distance in
                    onUpdate(recentSet, weight, reps, rpe, duration, holdTime, distance)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func formatSetData(_ recentSet: RecentSet) -> String {
        let set = recentSet.setData
        switch recentSet.exerciseType {
        case .strength:
            return set.formattedStrength ?? "Completed"
        case .isometric:
            return set.formattedIsometric ?? "Completed"
        case .cardio:
            return set.formattedCardio ?? "Completed"
        case .mobility, .explosive:
            return set.reps.map { "\($0) reps" } ?? "Completed"
        case .recovery:
            return set.formattedRecovery ?? "Completed"
        }
    }
}

// MARK: - Edit Recent Set Sheet

struct EditRecentSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recentSet: RecentSet
    let onSave: (Double?, Int?, Int?, Int?, Int?, Double?) -> Void

    @State private var inputWeight: String = ""
    @State private var inputReps: String = ""
    @State private var inputRPE: Int = 0
    @State private var inputDuration: Int = 0
    @State private var inputHoldTime: Int = 0
    @State private var inputDistance: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Text(recentSet.exerciseName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                inputFields
                    .padding(AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfaceTertiary)
                    )

                Spacer()
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            Double(inputWeight),
                            Int(inputReps),
                            inputRPE > 0 ? inputRPE : nil,
                            inputDuration > 0 ? inputDuration : nil,
                            inputHoldTime > 0 ? inputHoldTime : nil,
                            Double(inputDistance)
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.dominant)
                }
            }
            .onAppear { loadValues() }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var inputFields: some View {
        switch recentSet.exerciseType {
        case .strength:
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WEIGHT")
                            .statLabel(color: AppColors.textTertiary)
                        TextField("0", text: $inputWeight)
                            .keyboardType(.decimalPad)
                            .font(.displayMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPS")
                            .statLabel(color: AppColors.textTertiary)
                        TextField("0", text: $inputReps)
                            .keyboardType(.numberPad)
                            .font(.displayMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                    }
                }

                HStack {
                    Text("RPE")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Picker("RPE", selection: $inputRPE) {
                        Text("--").tag(0)
                        ForEach(5...10, id: \.self) { rpe in
                            Text("\(rpe)").tag(rpe)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 80)
                    .clipped()
                }
            }

        case .isometric:
            TimePickerView(totalSeconds: $inputHoldTime, maxMinutes: 5, label: "Hold Time")

        case .cardio:
            VStack(spacing: AppSpacing.md) {
                TimePickerView(totalSeconds: $inputDuration, maxMinutes: 60, maxHours: 4, label: "Duration")

                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                    TextField("0", text: $inputDistance)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
                }
            }

        case .mobility, .explosive:
            VStack(alignment: .leading, spacing: 4) {
                Text("REPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                TextField("0", text: $inputReps)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
            }

        case .recovery:
            VStack(alignment: .leading, spacing: 4) {
                Text("DURATION")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                Text(inputDuration > 0 ? formatDuration(inputDuration) : "--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppCorners.small).fill(AppColors.surfacePrimary))
            }
        }
    }

    private func loadValues() {
        let set = recentSet.setData
        inputWeight = set.weight.map { formatWeight($0) } ?? ""
        inputReps = set.reps.map { "\($0)" } ?? ""
        inputRPE = set.rpe ?? 0
        inputDuration = set.duration ?? 0
        inputHoldTime = set.holdTime ?? 0
        inputDistance = set.distance.map { formatDistanceValue($0) } ?? ""
    }
}
