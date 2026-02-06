//
//  SetContentCard.swift
//  gym app
//
//  Set content card for post detail view
//

import SwiftUI

struct SetContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedSet(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}
