//
//  SessionContentCard.swift
//  gym app
//
//  Session content card for post detail view — wraps SessionPostContent
//

import SwiftUI

struct SessionContentCard: View {
    let workoutName: String
    let date: Date
    let snapshot: Data
    let onTap: (() -> Void)?

    var body: some View {
        SessionPostContent(workoutName: workoutName, date: date, snapshot: snapshot)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
    }
}
