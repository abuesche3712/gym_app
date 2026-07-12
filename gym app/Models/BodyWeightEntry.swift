//
//  BodyWeightEntry.swift
//  gym app
//
//  Local-only bodyweight tracking entry. Not synced to cloud.
//

import Foundation

/// A single bodyweight log entry. Weight is always stored in kilograms;
/// views convert to the user's preferred display unit (see `AppState.weightUnit`).
struct BodyWeightEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weightKg: Double,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.note = note
    }
}
