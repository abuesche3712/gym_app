//
//  HistoryView.swift
//  gym app
//
//  Beautiful history view for browsing past workout sessions
//  Designed to match the modular, shareable aesthetic
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @State private var searchText = ""
    @State private var sessionToShare: Session?
    @State private var sessionToPost: Session?

    // Selection mode support for share flow
    var selectionMode: ViewSelectionMode? = nil
    var onSelectForShare: ((Session) -> Void)? = nil

    private var isSelectionMode: Bool { selectionMode != nil }

    var filteredSessions: [Session] {
        var sessions = sessionViewModel.visibleSessions

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
                VStack(spacing: AppSpacing.xl) {
                    // Sessions List
                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        sessionsList
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search workouts")
            .refreshable {
                sessionViewModel.loadAllSessions()
                HapticManager.shared.success()
            }
            .sheet(item: $sessionToShare) { session in
                ShareWithFriendSheet(content: session)
            }
            .sheet(item: $sessionToPost) { session in
                ComposePostSheet(content: session)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No Sessions",
            subtitle: searchText.isEmpty ? "Complete a workout to see it here" : "No workouts match your search"
        )
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        LazyVStack(spacing: AppSpacing.xl) {
            ForEach(groupedSessions, id: \.0) { group in
                let (month, sessions) = group

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Month header
                    Text(month)
                        .displaySmall(color: AppColors.textPrimary)
                        .fontWeight(.bold)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    // Sessions in month
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            if isSelectionMode {
                                Button {
                                    onSelectForShare?(session)
                                } label: {
                                    HistorySessionRow(session: session, showShareIcon: true)
                                }
                                .buttonStyle(.pressable)
                            } else {
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    HistorySessionRow(session: session)
                                }
                                .buttonStyle(.pressable)
                                .contextMenu {
                                    Button {
                                        sessionToPost = session
                                    } label: {
                                        Label("Post to Feed", systemImage: "rectangle.stack")
                                    }

                                    Button {
                                        sessionToShare = session
                                    } label: {
                                        Label("Share with Friend", systemImage: "paperplane")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        withAnimation(AppAnimation.standard) {
                                            sessionViewModel.softDeleteSession(session)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            if index < sessions.count - 1 {
                                Divider()
                                    .background(AppColors.surfaceTertiary.opacity(0.5))
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .unifiedCard(padding: 0, stroke: false)
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            }
        }
    }
}

// MARK: - History Filter Pill

// MARK: - History Session Row

struct HistorySessionRow: View {
    let session: Session
    var showShareIcon: Bool = false

    private var totalVolume: Double {
        session.completedModules.filter { !$0.skipped }.reduce(0.0) { total, module in
            total + module.completedExercises.reduce(0.0) { $0 + $1.totalVolume }
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Date indicator
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .caption2(color: AppColors.dominant)
                    .fontWeight(.bold)
                    .tracking(0.5)

                Text(dayNumber)
                    .displaySmall(color: AppColors.textPrimary)
                    .fontWeight(.bold)
            }
            .frame(width: 48)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.dominant.opacity(0.08))
            )

            // Main content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Workout name with session type badge
                HStack(spacing: AppSpacing.sm) {
                    Text(session.workoutName)
                        .headline()
                        .lineLimit(1)

                    if session.isImported {
                        Label("Imported", systemImage: "square.and.arrow.down")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textTertiary)
                    } else if session.isFreestyle {
                        Label("Freestyle", systemImage: "figure.mixed.cardio")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.accent3)
                    } else if session.isQuickLog {
                        Label("Quick Log", systemImage: "bolt.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.accent2)
                    }
                }

                // Stats row
                HStack(spacing: AppSpacing.md) {
                    if let duration = session.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .caption(color: AppColors.textSecondary)
                    }

                    Label("\(session.totalSetsCompleted) sets", systemImage: "square.stack.3d.up")
                        .caption(color: AppColors.textSecondary)

                    if totalVolume > 0 {
                        Text(formatVolume(totalVolume))
                            .caption(color: AppColors.accent3)
                    }
                }

                // Module indicators
                HStack(spacing: AppSpacing.xs) {
                    ForEach(session.completedModules.prefix(4)) { module in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(AppColors.moduleColor(module.moduleType))
                                .frame(width: 6, height: 6)

                            if session.completedModules.count <= 3 {
                                Text(module.moduleName)
                                    .caption2(color: AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    if session.completedModules.count > 4 {
                        Text("+\(session.completedModules.count - 4)")
                            .caption2(color: AppColors.textTertiary)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Right side
            VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                if let feeling = session.overallFeeling {
                    HistoryFeelingBadge(feeling: feeling)
                }

                Image(systemName: showShareIcon ? "square.and.arrow.up" : "chevron.right")
                    .caption(color: showShareIcon ? AppColors.dominant : AppColors.textTertiary)
                    .fontWeight(.semibold)
            }
        }
        .padding(AppSpacing.cardPadding)
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

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 10000 {
            return String(format: "%.1fk lbs", volume / 1000)
        } else if volume >= 1000 {
            return String(format: "%.0f lbs", volume)
        } else {
            return String(format: "%.0f lbs", volume)
        }
    }
}

// MARK: - History Feeling Badge

struct HistoryFeelingBadge: View {
    let feeling: Int

    private var color: Color {
        switch feeling {
        case 1...3: return AppColors.error
        case 4...6: return AppColors.warning
        case 7...10: return AppColors.success
        default: return AppColors.textSecondary
        }
    }

    private var emoji: String {
        switch feeling {
        case 1...3: return "😓"
        case 4...6: return "😐"
        case 7...8: return "😊"
        case 9...10: return "🔥"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .caption(color: AppColors.textPrimary)

            Text("\(feeling)")
                .caption(color: color)
                .fontWeight(.bold)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environmentObject(SessionViewModel())
}
