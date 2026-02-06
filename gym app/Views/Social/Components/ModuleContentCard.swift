//
//  ModuleContentCard.swift
//  gym app
//
//  Module content card for post detail view
//

import SwiftUI

struct ModuleContentCard: View {
    let snapshot: Data

    var body: some View {
        SharedContentCard(
            content: .sharedCompletedModule(snapshot: snapshot),
            isFromCurrentUser: false
        )
    }
}
