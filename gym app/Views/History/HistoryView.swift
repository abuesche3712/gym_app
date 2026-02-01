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
    @State private var selectedFilter: HistoryFilter = .all
    @State private var sessionToDelete: Session?
    @State private var showingDeleteConfirmation = false
    @State private var sessionToShare: Session?
    @State private var sessionToPost: Session?
    @State private var animateIn = false

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        var icon: String {
            switch self {
            case .all: return "infinity"
            case .thisWeek: return "calendar.badge.clock"
            case .thisMonth: return "calendar"
            }
        }
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

    // Aggregate stats for the selected period
    private var periodStats: (sessions: Int, sets: Int, volume: Double, duration: Int) {
        let sessions = filteredSessions
        let sets = sessions.reduce(0) { $0 + $1.totalSetsCompleted }
        let volume = sessions.reduce(0.0) { total, session in
            total + session.completedModules.filter { !$0.skipped }.reduce(0.0) { moduleTotal, module in
                moduleTotal + module.completedExercises.reduce(0.0) { $0 + $1.totalVolume }
            }
        }
        let duration = sessions.reduce(0) { $0 + ($1.duration ?? 0) }
        return (sessions.count, sets, volume, duration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Stats Summary Card
                    if !filteredSessions.isEmpty {
                        statsSummaryCard
                    }

                    // Filter Pills
                    filterPills

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
                sessionViewModel.loadSessions()
                HapticManager.shared.success()
            }
            .confirmationDialog(
                "Delete Workout?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        withAnimation(AppAnimation.standard) {
                            sessionViewModel.deleteSession(session)
                        }
                        HapticManager.shared.impact()
                    }
                    sessionToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                Text("This will permanently delete this workout from your history.")
            }
            .onChange(of: showingDeleteConfirmation) { _, isShowing in
                if isShowing {
                    HapticManager.shared.warning()
                }
            }
            .onAppear {
                withAnimation(AppAnimation.entrance) {
                    animateIn = true
                }
            }
            .sheet(item: $sessionToShare) { session in
                ShareWithFriendSheet(content: session) { conversationWithProfile in
                    let chatViewModel = ChatViewModel(
                        conversation: conversationWithProfile.conversation,
                        otherParticipant: conversationWithProfile.otherParticipant,
                        otherParticipantFirebaseId: conversationWithProfile.otherParticipantFirebaseId
                    )
                    let content = try session.createMessageContent()
                    try await chatViewModel.sendSharedContent(content)
                }
            }
            .sheet(item: $sessionToPost) { session in
                ComposePostSheet(content: session)
            }
        }
    }

    // MARK: - Stats Summary Card

    private var statsSummaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            miniStatCard(
                value: "\(periodStats.sessions)",
                label: "WORKOUTS",
                color: AppColors.dominant
            )

            miniStatCard(
                value: "\(periodStats.sets)",
                label: "SETS",
                color: AppColors.accent1
            )

            miniStatCard(
                value: formatVolume(periodStats.volume),
                label: "VOLUME",
                color: AppColors.accent3
            )

            miniStatCard(
                value: formatTotalDuration(periodStats.duration),
                label: "TIME",
                color: AppColors.accent2
            )
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    private func miniStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .displaySmall(color: color)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .caption2(color: AppColors.textTertiary)
                .fontWeight(.semibold)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    HistoryFilterPill(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(AppAnimation.quick) {
                            selectedFilter = filter
                        }
                        HapticManager.shared.tap()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
        .opacity(animateIn ? 1 : 0)
        .animation(AppAnimation.entrance.delay(0.1), value: animateIn)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.surfacePrimary)
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Sessions")
                    .headline()

                Text(searchText.isEmpty ? "Complete a workout to see it here" : "No workouts match your search")
                    .caption()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, AppSpacing.xxl)
        .opacity(animateIn ? 1 : 0)
        .animation(AppAnimation.entrance.delay(0.2), value: animateIn)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        LazyVStack(spacing: AppSpacing.xl) {
            ForEach(Array(groupedSessions.enumerated()), id: \.element.0) { groupIndex, group in
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
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                HistorySessionRow(session: session)
                            }
                            .buttonStyle(.plain)
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
                                    sessionToDelete = session
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            if index < sessions.count - 1 {
                                Divider()
                                    .background(AppColors.surfaceTertiary.opacity(0.5))
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .fill(AppColors.surfacePrimary)
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(AppAnimation.entrance.delay(0.15 + Double(groupIndex) * 0.05), value: animateIn)
            }
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 10000 {
            return String(format: "%.0fk", volume / 1000)
        } else if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        } else {
            return String(format: "%.0f", volume)
        }
    }

    private func formatTotalDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h\(mins > 0 ? " \(mins)m" : "")"
        }
        return "\(mins)m"
    }
}

// MARK: - History Filter Pill

struct HistoryFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)

                Text(title)
                    .subheadline(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.dominant.opacity(0.15) : AppColors.surfacePrimary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? AppColors.dominant.opacity(0.3) : AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Session Row

struct HistorySessionRow: View {
    let session: Session

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

                    if session.isFreestyle {
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

                Image(systemName: "chevron.right")
                    .caption(color: AppColors.textTertiary)
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
