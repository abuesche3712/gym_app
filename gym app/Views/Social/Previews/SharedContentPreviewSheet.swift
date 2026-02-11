//
//  SharedContentPreviewSheet.swift
//  gym app
//
//  Coordinator sheet for previewing shared content with navigation support
//

import SwiftUI

struct SharedContentPreviewSheet: View {
    let content: MessageContent
    let onImport: ((Bool) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingImportAlert = false
    @State private var importResult: ImportResult?
    @State private var isImporting = false

    init(content: MessageContent, onImport: ((Bool) -> Void)? = nil) {
        self.content = content
        self.onImport = onImport
    }

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .sharedProgram(_, _, let snapshot):
                    if let bundle = try? ProgramShareBundle.decode(from: snapshot) {
                        SharedProgramPreviewView(bundle: bundle, onImport: handleImport)
                    } else {
                        errorView(message: "Unable to load program data")
                    }

                case .sharedWorkout(_, _, let snapshot):
                    if let bundle = try? WorkoutShareBundle.decode(from: snapshot) {
                        SharedWorkoutPreviewView(
                            workout: bundle.workout,
                            modules: bundle.modules,
                            showImportButton: true,
                            onImport: handleImport
                        )
                    } else {
                        errorView(message: "Unable to load workout data")
                    }

                case .sharedModule(_, _, let snapshot):
                    if let bundle = try? ModuleShareBundle.decode(from: snapshot) {
                        SharedModulePreviewView(
                            module: bundle.module,
                            showImportButton: true,
                            onImport: handleImport
                        )
                    } else {
                        errorView(message: "Unable to load module data")
                    }

                case .sharedSession(_, _, _, let snapshot):
                    if let bundle = try? SessionShareBundle.decode(from: snapshot) {
                        SessionDetailView(session: bundle.session, readOnly: true)
                    } else {
                        errorView(message: "Unable to load session data")
                    }

                default:
                    errorView(message: "This content type cannot be previewed")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .disabled(isImporting)
            .overlay {
                if isImporting {
                    ProgressView("Importing...")
                        .padding()
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(AppCorners.medium)
                        .shadow(radius: 10)
                }
            }
        }
        .alert("Import Result", isPresented: $showingImportAlert) {
            Button("OK") {
                if let result = importResult, result.success {
                    onImport?(true)
                    dismiss()
                }
            }
        } message: {
            if let result = importResult {
                Text(result.message)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "Cannot Preview",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Import Handling

    private func handleImport() {
        isImporting = true

        Task {
            do {
                let result: ImportResult

                switch content {
                case .sharedProgram(_, _, let snapshot):
                    let bundle = try ProgramShareBundle.decode(from: snapshot)
                    result = await MainActor.run {
                        SharingService.shared.importProgram(from: bundle)
                    }

                case .sharedWorkout(_, _, let snapshot):
                    let bundle = try WorkoutShareBundle.decode(from: snapshot)
                    result = await MainActor.run {
                        SharingService.shared.importWorkout(from: bundle)
                    }

                case .sharedModule(_, _, let snapshot):
                    let bundle = try ModuleShareBundle.decode(from: snapshot)
                    result = await MainActor.run {
                        SharingService.shared.importModule(from: bundle)
                    }

                default:
                    result = .failure("This content type cannot be imported")
                }

                await MainActor.run {
                    isImporting = false
                    importResult = result
                    showingImportAlert = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importResult = .failure(error.localizedDescription)
                    showingImportAlert = true
                }
            }
        }
    }
}

#Preview("Program Preview") {
    SharedContentPreviewSheet(
        content: .sharedProgram(id: UUID(), name: "Test Program", snapshot: Data())
    )
}

#Preview("Workout Preview") {
    SharedContentPreviewSheet(
        content: .sharedWorkout(id: UUID(), name: "Test Workout", snapshot: Data())
    )
}
