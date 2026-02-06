//
//  CommentRow.swift
//  gym app
//
//  Comment row for post detail view
//

import SwiftUI

struct CommentRow: View {
    let comment: CommentWithAuthor
    let canDelete: Bool
    let canEdit: Bool
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil
    var onReply: (() -> Void)? = nil

    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Avatar
            ProfilePhotoView(
                profile: comment.author,
                size: 32,
                borderWidth: 0
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack(spacing: AppSpacing.xs) {
                    Text(comment.author.displayName ?? comment.author.username)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)

                    if comment.comment.updatedAt != nil {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    if canDelete || canEdit {
                        Menu {
                            if canEdit {
                                Button {
                                    onEdit?()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }

                            if let onReply = onReply {
                                Button {
                                    onReply()
                                } label: {
                                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                                }
                            }

                            if canDelete {
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24, height: 24)
                        }
                    }
                }

                // Comment text
                RichTextView(comment.comment.text, font: .subheadline)
                    .lineSpacing(2)
            }
        }
        .padding(AppSpacing.md)
        .confirmationDialog(
            "Delete Comment?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var relativeTime: String { formatRelativeTimeShort(comment.comment.createdAt) }
}
