//
//  Report.swift
//  gym app
//
//  Model for reporting inappropriate content
//

import Foundation

// MARK: - Report Reason

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "Spam"
    case harassment = "Harassment"
    case inappropriateContent = "Inappropriate Content"
    case impersonation = "Impersonation"
    case other = "Other"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .spam: return "This content is spam or misleading"
        case .harassment: return "This content is harassing or bullying"
        case .inappropriateContent: return "This content is inappropriate or offensive"
        case .impersonation: return "This account is impersonating someone"
        case .other: return "Other reason"
        }
    }
}

// MARK: - Content Moderation

enum ContentModerationError: LocalizedError, Equatable {
    case empty(field: String)
    case tooLong(field: String, limit: Int)
    case blocked(field: String)

    var errorDescription: String? {
        switch self {
        case .empty(let field):
            return "\(field) cannot be empty."
        case .tooLong(let field, let limit):
            return "\(field) must be \(limit) characters or fewer."
        case .blocked:
            return "This content cannot be posted. Edit it and try again."
        }
    }
}

enum ContentModerationService {
    private static let blockedPhrases = [
        "kill yourself",
        "kys",
        "nazi",
        "white power",
        "porn",
        "onlyfans",
        "buy followers",
        "free crypto",
        "cashapp",
        "telegram me",
        "whatsapp me"
    ]

    private static let blockedWords: Set<String> = [
        "suicidebait",
        "terrorist",
        "scammer"
    ]

    static func validateUserText(
        _ text: String,
        fieldName: String,
        maxLength: Int,
        allowEmpty: Bool = false
    ) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if allowEmpty { return "" }
            throw ContentModerationError.empty(field: fieldName)
        }

        guard trimmed.count <= maxLength else {
            throw ContentModerationError.tooLong(field: fieldName, limit: maxLength)
        }

        guard isAllowed(trimmed) else {
            throw ContentModerationError.blocked(field: fieldName)
        }

        return trimmed
    }

    static func isAllowed(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard !blockedPhrases.contains(where: { normalized.contains($0) }) else {
            return false
        }

        let words = normalized.split(separator: " ").map(String.init)
        return words.allSatisfy { !blockedWords.contains($0) }
    }

    private static func normalize(_ text: String) -> String {
        let lowercased = text.lowercased()
        var result = ""
        var previousWasSpace = false

        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasSpace = false
            } else if !previousWasSpace {
                result.append(" ")
                previousWasSpace = true
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Report Content Type

enum ReportContentType: String, Codable {
    case post
    case comment
    case message
    case user
}

// MARK: - Report Model

struct Report: Identifiable, Codable {
    var id: UUID
    var reporterId: String  // Firebase UID
    var reportedUserId: String  // Firebase UID of reported user
    var contentType: ReportContentType
    var contentId: String?  // UUID string of the content
    var reason: ReportReason
    var additionalInfo: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        reporterId: String,
        reportedUserId: String,
        contentType: ReportContentType,
        contentId: String? = nil,
        reason: ReportReason,
        additionalInfo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reporterId = reporterId
        self.reportedUserId = reportedUserId
        self.contentType = contentType
        self.contentId = contentId
        self.reason = reason
        self.additionalInfo = additionalInfo
        self.createdAt = createdAt
    }
}
