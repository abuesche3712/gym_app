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
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter
                                ) {
                                    withAnimation(AppAnimation.quick) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }

                    if filteredSessions.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No Sessions",
                            message: "Complete a workout to see it here"
                        )
                        .padding(.top, AppSpacing.xxl)
                    } else {
                        LazyVStack(spacing: AppSpacing.lg) {
                            ForEach(groupedSessions, id: \.0) { month, sessions in
                                VStack(alignment: .leading, spacing: AppSpacing.md) {
                                    Text(month)
                                        .font(.title3.bold())
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding(.horizontal, AppSpacing.screenPadding)

                                    VStack(spacing: 0) {
                                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                            NavigationLink(destination: SessionDetailView(session: session)) {
                                                SessionHistoryRow(session: session)
                                            }
                                            .buttonStyle(.plain)

                                            if index < sessions.count - 1 {
                                                Divider()
                                                    .background(AppColors.border)
                                                    .padding(.leading, 60)
                                            }
                                        }
                                    }
                                    .padding(AppSpacing.cardPadding)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCorners.large)
                                            .fill(AppColors.cardBackground)
                                    )
                                    .padding(.horizontal, AppSpacing.screenPadding)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background.ignoresSafeArea())
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
        HStack(spacing: AppSpacing.md) {
            // Date indicator
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accentBlue)
                Text(dayNumber)
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(session.workoutName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    if let duration = session.formattedDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(duration)
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }

                    Text("\(session.totalSetsCompleted) sets")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Module type indicators
                HStack(spacing: AppSpacing.xs) {
                    ForEach(session.completedModules.prefix(5)) { module in
                        Circle()
                            .fill(AppColors.moduleColor(module.moduleType))
                            .frame(width: 8, height: 8)
                    }
                    if session.completedModules.count > 5 {
                        Text("+\(session.completedModules.count - 5)")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                if let feeling = session.overallFeeling {
                    FeelingIndicator(feeling: feeling)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: session.date)
    }
}

#Preview {
    HistoryView()
        .environmentObject(SessionViewModel())
}
