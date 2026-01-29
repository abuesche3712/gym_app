//
//  DebugSyncLogsView.swift
//  gym app
//
//  Debug view for viewing sync operation logs
//  Hidden behind a gesture in SettingsView for TestFlight debugging
//

import SwiftUI

struct DebugSyncLogsView: View {
    @State private var logs: [SyncLogEntry] = []
    @State private var selectedSeverity: SyncLogSeverity? = nil
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @State private var showingShareSheet = false
    @State private var exportedText = ""

    private let logger = SyncLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader

            // Filter bar
            filterBar

            // Log list
            if filteredLogs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Sync Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        exportedText = logger.exportLogsAsText()
                        showingShareSheet = true
                    } label: {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadLogs()
        }
        .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                logger.clearLogs()
                loadLogs()
            }
        } message: {
            Text("This will permanently delete all sync logs.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: exportedText)
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(spacing: AppSpacing.lg) {
            StatBadge(
                count: logs.count,
                label: "Total",
                color: AppColors.textSecondary
            )

            StatBadge(
                count: logs.filter { $0.severity == .error }.count,
                label: "Errors",
                color: AppColors.error
            )

            StatBadge(
                count: logs.filter { $0.severity == .warning }.count,
                label: "Warnings",
                color: AppColors.warning
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                FilterChip(
                    label: "All",
                    isSelected: selectedSeverity == nil,
                    action: { selectedSeverity = nil }
                )

                ForEach(SyncLogSeverity.allCases, id: \.self) { severity in
                    FilterChip(
                        label: severity.rawValue.capitalized,
                        icon: severity.icon,
                        isSelected: selectedSeverity == severity,
                        action: { selectedSeverity = severity }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.surfacePrimary.opacity(0.5))
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredLogs) { log in
                    LogRowView(log: log)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No Logs")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Text(selectedSeverity == nil ? "Sync logs will appear here" : "No \(selectedSeverity!.rawValue) logs found")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var filteredLogs: [SyncLogEntry] {
        var result = logs

        if let severity = selectedSeverity {
            result = result.filter { $0.severity == severity }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.context.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - Helpers

    private func loadLogs() {
        logs = logger.getRecentLogs(limit: 100)
    }
}

// MARK: - Supporting Views

private struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.dominant : AppColors.surfacePrimary)
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
        }
    }
}

private struct LogRowView: View {
    let log: SyncLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                // Severity icon
                Image(systemName: log.severity.icon)
                    .font(.caption)
                    .foregroundColor(severityColor)

                // Context
                Text(log.context)
                    .font(.caption.bold())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Timestamp
                Text(log.formattedTimestamp)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Message
            Text(log.message)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(3)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfacePrimary)
    }

    private var severityColor: Color {
        switch log.severity {
        case .info: return AppColors.textSecondary
        case .warning: return AppColors.warning
        case .error: return AppColors.error
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DebugSyncLogsView()
    }
}
