//
//  QuickLogSheet.swift
//  gym app
//
//  Sheet for quickly logging activities without creating templates
//

import SwiftUI

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
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Preset Grid
                    presetGrid

                    // Custom Activity Section
                    if viewModel.isCustom {
                        customActivitySection
                    }

                    // Metric Inputs
                    if !viewModel.activeMetrics.isEmpty {
                        metricInputsSection
                    }

                    // Notes
                    notesSection

                    // Date Picker
                    dateSection

                    // Save Button
                    saveButton
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.sm) {
                ForEach(viewModel.presets) { preset in
                    presetButton(preset)
                }

                // Custom button
                customButton
            }
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
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: preset.icon)
                    .font(.title3.weight(.medium))

                Text(preset.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
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
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))

                Text("Custom")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceSecondary)
            )
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Activity Section

    private var customActivitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("CUSTOM ACTIVITY")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            // Name input
            TextField("Activity name", text: $viewModel.customName)
                .font(.body)
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                .focused($focusedField, equals: .customName)

            // Exercise type picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ExerciseType.allCases) { type in
                        exerciseTypeButton(type)
                    }
                }
            }
        }
    }

    private func exerciseTypeButton(_ type: ExerciseType) -> some View {
        let isSelected = viewModel.exerciseType == type

        return Button {
            HapticManager.shared.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.exerciseType = type
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: type.icon)
                    .font(.caption.weight(.medium))
                Text(type.displayName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.small)
                    .fill(isSelected ? AppColors.dominant : AppColors.surfaceSecondary)
            )
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metric Inputs Section

    private var metricInputsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("METRICS")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                ForEach(viewModel.activeMetrics, id: \.self) { metric in
                    metricInput(for: metric)
                }
            }
        }
    }

    @ViewBuilder
    private func metricInput(for metric: QuickLogMetric) -> some View {
        switch metric {
        case .distance:
            MetricInputCard(
                label: "Distance",
                unit: "mi",
                value: $viewModel.distance,
                keyboardType: .decimalPad
            )
            .focused($focusedField, equals: .distance)

        case .duration:
            DurationInputCard(
                label: "Duration",
                seconds: $viewModel.duration
            )

        case .weight:
            MetricInputCard(
                label: "Weight",
                unit: "lbs",
                value: $viewModel.weight,
                keyboardType: .decimalPad
            )
            .focused($focusedField, equals: .weight)

        case .reps:
            MetricInputCard(
                label: "Reps",
                unit: nil,
                value: $viewModel.reps,
                keyboardType: .numberPad
            )
            .focused($focusedField, equals: .reps)

        case .temperature:
            MetricInputCard(
                label: "Temperature",
                unit: "°F",
                value: $viewModel.temperature,
                keyboardType: .numberPad
            )
            .focused($focusedField, equals: .temperature)

        case .holdTime:
            DurationInputCard(
                label: "Hold Time",
                seconds: $viewModel.holdTime
            )

        case .intensity:
            MetricInputCard(
                label: "Intensity",
                unit: "/10",
                value: $viewModel.intensity,
                keyboardType: .numberPad
            )
            .focused($focusedField, equals: .intensity)

        case .height:
            MetricInputCard(
                label: "Height",
                unit: "in",
                value: $viewModel.height,
                keyboardType: .decimalPad
            )
            .focused($focusedField, equals: .height)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("NOTES")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            TextField("How did it feel?", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
                .padding(AppSpacing.md)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                .focused($focusedField, equals: .notes)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("DATE")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            DatePicker(
                "Log Date",
                selection: $viewModel.logDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveQuickLog()
        } label: {
            Text("Save Quick Log")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    Group {
                        if viewModel.canSave {
                            AppGradients.dominantGradient
                        } else {
                            LinearGradient(
                                colors: [AppColors.surfaceTertiary, AppColors.surfaceTertiary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
        }
        .disabled(!viewModel.canSave)
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func saveQuickLog() {
        let session = viewModel.save()

        // Save through DataRepository
        DataRepository.shared.saveSession(session)

        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Metric Input Card

struct MetricInputCard: View {
    let label: String
    let unit: String?
    @Binding var value: String
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                TextField("0", text: $value)
                    .keyboardType(keyboardType)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 50)

                if let unit = unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))

            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

// MARK: - Duration Input Card

struct DurationInputCard: View {
    let label: String
    @Binding var seconds: Int

    @State private var showingPicker = false

    private var formattedDuration: String {
        if seconds == 0 {
            return "0:00"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                showingPicker = true
            } label: {
                Text(formattedDuration)
                    .font(.title2.weight(.bold))
                    .foregroundColor(seconds > 0 ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(AppColors.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
            }
            .buttonStyle(.plain)

            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
        }
        .sheet(isPresented: $showingPicker) {
            QuickLogDurationPicker(seconds: $seconds)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Duration Picker

struct QuickLogDurationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var seconds: Int

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var secs: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                HStack(spacing: 0) {
                    // Hours
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<24) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text("h")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)

                    // Minutes
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text("m")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)

                    // Seconds
                    Picker("Seconds", selection: $secs) {
                        ForEach(0..<60) { s in
                            Text("\(s)").tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text("s")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal)

                // Quick duration buttons
                HStack(spacing: AppSpacing.md) {
                    quickDurationButton("5m", duration: 5 * 60)
                    quickDurationButton("10m", duration: 10 * 60)
                    quickDurationButton("15m", duration: 15 * 60)
                    quickDurationButton("30m", duration: 30 * 60)
                    quickDurationButton("1h", duration: 60 * 60)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        seconds = hours * 3600 + minutes * 60 + secs
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                hours = seconds / 3600
                minutes = (seconds % 3600) / 60
                secs = seconds % 60
            }
        }
    }

    private func quickDurationButton(_ title: String, duration: Int) -> some View {
        Button {
            let h = duration / 3600
            let m = (duration % 3600) / 60
            let s = duration % 60
            hours = h
            minutes = m
            secs = s
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.dominant)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.dominant.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppCorners.small))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Quick Log Sheet") {
    QuickLogSheet()
        .environmentObject(SessionViewModel())
}
