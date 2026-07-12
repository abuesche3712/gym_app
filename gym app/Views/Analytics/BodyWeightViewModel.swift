//
//  BodyWeightViewModel.swift
//  gym app
//
//  View-model wrapper around BodyWeightRepository for the Analytics bodyweight card.
//  Local-only feature: no cloud sync.
//

import Foundation
import Combine

@MainActor
final class BodyWeightViewModel: ObservableObject {
    @Published private(set) var entries: [BodyWeightEntry] = []

    private let repo: BodyWeightRepository
    private var cancellable: AnyCancellable?

    init(repo: BodyWeightRepository? = nil) {
        let resolvedRepo = repo ?? DataRepository.shared.bodyWeightRepo
        self.repo = resolvedRepo
        entries = resolvedRepo.entries

        cancellable = resolvedRepo.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.entries = entries
            }
    }

    var latestEntry: BodyWeightEntry? {
        entries.last
    }

    private var previousEntry: BodyWeightEntry? {
        guard entries.count >= 2 else { return nil }
        return entries[entries.count - 2]
    }

    /// Change in kg between the latest two entries, if there are at least two.
    var latestDeltaKg: Double? {
        guard let latest = latestEntry, let previous = previousEntry else { return nil }
        return latest.weightKg - previous.weightKg
    }

    /// Chart points within the given analytics time range (ascending by date).
    func chartPoints(in range: AnalyticsTimeRange) -> [BodyWeightPoint] {
        filteredEntries(in: range).map { BodyWeightPoint(date: $0.date, weightKg: $0.weightKg) }
    }

    /// Entries within the given time range, ascending by date.
    func filteredEntries(in range: AnalyticsTimeRange) -> [BodyWeightEntry] {
        guard let days = range.dayWindow else { return entries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return entries.filter { $0.date >= cutoff }
    }

    /// Most recent entries first, for the recent-entries list.
    func recentEntries(limit: Int = 20) -> [BodyWeightEntry] {
        Array(entries.reversed().prefix(limit))
    }

    func addEntry(weightKg: Double, date: Date = Date(), note: String? = nil) {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = BodyWeightEntry(
            date: date,
            weightKg: weightKg,
            note: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote
        )
        repo.save(entry)
        Logger.debug("BodyWeightViewModel: added entry \(entry.weightKg)kg on \(entry.date)")
    }

    func delete(_ entry: BodyWeightEntry) {
        repo.delete(entry)
    }

    func delete(at offsets: IndexSet, from list: [BodyWeightEntry]) {
        for index in offsets {
            delete(list[index])
        }
    }
}
