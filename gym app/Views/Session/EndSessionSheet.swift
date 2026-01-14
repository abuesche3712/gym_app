//
//  EndSessionSheet.swift
//  gym app
//
//  Sheet for finishing a workout session
//

import SwiftUI

struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Int?, String?) -> Void

    @State private var feeling: Int = 3
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                // Feeling picker
                VStack(spacing: AppSpacing.md) {
                    Text("How did you feel?")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.md) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                withAnimation(AppAnimation.quick) {
                                    feeling = value
                                }
                            } label: {
                                VStack(spacing: AppSpacing.xs) {
                                    Text(feelingEmoji(value))
                                        .font(.system(size: 36))
                                    Text("\(value)")
                                        .font(.caption)
                                        .foregroundColor(feeling == value ? AppColors.textPrimary : AppColors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCorners.medium)
                                        .fill(feeling == value ? AppColors.accentBlue.opacity(0.2) : AppColors.surfaceLight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                                .stroke(feeling == value ? AppColors.accentBlue : .clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Notes (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextEditor(text: $notes)
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.md)
                        .frame(minHeight: 100)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.surfaceLight)
                        )
                }

                Spacer()
            }
            .padding(AppSpacing.screenPadding)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(feeling, notes.isEmpty ? nil : notes)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "💪"
        default: return "😐"
        }
    }
}
