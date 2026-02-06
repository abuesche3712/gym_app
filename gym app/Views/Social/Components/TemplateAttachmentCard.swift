//
//  TemplateAttachmentCard.swift
//  gym app
//
//  Attachment card for templates (programs, workouts, modules) in feed posts
//

import SwiftUI

struct TemplateAttachmentCard: View {
    let type: String
    let name: String
    let snapshot: Data

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: iconForType)
                    .font(.caption.weight(.semibold))
                Text(type)
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundColor(AppColors.dominant)

            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .flatCardStyle()
    }

    private var iconForType: String {
        switch type {
        case "PROGRAM": return "doc.text.fill"
        case "WORKOUT": return "figure.run"
        default: return "square.stack.3d.up.fill"
        }
    }
}
