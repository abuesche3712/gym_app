//
//  BodyWeightCardView.swift
//  gym app
//
//  Bodyweight tracking card for AnalyticsView, plus its add-entry sheet.
//  Local-only feature: entries never leave the device.
//

import SwiftUI

struct BodyWeightCard: View {
    @ObservedObject var viewModel: BodyWeightViewModel
    let unit: WeightUnit
    let timeRange: AnalyticsTimeRange

    @State private var showingAddSheet = false

    private var chartPoints: [BodyWeightPoint] {
        viewModel.chartPoints(in: timeRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header

            if viewModel.entries.isEmpty {
                emptyState
            } else {
                summaryRow

                if chartPoints.count >= 2 {
                    BodyWeightSwiftChart(points: chartPoints, unit: unit)
                        .frame(height: 120)
                } else {
                    Text("Log a couple more entries to see a trend line.")
                        .caption(color: AppColors.textTertiary)
                }
            }
        }
        .analyticsCard()
        .sheet(isPresented: $showingAddSheet) {
            AddBodyWeightEntrySheet(viewModel: viewModel, unit: unit)
        }
    }

    private var header: some View {
        HStack {
            Text("Bodyweight")
                .headline(color: AppColors.textPrimary)
            Spacer()
            Button {
                HapticManager.shared.tap()
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.dominant)
            }
            .buttonStyle(.pressable)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "scalemass",
            title: "No Weigh-Ins Yet",
            subtitle: "Log your bodyweight to track trends over time.",
            buttonTitle: "Log Weight",
            buttonIcon: "plus",
            onButtonTap: { showingAddSheet = true }
        )
    }

    private var summaryRow: some View {
        HStack(spacing: AppSpacing.md) {
            if let latest = viewModel.latestEntry {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest")
                        .caption(color: AppColors.textTertiary)
                    Text(formatBodyWeight(kg: latest.weightKg, unit: unit))
                        .monoSmall(color: AppColors.textPrimary)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceSecondary)
                )
            }

            if let delta = viewModel.latestDeltaKg {
                let displayDelta = convertWeight(kg: abs(delta), to: unit)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Change")
                        .caption(color: AppColors.textTertiary)
                    Text(delta == 0 ? "No change" : "\(delta > 0 ? "+" : "-")\(formatWeight(displayDelta)) \(unit.abbreviation)")
                        .monoSmall(color: AppColors.textPrimary)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.surfaceSecondary)
                )
            }
        }
    }
}

// MARK: - Add Entry Sheet

struct AddBodyWeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BodyWeightViewModel
    let unit: WeightUnit

    @State private var weightText: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @FocusState private var weightFieldFocused: Bool

    private var recentEntries: [BodyWeightEntry] {
        viewModel.recentEntries(limit: 20)
    }

    private var enteredWeight: Double? {
        Double(weightText)
    }

    private var canSave: Bool {
        guard let value = enteredWeight else { return false }
        return value > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($weightFieldFocused)
                        Text(unit.abbreviation)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Section("Date") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }

                Section("Note (optional)") {
                    TextField("e.g. after fasted cardio", text: $note)
                }

                if !recentEntries.isEmpty {
                    Section("Recent Entries") {
                        ForEach(recentEntries) { entry in
                            recentEntryRow(entry)
                        }
                        .onDelete { offsets in
                            viewModel.delete(at: offsets, from: recentEntries)
                        }
                    }
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { weightFieldFocused = true }
        }
    }

    private func save() {
        guard let value = enteredWeight else { return }
        let weightKg = convertWeight(value, from: unit)
        viewModel.addEntry(weightKg: weightKg, date: date, note: note)
        HapticManager.shared.success()
        dismiss()
    }

    private func recentEntryRow(_ entry: BodyWeightEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatBodyWeight(kg: entry.weightKg, unit: unit))
                    .fontWeight(.medium)
                Text(formatDate(entry.date))
                    .caption(color: AppColors.textTertiary)
            }

            Spacer()

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .caption(color: AppColors.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
        }
    }
}

#Preview {
    AddBodyWeightEntrySheet(viewModel: BodyWeightViewModel(), unit: .lbs)
}
