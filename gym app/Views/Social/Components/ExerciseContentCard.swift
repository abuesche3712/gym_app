//
//  ExerciseContentCard.swift
//  gym app
//
//  Exercise content card for post detail view
//

import SwiftUI

struct ExerciseContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedExercise(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}
