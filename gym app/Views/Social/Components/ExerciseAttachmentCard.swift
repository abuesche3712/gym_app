//
//  ExerciseAttachmentCard.swift
//  gym app
//
//  Attachment card for exercises in feed posts
//

import SwiftUI

struct ExerciseAttachmentCard: View {
    let snapshot: Data

    private var bundle: ExerciseShareBundle? {
        try? ExerciseShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            let completedSets = bundle.setData.filter { $0.completed }
            let detectedType = detectExerciseType(from: completedSets)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: iconForDetectedType(detectedType))
                        .font(.subheadline)
                        .foregroundColor(colorForDetectedType(detectedType))

                    Text(bundle.exerciseName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                }

                // Sets summary based on type
                exerciseSummary(completedSets: completedSets, type: detectedType, distanceUnit: bundle.distanceUnit)
            }
            .flatCardStyle()
        }
    }

    @ViewBuilder
    private func exerciseSummary(completedSets: [SetData], type: AttachmentDetectedType, distanceUnit: DistanceUnit?) -> some View {
        switch type {
        case .strength:
            if let topSet = completedSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
               let weight = topSet.weight, let reps = topSet.reps {
                HStack(spacing: AppSpacing.xs) {
                    Text("\(completedSets.count) sets")
                        .caption(color: AppColors.textSecondary)
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text("Top: \(formatWeight(weight)) × \(reps)")
                        .caption(color: AppColors.dominant)
                }
            }

        case .cardio:
            let totalDuration = completedSets.compactMap { $0.duration }.reduce(0, +)
            let totalDistance = completedSets.compactMap { $0.distance }.reduce(0, +)
            HStack(spacing: AppSpacing.xs) {
                Text("\(completedSets.count) sets")
                    .caption(color: AppColors.textSecondary)
                if totalDuration > 0 {
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text(formatDurationCompact(totalDuration))
                        .caption(color: AppColors.accent3)
                }
                if totalDistance > 0 {
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text(formatDistanceWithUnit(totalDistance, unit: distanceUnit))
                        .caption(color: AppColors.accent1)
                }
            }

        case .isometric:
            let totalHoldTime = completedSets.compactMap { $0.holdTime }.reduce(0, +)
            HStack(spacing: AppSpacing.xs) {
                Text("\(completedSets.count) sets")
                    .caption(color: AppColors.textSecondary)
                Text("·")
                    .caption(color: AppColors.textTertiary)
                Text("Total: \(formatDurationCompact(totalHoldTime))")
                    .caption(color: AppColors.accent2)
            }

        case .band:
            if let topSet = completedSets.first, let bandColor = topSet.bandColor, let reps = topSet.reps {
                HStack(spacing: AppSpacing.xs) {
                    Text("\(completedSets.count) sets")
                        .caption(color: AppColors.textSecondary)
                    Text("·")
                        .caption(color: AppColors.textTertiary)
                    Text("\(bandColor) × \(reps)")
                        .caption(color: AppColors.accent3)
                }
            }

        case .unknown:
            Text("\(completedSets.count) sets")
                .caption(color: AppColors.textSecondary)
        }
    }
}
