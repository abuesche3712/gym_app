//
//  HistoryView.swift
//  gym app
//
//  View for browsing past workout sessions
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
    }

    var filteredSessions: [Session] {
        var sessions = sessionViewModel.sessions

        // Apply date filter
        let now = Date()
        let calendar = Calendar.current

        switch selectedFilter {
        case .all:
            break
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            sessions = sessions.filter { $0.date >= startOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            sessions = sessions.filter { $0.date >= startOfMonth }
        }

        // Apply search filter
        if !searchText.isEmpty {
            sessions = sessions.filter {
                $0.workoutName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return sessions
    }

    var groupedSessions: [(String, [Session])] {
        let grouped = Dictionary(grouping: filteredSessions) { session -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: session.date)
        }

        return grouped.sorted { pair1, pair2 in
            guard let date1 = filteredSessions.first(where: { session in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: session.date) == pair1.0
            })?.date,
                  let date2 = filteredSessions.first(where: { session in
                      let formatter = DateFormatter()
                      formatter.dateFormat = "MMMM yyyy"
                      return formatter.string(from: session.date) == pair2.0
                  })?.date else {
                return false
            }
            return date1 > date2
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            FilterPill(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Complete a workout to see it here")
                    )
                } else {
                    ForEach(groupedSessions, id: \.0) { month, sessions in
                        Section(month) {
                            ForEach(sessions) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionHistoryRow(session: session)
                                }
                            }
                            .onDelete { offsets in
                                let sessionsToDelete = offsets.map { sessions[$0] }
                                for session in sessionsToDelete {
                                    sessionViewModel.deleteSession(session)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search workouts")
            .refreshable {
                sessionViewModel.loadSessions()
            }
        }
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.workoutName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Text(formatDate(session.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let duration = session.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Module types completed
                HStack(spacing: 4) {
                    ForEach(session.completedModules.prefix(4)) { module in
                        Image(systemName: module.moduleType.icon)
                            .font(.caption2)
                            .foregroundStyle(Color(module.moduleType.color))
                    }
                    if session.completedModules.count > 4 {
                        Text("+\(session.completedModules.count - 4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let feeling = session.overallFeeling {
                    FeelingIndicator(feeling: feeling)
                }

                Text("\(session.totalSetsCompleted) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
        .environmentObject(SessionViewModel())
}
