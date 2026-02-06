//
//  ReportSheet.swift
//  gym app
//
//  Sheet for reporting inappropriate content or users
//

import SwiftUI

struct ReportSheet: View {
    let reportedUserId: String
    let contentType: ReportContentType
    var contentId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var additionalInfo = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var error: Error?

    private let activityService = FirestoreActivityService.shared
    private let authService = AuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Why are you reporting this?")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        Text("Select a reason that best describes the issue.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Reason picker
                    VStack(spacing: 0) {
                        ForEach(ReportReason.allCases) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reason.rawValue)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppColors.textPrimary)

                                        Text(reason.description)
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary)
                                    }

                                    Spacer()

                                    if selectedReason == reason {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.dominant)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                }
                                .padding(AppSpacing.md)
                            }
                            .buttonStyle(.plain)

                            if reason != ReportReason.allCases.last {
                                Divider()
                                    .padding(.leading, AppSpacing.md)
                            }
                        }
                    }
                    .background(AppColors.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCorners.large)
                            .stroke(AppColors.surfaceTertiary.opacity(0.5), lineWidth: 1)
                    )

                    // Additional details
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Additional details (optional)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)

                        TextField("Provide more context...", text: $additionalInfo, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding(AppSpacing.md)
                            .background(AppColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCorners.medium)
                                    .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Submit button
                    Button {
                        submitReport()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Submit Report")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(selectedReason != nil ? AppColors.error : AppColors.textTertiary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppCorners.medium))
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
                .padding(AppSpacing.screenPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Report Submitted", isPresented: $showingConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you for your report. We'll review it shortly.")
            }
        }
    }

    private func submitReport() {
        guard let reason = selectedReason,
              let reporterId = authService.currentUser?.uid else { return }

        isSubmitting = true

        let report = Report(
            reporterId: reporterId,
            reportedUserId: reportedUserId,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo
        )

        Task {
            do {
                try await activityService.submitReport(report)
                isSubmitting = false
                showingConfirmation = true
                HapticManager.shared.success()
            } catch {
                self.error = error
                isSubmitting = false
            }
        }
    }
}
