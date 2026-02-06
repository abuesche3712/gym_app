//
//  ComposePostViewModel.swift
//  gym app
//
//  ViewModel for creating new posts
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let didCreatePost = Notification.Name("didCreatePost")
    static let didUpdatePostCommentCount = Notification.Name("didUpdatePostCommentCount")
}

@MainActor
class ComposePostViewModel: ObservableObject {
    @Published var caption: String = ""
    @Published var isPosting = false
    @Published var error: Error?
    @Published var scheduledDate: Date?

    @Published private(set) var content: PostContent
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
        loadDraft()
    }

    // MARK: - Content Management

    /// Set content from a shareable item
    func setContent(_ shareableContent: any ShareableContent) {
        do {
            let messageContent = try shareableContent.createMessageContent()
            self.content = PostContent(from: messageContent)
            self.contentCreationError = nil
        } catch {
            Logger.error(error, context: "ComposePostViewModel.setContent")
            self.contentCreationError = error
        }
    }

    /// Clear the attached content (revert to text-only)
    func clearContent() {
        self.content = .text("")
        self.contentCreationError = nil
    }

    // MARK: - Actions

    var isScheduled: Bool {
        scheduledDate != nil
    }

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
            caption: caption.isEmpty ? nil : caption,
            scheduledFor: scheduledDate
        )

        // If scheduled for the future, save locally only
        if let scheduled = scheduledDate, scheduled > Date() {
            Self.saveScheduledPost(post)
            HapticManager.shared.success()
            clearDraft()
            return true
        }

        do {
            try await firestoreService.savePost(post)
            postRepo.save(post)
            HapticManager.shared.success()
            clearDraft()

            // Notify that a new post was created so feed can refresh
            NotificationCenter.default.post(name: .didCreatePost, object: post)

            return true
        } catch {
            self.error = error
            return false
        }
    }

    // MARK: - Scheduled Posts

    private static let scheduledPostsKey = "scheduled_posts"

    static func saveScheduledPost(_ post: Post) {
        var posts = loadScheduledPosts()
        posts.append(post)
        if let data = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(data, forKey: scheduledPostsKey)
        }
    }

    static func loadScheduledPosts() -> [Post] {
        guard let data = UserDefaults.standard.data(forKey: scheduledPostsKey),
              let posts = try? JSONDecoder().decode([Post].self, from: data) else {
            return []
        }
        return posts
    }

    private static func saveScheduledPosts(_ posts: [Post]) {
        if posts.isEmpty {
            UserDefaults.standard.removeObject(forKey: scheduledPostsKey)
        } else if let data = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(data, forKey: scheduledPostsKey)
        }
    }

    /// Publish any scheduled posts that are due. Called on app launch.
    static func publishScheduledPosts() async {
        let posts = loadScheduledPosts()
        guard !posts.isEmpty else { return }

        let now = Date()
        var remaining: [Post] = []
        let firestoreService = FirestoreService.shared
        let postRepo = PostRepository()

        for post in posts {
            if let scheduledFor = post.scheduledFor, scheduledFor <= now {
                // Time to publish
                var publishPost = post
                publishPost.scheduledFor = nil
                publishPost.createdAt = Date() // Use current time
                do {
                    try await firestoreService.savePost(publishPost)
                    postRepo.save(publishPost)
                    NotificationCenter.default.post(name: .didCreatePost, object: publishPost)
                    Logger.debug("Published scheduled post: \(publishPost.id)")
                } catch {
                    Logger.error(error, context: "publishScheduledPosts")
                    remaining.append(post) // Keep for retry
                }
            } else {
                remaining.append(post) // Not yet due
            }
        }

        saveScheduledPosts(remaining)
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
        case .highlights(let snapshot):
            if let bundle = try? HighlightsShareBundle.decode(from: snapshot) {
                let count = bundle.exercises.count + bundle.sets.count
                return "\(count) Highlight\(count == 1 ? "" : "s") from \(bundle.workoutName)"
            }
            return "Highlights"
        case .text:
            return "Text post"
        }
    }

    var contentIcon: String {
        content.icon
    }

    // MARK: - Draft Management

    private static let draftCaptionKey = "compose_post_draft_caption"

    var hasDraft: Bool {
        !caption.isEmpty
    }

    func saveDraft() {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.draftCaptionKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.draftCaptionKey)
        }
    }

    func loadDraft() {
        if let saved = UserDefaults.standard.string(forKey: Self.draftCaptionKey), !saved.isEmpty {
            caption = saved
        }
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftCaptionKey)
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
