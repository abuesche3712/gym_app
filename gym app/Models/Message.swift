//
//  Message.swift
//  gym app
//
//  Message model for direct messaging (Phase 3)
//

import Foundation

/// Represents a message in a conversation
struct Message: Identifiable, Codable, Hashable {
    var schemaVersion: Int = SchemaVersions.message
    var id: UUID
    var conversationId: UUID
    var senderId: String  // Firebase UID
    var content: MessageContent
    var createdAt: Date
    var readAt: Date?  // nil = unread by recipient
    var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        senderId: String,
        content: MessageContent,
        createdAt: Date = Date(),
        readAt: Date? = nil,
        syncStatus: SyncStatus = .pendingSync
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.createdAt = createdAt
        self.readAt = readAt
        self.syncStatus = syncStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersions.message
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        senderId = try container.decode(String.self, forKey: .senderId)
        content = try container.decode(MessageContent.self, forKey: .content)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .pendingSync
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, conversationId, senderId, content, createdAt, readAt, syncStatus
    }
}

// MARK: - Message Helpers

extension Message {
    /// Check if this message was sent by the given user
    func isSentBy(_ userId: String) -> Bool {
        senderId == userId
    }

    /// Check if this message has been read
    var isRead: Bool {
        readAt != nil
    }
}

// MARK: - Message Content

/// Content types for messages - text now, shared content for Phase 4
enum MessageContent: Codable, Equatable, Hashable {
    case text(String)

    // Template sharing (Phase 4)
    case sharedProgram(id: UUID, name: String, snapshot: Data)
    case sharedWorkout(id: UUID, name: String, snapshot: Data)
    case sharedModule(id: UUID, name: String, snapshot: Data)

    // Performance sharing (Phase 4)
    case sharedSession(id: UUID, workoutName: String, date: Date, snapshot: Data)
    case sharedExercise(snapshot: Data)  // SessionExercise with all sets
    case sharedSet(snapshot: Data)       // Single SetData (PR brag)
    case sharedCompletedModule(snapshot: Data)  // CompletedModule from a session
    case sharedHighlights(snapshot: Data)  // Multiple exercises/sets bundled together

    // Granular sharing (Phase 4 extension)
    case sharedExerciseInstance(snapshot: Data)  // Exercise config (importable)
    case sharedSetGroup(snapshot: Data)           // Set prescription (view-only)
    case sharedCompletedSetGroup(snapshot: Data)  // Completed sets from a session

    // Error handling
    case decodeFailed(originalType: String?)  // Fallback when decoding fails

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, snapshot, workoutName, date, originalType
    }

    private enum ContentType: String, Codable {
        case text, sharedProgram, sharedWorkout, sharedModule, sharedSession, sharedExercise, sharedSet, sharedCompletedModule, sharedHighlights
        case sharedExerciseInstance, sharedSetGroup, sharedCompletedSetGroup
        case decodeFailed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case .sharedProgram:
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedProgram(id: id, name: name, snapshot: snapshot)
        case .sharedWorkout:
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedWorkout(id: id, name: name, snapshot: snapshot)
        case .sharedModule:
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedModule(id: id, name: name, snapshot: snapshot)
        case .sharedSession:
            let id = try container.decode(UUID.self, forKey: .id)
            let workoutName = try container.decode(String.self, forKey: .workoutName)
            let date = try container.decode(Date.self, forKey: .date)
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedSession(id: id, workoutName: workoutName, date: date, snapshot: snapshot)
        case .sharedExercise:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedExercise(snapshot: snapshot)
        case .sharedSet:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedSet(snapshot: snapshot)
        case .sharedCompletedModule:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedCompletedModule(snapshot: snapshot)
        case .sharedHighlights:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedHighlights(snapshot: snapshot)
        case .sharedExerciseInstance:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedExerciseInstance(snapshot: snapshot)
        case .sharedSetGroup:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedSetGroup(snapshot: snapshot)
        case .sharedCompletedSetGroup:
            let snapshot = try container.decode(Data.self, forKey: .snapshot)
            self = .sharedCompletedSetGroup(snapshot: snapshot)
        case .decodeFailed:
            let originalType = try container.decodeIfPresent(String.self, forKey: .originalType)
            self = .decodeFailed(originalType: originalType)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(text, forKey: .text)
        case .sharedProgram(let id, let name, let snapshot):
            try container.encode(ContentType.sharedProgram, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedWorkout(let id, let name, let snapshot):
            try container.encode(ContentType.sharedWorkout, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedModule(let id, let name, let snapshot):
            try container.encode(ContentType.sharedModule, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedSession(let id, let workoutName, let date, let snapshot):
            try container.encode(ContentType.sharedSession, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(workoutName, forKey: .workoutName)
            try container.encode(date, forKey: .date)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedExercise(let snapshot):
            try container.encode(ContentType.sharedExercise, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedSet(let snapshot):
            try container.encode(ContentType.sharedSet, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedCompletedModule(let snapshot):
            try container.encode(ContentType.sharedCompletedModule, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedHighlights(let snapshot):
            try container.encode(ContentType.sharedHighlights, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedExerciseInstance(let snapshot):
            try container.encode(ContentType.sharedExerciseInstance, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedSetGroup(let snapshot):
            try container.encode(ContentType.sharedSetGroup, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .sharedCompletedSetGroup(let snapshot):
            try container.encode(ContentType.sharedCompletedSetGroup, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .decodeFailed(let originalType):
            try container.encode(ContentType.decodeFailed, forKey: .type)
            try container.encodeIfPresent(originalType, forKey: .originalType)
        }
    }
}

// MARK: - MessageContent Helpers

extension MessageContent {
    /// Preview text for conversation list
    var previewText: String {
        switch self {
        case .text(let str):
            return String(str.prefix(50))
        case .sharedProgram(_, let name, _):
            return "Shared program: \(name)"
        case .sharedWorkout(_, let name, _):
            return "Shared workout: \(name)"
        case .sharedModule(_, let name, _):
            return "Shared module: \(name)"
        case .sharedSession(_, let name, _, _):
            return "Completed: \(name)"
        case .sharedExercise:
            return "Shared exercise"
        case .sharedSet:
            return "Shared set"
        case .sharedCompletedModule:
            return "Shared module results"
        case .sharedHighlights:
            return "Shared workout highlights"
        case .sharedExerciseInstance:
            return "Shared exercise config"
        case .sharedSetGroup:
            return "Shared set prescription"
        case .sharedCompletedSetGroup:
            return "Shared completed sets"
        case .decodeFailed(let originalType):
            if let type = originalType {
                return "[Failed to load \(type)]"
            }
            return "[Failed to load content]"
        }
    }

    /// Check if this is a text message
    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    /// Get the text content if this is a text message
    var textValue: String? {
        if case .text(let str) = self { return str }
        return nil
    }
}
