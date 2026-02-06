//
//  PostContentCard.swift
//  gym app
//
//  Content card dispatcher for post detail view
//

import SwiftUI

struct PostContentCard: View {
    let content: PostContent
    let onTap: (() -> Void)?

    init(content: PostContent, onTap: (() -> Void)? = nil) {
        self.content = content
        self.onTap = onTap
    }

    var body: some View {
        Group {
            switch content {
            case .session(_, let workoutName, let date, let snapshot):
                SessionContentCard(workoutName: workoutName, date: date, snapshot: snapshot, onTap: onTap)

            case .exercise(let snapshot):
                ExerciseContentCard(snapshot: snapshot)

            case .set(let snapshot):
                SetContentCard(snapshot: snapshot)

            case .completedModule(let snapshot):
                ModuleContentCard(snapshot: snapshot)

            case .program(_, let name, let snapshot):
                TemplateContentCard(type: "Program", name: name, icon: "doc.text.fill", color: AppColors.dominant, snapshot: snapshot, onTap: onTap)

            case .workout(_, let name, let snapshot):
                TemplateContentCard(type: "Workout", name: name, icon: "figure.run", color: AppColors.dominant, snapshot: snapshot, onTap: onTap)

            case .module(_, let name, let snapshot):
                TemplateContentCard(type: "Module", name: name, icon: "square.stack.3d.up.fill", color: AppColors.accent3, snapshot: snapshot, onTap: onTap)

            case .highlights(let snapshot):
                HighlightsContentCard(snapshot: snapshot)

            case .text:
                EmptyView()
            }
        }
    }
}
