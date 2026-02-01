//
//  QuickLogSheet.swift
//  gym app
//
//  Sheet for quickly logging activities without creating templates
//

import SwiftUI
import WidgetKit

struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = QuickLogViewModel()

    @FocusState private var focusedField: FocusField?

    enum FocusField {
        case customName
        case distance
        case weight
        case reps
        case temperature
        case intensity
        case height
        case notes
        case durationMinutes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Preset Grid
                    presetGrid

                    // Custom Activity Name (only if custom)
                    if viewModel.isCustom {
                        customNameInput
                    }

                    // Metric Inputs (inline - no separate screens)
                    if !viewModel.activeMetrics.isEmpty {
                        metricInputsSection
                    }

                    // Notes (collapsible)
                    notesSection

                    // Date (compact - defaults to now)
                    dateSection
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, 100) // Space for save button
            }
            .background(AppColors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Preset Grid

    private var presetGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacing.sm) {
            ForEach(viewModel.presets) { preset in
                presetButton(preset)
            }
            customButton
        }
    }

    private func presetButton(_ preset: QuickLogPreset) -> some View {
        let isSelected = viewModel.selectedPreset?.id == preset.id && !viewModel.isCustom

        return Button {
            HapticManager.shared.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectPreset(preset)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.body.weight(.medium))

                Text(preset.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceSecondary)
            )
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var customButton: some View {
        let isSelected = viewModel.isCustom

        return Button {
            HapticManager.shared.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectCustom()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))

                Text("Custom")
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceSecondary)
            )
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Name Input

    private var customNameInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            TextField("Activity name", text: $viewModel.customName)
                .font(.body)
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                .focused($focusedField, equals: .customName)

            // Exercise type - compact pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ExerciseType.allCases) { type in
                        exerciseTypePill(type)
                    }
                }
            }
        }
    }

    private func exerciseTypePill(_ type: ExerciseType) -> some View {
        let isSelected = viewModel.exerciseType == type

        return Button {
            HapticManager.shared.tap()
            viewModel.exerciseType = type
        } label: {
            Text(type.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.dominant : AppColors.surfaceSecondary)
                )
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metric Inputs Section

    private var metricInputsSection: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(viewModel.activeMetrics, id: \.self) { metric in
                metricInput(for: metric)
            }
        }
    }

    @ViewBuilder
    private func metricInput(for metric: QuickLogMetric) -> some View {
        switch metric {
        case .distance:
            inlineMetricRow(
                icon: "arrow.left.and.right",
                label: "Distance",
                value: $viewModel.distance,
                unit: "mi",
                keyboardType: .decimalPad,
                focusField: .distance
            )

        case .duration:
            inlineDurationRow

        case .weight:
            inlineMetricRow(
                icon: "scalemass",
                label: "Weight",
                value: $viewModel.weight,
                unit: "lbs",
                keyboardType: .decimalPad,
                focusField: .weight
            )

        case .reps:
            inlineMetricRow(
                icon: "repeat",
                label: "Reps",
                value: $viewModel.reps,
                unit: nil,
                keyboardType: .numberPad,
                focusField: .reps
            )

        case .temperature:
            inlineMetricRow(
                icon: "thermometer.medium",
                label: "Temperature",
                value: $viewModel.temperature,
                unit: "°F",
                keyboardType: .numberPad,
                focusField: .temperature
            )

        case .holdTime:
            inlineHoldTimeRow

        case .intensity:
            inlineMetricRow(
                icon: "flame",
                label: "Intensity",
                value: $viewModel.intensity,
                unit: "/10",
                keyboardType: .numberPad,
                focusField: .intensity
            )

        case .height:
            inlineMetricRow(
                icon: "arrow.up.and.down",
                label: "Height",
                value: $viewModel.height,
                unit: "in",
                keyboardType: .decimalPad,
                focusField: .height
            )
        }
    }

    private func inlineMetricRow(
        icon: String,
        label: String,
        value: Binding<String>,
        unit: String?,
        keyboardType: UIKeyboardType,
        focusField: FocusField
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: value)
                    .keyboardType(keyboardType)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .focused($focusedField, equals: focusField)

                if let unit = unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 30, alignment: .leading)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
    }

    // MARK: - Inline Duration Row

    private var inlineDurationRow: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Duration")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Editable minutes field
                HStack(spacing: 4) {
                    TextField("0", text: Binding(
                        get: { String(viewModel.duration / 60) },
                        set: { viewModel.duration = (Int($0) ?? 0) * 60 }
                    ))
                    .keyboardType(.numberPad)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                    .focused($focusedField, equals: .durationMinutes)

                    Text("min")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))

            // Quick duration buttons
            HStack(spacing: AppSpacing.sm) {
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { mins in
                    quickDurationButton(mins)
                }
            }
        }
    }

    private func quickDurationButton(_ minutes: Int) -> some View {
        let isSelected = viewModel.duration == minutes * 60

        return Button {
            HapticManager.shared.tap()
            viewModel.duration = minutes * 60
        } label: {
            Text(minutes < 60 ? "\(minutes)m" : "1h")
                .font(.caption2.weight(.medium))
                .foregroundColor(isSelected ? .white : AppColors.dominant)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.dominant : AppColors.dominant.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline Hold Time Row

    private var inlineHoldTimeRow: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "timer")
                    .font(.body)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                Text("Hold Time")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    TextField("0", text: Binding(
                        get: { String(viewModel.holdTime / 60) },
                        set: { viewModel.holdTime = (Int($0) ?? 0) * 60 }
                    ))
                    .keyboardType(.numberPad)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)

                    Text("min")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))

            // Quick hold time buttons
            HStack(spacing: AppSpacing.sm) {
                ForEach([1, 2, 3, 5, 10, 15], id: \.self) { mins in
                    Button {
                        HapticManager.shared.tap()
                        viewModel.holdTime = mins * 60
                    } label: {
                        let isSelected = viewModel.holdTime == mins * 60
                        Text("\(mins)m")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(isSelected ? .white : AppColors.accent2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? AppColors.accent2 : AppColors.accent2.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
            .lineLimit(2...4)
            .font(.subheadline)
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
            .focused($focusedField, equals: .notes)
    }

    // MARK: - Date Section

    private var dateSection: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.body)
                .foregroundColor(AppColors.textTertiary)

            DatePicker(
                "",
                selection: $viewModel.logDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                saveQuickLog()
            } label: {
                Text("Save")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        viewModel.canSave
                            ? AppGradients.dominantGradient
                            : LinearGradient(colors: [AppColors.surfaceTertiary], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
            }
            .disabled(!viewModel.canSave)
            .buttonStyle(.plain)
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background)
    }

    // MARK: - Actions

    private func saveQuickLog() {
        let session = viewModel.save()
        DataRepository.shared.saveSession(session)

        // Update widget to show the completed session
        let widgetData = TodayWorkoutData(
            workoutName: session.displayName,
            moduleNames: session.completedModules.map { $0.moduleName },
            isRestDay: false,
            isCompleted: true,
            lastUpdated: Date()
        )
        WidgetDataService.writeTodayWorkout(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayWorkoutWidget")

        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview("Quick Log Sheet") {
    QuickLogSheet()
        .environmentObject(SessionViewModel())
}
