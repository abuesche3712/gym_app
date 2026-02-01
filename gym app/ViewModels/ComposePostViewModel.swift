//
//  ComposePostViewModel.swift
//  gym app
//
//  ViewModel for creating new posts
//

import Foundation

@MainActor
class ComposePostViewModel: ObservableObject {
    @Published var caption: String = ""
    @Published var isPosting = false
    @Published var error: Error?

    let content: PostContent
    private(set) var contentCreationError: Error?

    private let postRepo: PostRepository
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    var currentUserId: String? { authService.currentUser?.uid }

    /// Initialize with shareable content
    init(content: any ShareableContent, postRepo: PostRepository = PostRepository()) {
        do {
            let messageContent = try content.createMessageContent()
            self.content = PostContent(from: messageContent)
            self.contentCreationError = nil
        } catch {
            print("[ComposePostViewModel] Error creating content: \(error)")
            self.content = .text("Error creating content: \(error.localizedDescription)")
            self.contentCreationError = error
        }
        self.postRepo = postRepo
    }

    /// Initialize with already-created PostContent
    init(postContent: PostContent, postRepo: PostRepository = PostRepository()) {
        self.content = postContent
        self.postRepo = postRepo
    }

    /// Initialize for a text-only post
    init(postRepo: PostRepository = PostRepository()) {
        self.content = .text("")
        self.postRepo = postRepo
    }

    // MARK: - Actions

    func createPost() async -> Bool {
        guard let userId = currentUserId else {
            error = PostError.notAuthenticated
            return false
        }

        isPosting = true
        defer { isPosting = false }

        // For text-only posts, use the caption as content
        let finalContent: PostContent
        if case .text = content, !caption.isEmpty {
            finalContent = .text(caption)
        } else {
            finalContent = content
        }

        let post = Post(
            authorId: userId,
            content: finalContent,
            caption: caption.isEmpty ? nil : caption
        )

        do {
            try await firestoreService.savePost(post)
            postRepo.save(post)
            HapticManager.shared.success()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    var contentPreview: String {
        switch content {
        case .session(_, let workoutName, let date, _):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Workout: \(workoutName) - \(formatter.string(from: date))"
        case .exercise(let snapshot):
            if let bundle = try? ExerciseShareBundle.decode(from: snapshot) {
                return "Exercise: \(bundle.exerciseName)"
            }
            return "Exercise"
        case .set(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot) {
                let prLabel = bundle.isPR ? " (PR!)" : ""
                return "Set: \(bundle.exerciseName)\(prLabel)"
            }
            return "Set"
        case .program(_, let name, _):
            return "Program: \(name)"
        case .workout(_, let name, _):
            return "Workout: \(name)"
        case .module(_, let name, _):
            return "Module: \(name)"
        case .completedModule(let snapshot):
            if let bundle = try? CompletedModuleShareBundle.decode(from: snapshot) {
                return "Module: \(bundle.module.moduleName)"
            }
            return "Completed Module"
        case .text:
            return "Text post"
        }
    }

    var contentIcon: String {
        content.icon
    }
}

// MARK: - Post Errors

enum PostError: LocalizedError {
    case notAuthenticated
    case contentMissing
    case postFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to post"
        case .contentMissing:
            return "Post content is missing"
        case .postFailed:
            return "Failed to create post"
        }
    }
}
