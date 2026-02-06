//
//  HighlightsContentCard.swift
//  gym app
//
//  Highlights content card for post detail view
//

import SwiftUI

struct HighlightsContentCard: View {
    let snapshot: Data

    private var bundle: HighlightsShareBundle? {
        try? HighlightsShareBundle.decode(from: snapshot)
    }

    private var totalCount: Int {
        (bundle?.exercises.count ?? 0) + (bundle?.sets.count ?? 0)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(AppColors.warning)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(totalCount) HIGHLIGHT\(totalCount == 1 ? "" : "S")")
                            .font(.headline.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("from \(bundle.workoutName)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }

                // Show highlights
                ForEach(bundle.exercises.indices, id: \.self) { index in
                    let exercise = bundle.exercises[index]
                    highlightRow(name: exercise.exerciseName, icon: "dumbbell.fill", color: AppColors.dominant)
                }

                ForEach(bundle.sets.indices, id: \.self) { index in
                    let set = bundle.sets[index]
                    highlightRow(
                        name: set.exerciseName,
                        icon: set.isPR ? "trophy.fill" : "flame.fill",
                        color: set.isPR ? AppColors.warning : AppColors.accent1
                    )
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.warning.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .stroke(AppColors.warning.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func highlightRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)

            Text(name)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}
