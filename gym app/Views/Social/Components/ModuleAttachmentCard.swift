//
//  ModuleAttachmentCard.swift
//  gym app
//
//  Attachment card for completed modules in feed posts
//

import SwiftUI

struct ModuleAttachmentCard: View {
    let snapshot: Data

    private var bundle: CompletedModuleShareBundle? {
        try? CompletedModuleShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            let moduleColor = AppColors.moduleColor(bundle.module.moduleType)
            let exerciseCount = bundle.module.completedExercises.count
            let setCount = bundle.module.completedExercises.reduce(0) { total, exercise in
                total + exercise.completedSetGroups.reduce(0) { $0 + $1.sets.filter(\.completed).count }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(AppColors.success)

                    Image(systemName: bundle.module.moduleType.icon)
                        .font(.caption)
                        .foregroundColor(moduleColor)

                    Text(bundle.module.moduleName.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(0.5)
                }

                HStack(spacing: AppSpacing.md) {
                    Label("\(exerciseCount) exercises", systemImage: "dumbbell.fill")
                    Label("\(setCount) sets", systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
            .flatCardStyle()
        }
    }
}
