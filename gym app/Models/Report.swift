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
