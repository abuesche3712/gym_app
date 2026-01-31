//
//  TimeInputPickers.swift
//  gym app
//
//  Time picker sheets for duration input
//

import SwiftUI

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var totalSeconds: Int
    var title: String = "Time"
    var maxHours: Int = 4
    var onSave: (() -> Void)? = nil

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                HStack(spacing: 0) {
                    // Hours picker
                    Picker("Hours", selection: $hours) {
                        ForEach(0...maxHours, id: \.self) { hr in
                            Text("\(hr)").tag(hr)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("hr")
                        .headline(color: AppColors.textSecondary)
                        .frame(width: 30)

                    // Minutes picker
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text(String(format: "%02d", min)).tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("min")
                        .headline(color: AppColors.textSecondary)
                        .frame(width: 35)

                    // Seconds picker
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    Text("sec")
                        .headline(color: AppColors.textSecondary)
                        .frame(width: 35)
                }
                .frame(height: 150)

                Spacer()
            }
            .padding(AppSpacing.lg)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                        onSave?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.dominant)
                }
            }
            .onAppear {
                hours = totalSeconds / 3600
                minutes = (totalSeconds % 3600) / 60
                seconds = totalSeconds % 60
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Set Indicator

struct SetIndicator: View {
    let setNumber: Int
    let isCompleted: Bool
    let isCurrent: Bool
    var restTime: Int = 90

    var body: some View {
        ZStack {
            if isCompleted {
                // Use animated checkmark for completed sets
                AnimatedCheckmark(
                    isChecked: true,
                    size: 40,
                    color: AppColors.success,
                    lineWidth: 3
                )
            } else {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)

                Text("\(setNumber)")
                    .subheadline(color: isCurrent ? AppColors.dominant : AppColors.textTertiary)
                    .fontWeight(.bold)
            }
        }
        .overlay(
            Circle()
                .stroke(isCurrent && !isCompleted ? AppColors.dominant : .clear, lineWidth: 2)
        )
        .animation(AppAnimation.quick, value: isCompleted)
        .animation(AppAnimation.quick, value: isCurrent)
    }

    private var backgroundColor: Color {
        if isCurrent {
            return AppColors.dominant.opacity(0.15)
        } else {
            return AppColors.surfaceTertiary
        }
    }
}
