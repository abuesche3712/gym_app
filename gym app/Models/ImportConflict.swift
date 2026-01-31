//
//  ImportConflict.swift
//  gym app
//
//  Types for handling conflicts when importing shared content
//

import Foundation

// MARK: - Import Conflict

/// Represents a conflict when importing shared content
enum ImportConflict: Identifiable {
    case template(TemplateConflict)
    case implement(ImplementConflict)

    var id: UUID {
        switch self {
        case .template(let conflict): return conflict.id
        case .implement(let conflict): return conflict.id
        }
    }

    var title: String {
        switch self {
        case .template(let conflict): return "Exercise: \(conflict.existingName)"
        case .implement(let conflict): return "Equipment: \(conflict.existingName)"
        }
    }
}

// MARK: - Template Conflict

/// Conflict between an imported exercise template and an existing one
struct TemplateConflict: Identifiable {
    let id: UUID
    let existingId: UUID
    let existingName: String
    let importedTemplate: ExerciseTemplate
    var resolution: ConflictResolution = .useExisting

    init(existingId: UUID, existingName: String, importedTemplate: ExerciseTemplate) {
        self.id = UUID()
        self.existingId = existingId
        self.existingName = existingName
        self.importedTemplate = importedTemplate
    }
}

// MARK: - Implement Conflict

/// Conflict between an imported implement and an existing one
struct ImplementConflict: Identifiable {
    let id: UUID
    let existingId: UUID
    let existingName: String
    let importedImplement: ImplementSnapshot
    var resolution: ConflictResolution = .useExisting

    init(existingId: UUID, existingName: String, importedImplement: ImplementSnapshot) {
        self.id = UUID()
        self.existingId = existingId
        self.existingName = existingName
        self.importedImplement = importedImplement
    }
}

// MARK: - Conflict Resolution

/// How to resolve an import conflict
enum ConflictResolution: String, CaseIterable, Identifiable {
    case useExisting = "Use Existing"
    case importAsCopy = "Import as Copy"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .useExisting:
            return "Keep your existing version and link to it"
        case .importAsCopy:
            return "Create a new copy with a different name"
        }
    }

    var icon: String {
        switch self {
        case .useExisting: return "checkmark.circle"
        case .importAsCopy: return "doc.on.doc"
        }
    }
}

// MARK: - Import Result

/// Result of importing shared content
struct ImportResult {
    let success: Bool
    let importedId: UUID?
    let importedName: String?
    let message: String

    static func success(id: UUID, name: String) -> ImportResult {
        ImportResult(success: true, importedId: id, importedName: name, message: "Successfully imported \(name)")
    }

    static func failure(_ message: String) -> ImportResult {
        ImportResult(success: false, importedId: nil, importedName: nil, message: message)
    }
}

// MARK: - Import Options

/// Options for importing shared content
struct ImportOptions {
    /// Resolutions for detected conflicts
    var conflictResolutions: [UUID: ConflictResolution] = [:]

    /// Whether to automatically skip items that already exist
    var skipExisting: Bool = false

    /// Default resolution for unspecified conflicts
    var defaultResolution: ConflictResolution = .useExisting

    init() {}

    func resolution(for conflictId: UUID) -> ConflictResolution {
        conflictResolutions[conflictId] ?? defaultResolution
    }
}
