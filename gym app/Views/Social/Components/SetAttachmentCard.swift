//
//  SetAttachmentCard.swift
//  gym app
//
//  Attachment card for sets (including PR celebrations) in feed posts
//

import SwiftUI

struct SetAttachmentCard: View {
    let snapshot: Data

    private var bundle: SetShareBundle? {
        try? SetShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            let detectedType = detectSetType(from: bundle.setData)

            VStack(spacing: AppSpacing.md) {
                // PR Badge
                if bundle.isPR {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.caption.weight(.bold))
                        Text("NEW PR")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                    }
                    .foregroundColor(AppColors.warning)
                }

                // Exercise name
                Text(bundle.exerciseName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textSecondary)

                // Display based on type
                setDisplay(set: bundle.setData, type: detectedType, isPR: bundle.isPR, distanceUnit: bundle.distanceUnit)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .padding(.horizontal, AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(bundle.isPR ? AppColors.warning.opacity(0.08) : AppColors.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .stroke(
                        bundle.isPR ? AppColors.warning.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.5),
                        lineWidth: bundle.isPR ? 1.5 : 1
                    )
            )
        }
    }

    @ViewBuilder
    private func setDisplay(set: SetData, type: AttachmentDetectedType, isPR: Bool, distanceUnit: DistanceUnit?) -> some View {
        switch type {
        case .strength:
            if let weight = set.weight, let reps = set.reps {
                HStack(spacing: AppSpacing.sm) {
                    Text("\(Int(weight))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)

                    Text("×")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)

                    Text("\(reps)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)
                }

                Text("lbs")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }

        case .cardio:
            HStack(spacing: AppSpacing.lg) {
                if let duration = set.duration, duration > 0 {
                    VStack(spacing: 4) {
                        Text(formatDurationClock(duration))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent3)
                        Text("time")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                if let distance = set.distance, distance > 0 {
                    VStack(spacing: 4) {
                        Text(formatDistanceNumeric(distance))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent1)
                        Text(distanceUnit?.abbreviation ?? "m")
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

        case .isometric:
            if let holdTime = set.holdTime {
                VStack(spacing: 4) {
                    Text(formatDurationClock(holdTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(isPR ? AppColors.warning : AppColors.accent2)
                    Text("hold")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

        case .band:
            if let bandColor = set.bandColor, let reps = set.reps {
                VStack(spacing: 4) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(bandColor)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.accent3)

                        Text("×")
                            .font(.title2)
                            .foregroundColor(AppColors.textTertiary)

                        Text("\(reps)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(isPR ? AppColors.warning : AppColors.textPrimary)
                    }
                    Text("reps")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

        case .unknown:
            EmptyView()
        }
    }
}
