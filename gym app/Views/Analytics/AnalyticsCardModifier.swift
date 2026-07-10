//
//  AnalyticsCardModifier.swift
//  gym app
//
//  Shared styling for analytics cards. Delegates to the canonical
//  unifiedCard() modifier (Theme/Components.swift) so Analytics call
//  sites don't need to churn their modifier name.
//

import SwiftUI

extension View {
    func analyticsCard() -> some View {
        unifiedCard()
    }
}
