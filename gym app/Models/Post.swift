//
//  Post.swift
//  gym app
//
//  Social feed post model for sharing workout content publicly
//

import Foundation

// MARK: - Post Model

struct Post: Identifiable, Codable, Hashable {
    var schemaVersion: Int
    var id: UUID
    var authorId: String  // Firebase UID
    var content: PostContent
    var caption: String?
    var createdAt: Date
    var updatedAt: Date?
    var likeCount: Int
    var commentCount: Int
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        authorId: String,
        content: PostContent,
        caption: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        likeCount: Int = 0,
        commentCount: Int = 0,
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.schemaVersion = SchemaVersions.post
        self.id = id
        self.authorId = authorId
        self.content = content
        self.caption = caption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.syncStatus = syncStatus
    }
}

// MARK: - Post Content

/// Reuses the shared content types from MessageContent for consistency
enum PostContent: Codable, Hashable {
    case session(id: UUID, workoutName: String, date: Date, snapshot: Data)
    case exercise(snapshot: Data)
    case set(snapshot: Data)
    case completedModule(snapshot: Data)  // CompletedModule from a session
    case program(id: UUID, name: String, snapshot: Data)
    case workout(id: UUID, name: String, snapshot: Data)
    case module(id: UUID, name: String, snapshot: Data)
    case text(String)  // Plain text post

    // Convert from MessageContent for sharing
    init(from messageContent: MessageContent) {
        switch messageContent {
        case .text(let text):
            self = .text(text)
        case .sharedProgram(let id, let name, let snapshot):
            self = .program(id: id, name: name, snapshot: snapshot)
        case .sharedWorkout(let id, let name, let snapshot):
            self = .workout(id: id, name: name, snapshot: snapshot)
        case .sharedModule(let id, let name, let snapshot):
            self = .module(id: id, name: name, snapshot: snapshot)
        case .sharedSession(let id, let workoutName, let date, let snapshot):
            self = .session(id: id, workoutName: workoutName, date: date, snapshot: snapshot)
        case .sharedExercise(let snapshot):
            self = .exercise(snapshot: snapshot)
        case .sharedSet(let snapshot):
            self = .set(snapshot: snapshot)
        case .sharedCompletedModule(let snapshot):
            self = .completedModule(snapshot: snapshot)
        }
    }

    // Convert to MessageContent for reusing SharedContentCard
    func toMessageContent() -> MessageContent {
        switch self {
        case .text(let text):
            return .text(text)
        case .program(let id, let name, let snapshot):
            return .sharedProgram(id: id, name: name, snapshot: snapshot)
        case .workout(let id, let name, let snapshot):
            return .sharedWorkout(id: id, name: name, snapshot: snapshot)
        case .module(let id, let name, let snapshot):
            return .sharedModule(id: id, name: name, snapshot: snapshot)
        case .session(let id, let workoutName, let date, let snapshot):
            return .sharedSession(id: id, workoutName: workoutName, date: date, snapshot: snapshot)
        case .exercise(let snapshot):
            return .sharedExercise(snapshot: snapshot)
        case .set(let snapshot):
            return .sharedSet(snapshot: snapshot)
        case .completedModule(let snapshot):
            return .sharedCompletedModule(snapshot: snapshot)
        }
    }

    /// Display title for the content
    var displayTitle: String {
        switch self {
        case .session(_, let workoutName, _, _):
            return workoutName
        case .exercise(let snapshot):
            if let bundle = try? ExerciseShareBundle.decode(from: snapshot) {
                return bundle.exerciseName
            }
            return "Exercise"
        case .set(let snapshot):
            if let bundle = try? SetShareBundle.decode(from: snapshot) {
                return bundle.exerciseName
            }
            return "Set"
        case .completedModule(let snapshot):
            if let bundle = try? CompletedModuleShareBundle.decode(from: snapshot) {
                return bundle.module.moduleName
            }
            return "Module"
        case .program(_, let name, _):
            return name
        case .workout(_, let name, _):
            return name
        case .module(_, let name, _):
            return name
        case .text(let text):
            return String(text.prefix(50))
        }
    }

    /// Icon for the content type
    var icon: String {
        switch self {
        case .session: return "checkmark.circle.fill"
        case .exercise: return "figure.strengthtraining.traditional"
        case .set: return "flame.fill"
        case .completedModule: return "square.stack.3d.up.fill"
        case .program: return "doc.text.fill"
        case .workout: return "figure.run"
        case .module: return "square.stack.3d.up.fill"
        case .text: return "text.quote"
        }
    }
}

// MARK: - Post Like

struct PostLike: Identifiable, Codable, Hashable {
    var schemaVersion: Int
    var id: UUID
    var postId: UUID
    var userId: String  // Firebase UID
    var createdAt: Date
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        postId: UUID,
        userId: String,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.schemaVersion = SchemaVersions.postLike
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
        self.syncStatus = syncStatus
    }
}

// MARK: - Post Comment

struct PostComment: Identifiable, Codable, Hashable {
    var schemaVersion: Int
    var id: UUID
    var postId: UUID
    var authorId: String  // Firebase UID
    var text: String
    var createdAt: Date
    var updatedAt: Date?
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        postId: UUID,
        authorId: String,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.schemaVersion = SchemaVersions.postComment
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}

// MARK: - Helper Types

/// Post with author profile for UI display
struct PostWithAuthor: Identifiable, Hashable {
    let post: Post
    let author: UserProfile
    var isLikedByCurrentUser: Bool

    var id: UUID { post.id }

    init(post: Post, author: UserProfile, isLikedByCurrentUser: Bool = false) {
        self.post = post
        self.author = author
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
}

/// Comment with author profile for UI display
struct CommentWithAuthor: Identifiable, Hashable {
    let comment: PostComment
    let author: UserProfile

    var id: UUID { comment.id }
}

