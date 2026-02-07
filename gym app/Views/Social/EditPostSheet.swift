//
//  EditPostSheet.swift
//  gym app
//
//  Sheet for editing existing posts (caption and highlights)
//

import SwiftUI

struct EditPostSheet: View {
    @StateObject private var viewModel: EditPostViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCaptionFocused: Bool

    let onSave: (Post) -> Void

    @State private var showingHighlightPicker = false

    init(post: Post, onSave: @escaping (Post) -> Void) {
        _viewModel = StateObject(wrappedValue: EditPostViewModel(post: post))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Content preview section
                    contentPreview

                    // Session highlight editor (for session posts)
                    if viewModel.isSessionPost {
                        highlightSection
                    }

                    // Caption input
                    captionInput
                }
                .padding(AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PostEditorToolbar(
                    isProcessing: viewModel.isSaving,
                    canSubmit: viewModel.hasChanges,
                    submitTitle: "Save",
                    onCancel: { dismiss() },
                    onSubmit: { saveChanges() }
                )
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CONTENT")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)

            ContentPreviewCard(
                icon: contentIcon,
                iconColor: AppColors.dominant,
                title: contentTitle,
                subtitle: contentTypeLabel
            )
        }
    }

    // MARK: - Highlight Section

    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("HIGHLIGHTS")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)

                Spacer()

                Text("\(viewModel.highlightCount)/5")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            // Current highlights summary
            if viewModel.highlightCount > 0 {
                highlightsSummary
            } else {
                noHighlightsView
            }

            // Edit highlights button
            Button {
                showingHighlightPicker = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.medium))
                    Text("Edit Highlights")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(AppColors.dominant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCorners.medium)
                        .stroke(AppColors.dominant.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingHighlightPicker) {
            if let session = viewModel.session {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            Text("Select up to 5 highlights to feature")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HighlightSelectionCore(
                                session: session,
                                selectedExerciseIds: $viewModel.selectedExerciseIds,
                                selectedSetIds: $viewModel.selectedSetIds,
                                maxHighlights: 5
                            )
                        }
                        .padding(AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .background(AppColors.background.ignoresSafeArea())
                    .navigationTitle("Edit Highlights")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingHighlightPicker = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private var highlightsSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let session = viewModel.session {
                ForEach(session.completedModules.filter { !$0.skipped }) { module in
                    ForEach(module.completedExercises) { exercise in
                        if viewModel.isExerciseSelected(exercise.id) {
                            highlightRow(
                                name: exercise.exerciseName,
                                icon: "dumbbell.fill",
                                color: AppColors.dominant,
                                detail: "\(exercise.completedSetGroups.flatMap { $0.sets }.filter { $0.completed }.count) sets"
                            )
                        } else if let setIds = viewModel.selectedSetIds[exercise.id], !setIds.isEmpty {
                            ForEach(Array(setIds), id: \.self) { setId in
                                if let set = findSet(setId, in: exercise) {
                                    highlightRow(
                                        name: exercise.exerciseName,
                                        icon: "flame.fill",
                                        color: AppColors.accent1,
                                        detail: formatSetData(set, exercise: exercise)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    private var noHighlightsView: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "star")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary)

            Text("No highlights selected")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppCorners.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppCorners.large)
                .stroke(AppColors.surfaceTertiary.opacity(0.3), lineWidth: 1)
        )
    }

    private func highlightRow(name: String, icon: String, color: Color, detail: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)

            Text(name)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Caption Input

    private var captionInput: some View {
        CaptionInputView(
            caption: $viewModel.caption,
            isFocused: $isCaptionFocused
        )
    }

    // MARK: - Helpers

    private var contentIcon: String {
        if let bundle = viewModel.sessionBundle {
            return "checkmark.circle.fill"
        }
        return "doc.fill"
    }

    private var contentTitle: String {
        if let bundle = viewModel.sessionBundle {
            return bundle.workoutName
        }
        return "Post"
    }

    private var contentTypeLabel: String? {
        if viewModel.isSessionPost {
            return "Workout"
        }
        return nil
    }

    private func findSet(_ setId: UUID, in exercise: SessionExercise) -> SetData? {
        for setGroup in exercise.completedSetGroups {
            if let set = setGroup.sets.first(where: { $0.id == setId }) {
                return set
            }
        }
        return nil
    }

    private func saveChanges() {
        guard let updatedPost = viewModel.buildUpdatedPost() else { return }
        HapticManager.shared.tap()
        onSave(updatedPost)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    EditPostSheet(
        post: Post(
            authorId: "user1",
            content: .text("Test post"),
            caption: "Original caption"
        ),
        onSave: { _ in }
    )
}
