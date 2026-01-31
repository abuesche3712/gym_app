//
//  UsernameValidation.swift
//  gym app
//
//  Username validation utilities for user profiles
//

import Foundation

/// Result of username validation
struct UsernameValidation {
    let isValid: Bool
    let error: UsernameError?

    static let valid = UsernameValidation(isValid: true, error: nil)

    static func invalid(_ error: UsernameError) -> UsernameValidation {
        UsernameValidation(isValid: false, error: error)
    }
}

/// Username validation errors
enum UsernameError: Error, LocalizedError {
    case empty
    case tooShort(minLength: Int)
    case tooLong(maxLength: Int)
    case invalidCharacters
    case startsWithSpecialChar
    case endsWithSpecialChar
    case consecutiveSpecialChars
    case reserved
    case alreadyTaken

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Username is required"
        case .tooShort(let minLength):
            return "Username must be at least \(minLength) character\(minLength == 1 ? "" : "s")"
        case .tooLong(let maxLength):
            return "Username must be \(maxLength) characters or less"
        case .invalidCharacters:
            return "Username can only contain letters, numbers, dots, underscores, and hyphens"
        case .startsWithSpecialChar:
            return "Username must start with a letter or number"
        case .endsWithSpecialChar:
            return "Username must end with a letter or number"
        case .consecutiveSpecialChars:
            return "Username cannot have consecutive dots, underscores, or hyphens"
        case .reserved:
            return "This username is reserved"
        case .alreadyTaken:
            return "This username is already taken"
        }
    }
}

/// Username validation utilities
enum UsernameValidator {
    static let minLength = 1
    static let maxLength = 32
    static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
    static let specialCharacters = CharacterSet(charactersIn: "._-")

    /// Reserved usernames that cannot be claimed
    static let reservedUsernames: Set<String> = [
        "admin", "administrator", "support", "help", "system", "mod", "moderator",
        "official", "staff", "team", "gymapp", "gym_app", "gym-app"
    ]

    /// Validates a username according to rules
    /// - Parameter username: The username to validate (will be lowercased)
    /// - Returns: Validation result with error if invalid
    static func validate(_ username: String) -> UsernameValidation {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespaces)

        // Check empty
        guard !normalized.isEmpty else {
            return .invalid(.empty)
        }

        // Check length
        guard normalized.count >= minLength else {
            return .invalid(.tooShort(minLength: minLength))
        }
        guard normalized.count <= maxLength else {
            return .invalid(.tooLong(maxLength: maxLength))
        }

        // Check characters
        let usernameCharSet = CharacterSet(charactersIn: normalized)
        guard usernameCharSet.isSubset(of: allowedCharacters) else {
            return .invalid(.invalidCharacters)
        }

        // Check doesn't start with special char
        if let first = normalized.unicodeScalars.first,
           specialCharacters.contains(first) {
            return .invalid(.startsWithSpecialChar)
        }

        // Check doesn't end with special char
        if let last = normalized.unicodeScalars.last,
           specialCharacters.contains(last) {
            return .invalid(.endsWithSpecialChar)
        }

        // Check no consecutive special characters
        var previousWasSpecial = false
        for scalar in normalized.unicodeScalars {
            let isSpecial = specialCharacters.contains(scalar)
            if isSpecial && previousWasSpecial {
                return .invalid(.consecutiveSpecialChars)
            }
            previousWasSpecial = isSpecial
        }

        // Check not reserved
        guard !reservedUsernames.contains(normalized) else {
            return .invalid(.reserved)
        }

        return .valid
    }

    /// Normalizes a username (lowercase, trimmed)
    static func normalize(_ username: String) -> String {
        username.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
