//
//  HighlightsInlineCards.swift
//  gym app
//
//  Inline cards for exercise and set highlights in feed posts
//

import SwiftUI

struct HighlightsInlineCards: View {
    let snapshot: Data

    private var bundle: HighlightsShareBundle? {
        try? HighlightsShareBundle.decode(from: snapshot)
    }

    var body: some View {
        if let bundle = bundle {
            VStack(spacing: AppSpacing.md) {
                ForEach(bundle.exercises.indices, id: \.self) { index in
                    if let data = try? bundle.exercises[index].encode() {
                        ExerciseAttachmentCard(snapshot: data)
                    }
                }

                ForEach(bundle.sets.indices, id: \.self) { index in
                    if let data = try? bundle.sets[index].encode() {
                        SetAttachmentCard(snapshot: data)
                    }
                }
            }
        }
    }
}
