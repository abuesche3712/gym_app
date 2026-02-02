//
//  ImportDataView.swift
//  gym app
//
//  Import workout history from Strong app CSV exports
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionViewModel: SessionViewModel

    // Import state
    @State private var importState: ImportState = .ready
    @State private var selectedWeightUnit: WeightUnit = .lbs
    @State private var importResult: StrongImportResult?
    @State private var importProgress: (current: Int, total: Int) = (0, 0)
    @State private var errorMessage: String = ""
    @State private var importTask: Task<Void, Never>?

    // File picker
    @State private var showingFilePicker = false

    private let importService = StrongImportService()

    enum ImportState {
        case ready
        case parsing
        case preview
        case importing
        case complete
        case error
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                switch importState {
                case .ready:
                    readyStateView
                case .parsing:
                    parsingStateView
                case .preview:
                    previewStateView
                case .importing:
                    importingStateView
                case .complete:
                    completeStateView
                case .error:
                    errorStateView
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            // Default to app's current weight unit
            selectedWeightUnit = appState.weightUnit
        }
        .onDisappear {
            // Cancel any running import task
            importTask?.cancel()
        }
    }

    // MARK: - Ready State

    private var readyStateView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
                .frame(height: AppSpacing.xl)

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.dominant.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.dominant)
            }

            // Title
            Text("Import from Strong")
                .displayMedium(color: AppColors.textPrimary)

            // Instructions
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                instructionRow(number: "1", text: "Open Strong app and go to Settings")
                instructionRow(number: "2", text: "Tap \"Export Data\" and save the CSV file")
                instructionRow(number: "3", text: "Select the CSV file below to import")
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )

            // Unit picker
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("WEIGHT UNIT IN CSV")
                    .caption(color: AppColors.textTertiary)
                    .fontWeight(.semibold)

                Picker("Weight Unit", selection: $selectedWeightUnit) {
                    Text("Pounds (lbs)").tag(WeightUnit.lbs)
                    Text("Kilograms (kg)").tag(WeightUnit.kg)
                }
                .pickerStyle(.segmented)
            }
            .padding(AppSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.large)
                    .fill(AppColors.surfacePrimary)
            )

            // Info note
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.dominant)
                Text("Your existing workout data won't be affected.")
                    .caption(color: AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCorners.medium)
                    .fill(AppColors.dominant.opacity(0.08))
            )

            Spacer()

            // Select file button
            Button {
                showingFilePicker = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.badge.plus")
                    Text("Select CSV File")
                }
                .headline(color: .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .fill(AppColors.dominant)
                )
            }
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(AppColors.dominant)
                )

            Text(text)
                .body(color: AppColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Parsing State

    private var parsingStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Reading workout data...")
                .headline(color: AppColors.textPrimary)

            Text("This may take a moment for large files")
                .caption(color: AppColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Preview State

    private var previewStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            if let result = importResult {
                // Summary header
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.success)

                    Text("Ready to Import")
                        .displaySmall(color: AppColors.textPrimary)
                }

                // Stats grid
                HStack(spacing: AppSpacing.md) {
                    statBox(value: "\(result.sessions.count)", label: "Workouts")
                    statBox(value: "\(result.exerciseNames.count)", label: "Exercises")
                    statBox(value: "\(totalSets(in: result))", label: "Sets")
                }

                // Date range
                if let dateRange = result.dateRange {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "calendar")
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(formatDate(dateRange.earliest)) – \(formatDate(dateRange.latest))")
                            .caption(color: AppColors.textSecondary)
                    }
                }

                // Duplicate warning
                if !result.duplicateSessions.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.warning)
                        Text("\(result.duplicateSessions.count) workouts may already exist. Importing will create duplicates.")
                            .caption(color: AppColors.textPrimary)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.warning.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                // Warnings
                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("\(result.skippedRows) rows skipped")
                            .caption(color: AppColors.textTertiary)
                            .fontWeight(.semibold)

                        ForEach(result.warnings.prefix(5), id: \.self) { warning in
                            Text("• \(warning)")
                                .caption(color: AppColors.textTertiary)
                        }

                        if result.warnings.count > 5 {
                            Text("... and \(result.warnings.count - 5) more")
                                .caption(color: AppColors.textTertiary)
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.surfacePrimary)
                    )
                }

                // Session preview list
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("WORKOUTS TO IMPORT")
                        .caption(color: AppColors.textTertiary)
                        .fontWeight(.semibold)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(result.sessions.prefix(50)) { session in
                                sessionPreviewRow(session: session, isDuplicate: result.duplicateSessions.contains(where: { $0.id == session.id }))
                            }

                            if result.sessions.count > 50 {
                                Text("... and \(result.sessions.count - 50) more workouts")
                                    .caption(color: AppColors.textTertiary)
                                    .padding()
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .fill(AppColors.surfacePrimary)
                    )
                }

                Spacer()

                // Action buttons
                VStack(spacing: AppSpacing.md) {
                    Button {
                        startImport()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import \(result.sessions.count) Workouts")
                        }
                        .headline(color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.dominant)
                        )
                    }

                    Button {
                        importState = .ready
                        importResult = nil
                    } label: {
                        Text("Cancel")
                            .headline(color: AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .displayMedium(color: AppColors.dominant)

            Text(label)
                .statLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCorners.medium)
                .fill(AppColors.dominant.opacity(0.08))
        )
    }

    private func sessionPreviewRow(session: Session, isDuplicate: Bool) -> some View {
        HStack(spacing: AppSpacing.md) {
            if isDuplicate {
                Circle()
                    .fill(AppColors.warning)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName)
                    .subheadline(color: AppColors.textPrimary)
                    .fontWeight(.semibold)

                HStack(spacing: AppSpacing.sm) {
                    Text(formatDate(session.date))
                        .caption(color: AppColors.textTertiary)

                    Text("•")
                        .caption(color: AppColors.textTertiary)

                    Text("\(session.totalExercisesCompleted) exercises")
                        .caption(color: AppColors.textTertiary)

                    Text("•")
                        .caption(color: AppColors.textTertiary)

                    Text("\(session.totalSetsCompleted) sets")
                        .caption(color: AppColors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Importing State

    private var importingStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Importing workouts...")
                .headline(color: AppColors.textPrimary)

            if importProgress.total > 0 {
                Text("\(importProgress.current) of \(importProgress.total)")
                    .monoMedium()

                ProgressView(value: Double(importProgress.current), total: Double(importProgress.total))
                    .tint(AppColors.dominant)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            Button {
                importTask?.cancel()
                importState = .ready
            } label: {
                Text("Cancel")
                    .headline(color: AppColors.textSecondary)
            }
        }
    }

    // MARK: - Complete State

    private var completeStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.success)
            }

            Text("Import Complete!")
                .displayMedium(color: AppColors.textPrimary)

            if let result = importResult {
                Text("Successfully imported \(result.sessions.count) workouts containing \(result.exerciseNames.count) exercises")
                    .body(color: AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .headline(color: .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppCorners.medium)
                            .fill(AppColors.dominant)
                    )
            }
        }
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.error.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.error)
            }

            Text("Import Failed")
                .displayMedium(color: AppColors.textPrimary)

            Text(errorMessage)
                .body(color: AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()

            VStack(spacing: AppSpacing.md) {
                Button {
                    importState = .ready
                    errorMessage = ""
                } label: {
                    Text("Try Again")
                        .headline(color: .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppCorners.medium)
                                .fill(AppColors.dominant)
                        )
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .headline(color: AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            parseFile(at: url)

        case .failure(let error):
            errorMessage = error.localizedDescription
            importState = .error
        }
    }

    private func parseFile(at url: URL) {
        importState = .parsing

        Task {
            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw StrongImportError.invalidFormat("Cannot access file. Please try selecting it again.")
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                // Read file data
                let data = try Data(contentsOf: url)

                // Parse CSV
                let result = try importService.importCSV(
                    data: data,
                    csvWeightUnit: selectedWeightUnit,
                    appWeightUnit: appState.weightUnit,
                    existingSessions: sessionViewModel.sessions
                )

                await MainActor.run {
                    self.importResult = result
                    self.importState = .preview
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.importState = .error
                }
            }
        }
    }

    private func startImport() {
        guard let result = importResult else { return }

        importState = .importing
        importProgress = (0, result.sessions.count)

        importTask = Task {
            let repository = DataRepository.shared

            for (index, session) in result.sessions.enumerated() {
                // Check for cancellation
                if Task.isCancelled {
                    await MainActor.run {
                        importState = .ready
                    }
                    return
                }

                // Save session
                repository.saveSession(session)

                // Update progress
                await MainActor.run {
                    importProgress = (index + 1, result.sessions.count)
                }

                // Small delay to avoid overwhelming CoreData and show progress
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }

            // Refresh session list - load ALL sessions so imported old data appears
            await MainActor.run {
                sessionViewModel.loadAllSessions()
                importState = .complete
            }
        }
    }

    // MARK: - Helpers

    private func totalSets(in result: StrongImportResult) -> Int {
        result.sessions.reduce(0) { $0 + $1.totalSetsCompleted }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ImportDataView()
            .environmentObject(AppState.shared)
            .environmentObject(AppState.shared.sessionViewModel)
    }
}
