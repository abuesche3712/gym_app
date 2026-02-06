//
//  TextParser.swift
//  gym app
//
//  Parses text for hashtags (#tag) and mentions (@username)
//

import Foundation

// MARK: - Parsed Token

enum ParsedTokenType {
    case text
    case hashtag
    case mention
}

struct ParsedToken {
    let type: ParsedTokenType
    let text: String      // The full text including # or @
    let value: String     // The value without # or @
}

// MARK: - Text Parser

struct TextParser {
    /// Regex for hashtags: # followed by 1-50 word characters
    private static let hashtagPattern = try! NSRegularExpression(
        pattern: "#(\\w{1,50})",
        options: []
    )

    /// Regex for mentions: @ followed by 1-32 word characters
    private static let mentionPattern = try! NSRegularExpression(
        pattern: "@(\\w{1,32})",
        options: []
    )

    /// Parse text into tokens of text, hashtags, and mentions
    static func parse(_ text: String) -> [ParsedToken] {
        guard !text.isEmpty else { return [] }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Find all hashtag and mention matches
        struct Match {
            let range: NSRange
            let type: ParsedTokenType
            let fullText: String
            let value: String
        }

        var matches: [Match] = []

        // Find hashtags
        let hashtagMatches = hashtagPattern.matches(in: text, range: fullRange)
        for match in hashtagMatches {
            let fullText = nsString.substring(with: match.range)
            let value = nsString.substring(with: match.range(at: 1))
            matches.append(Match(range: match.range, type: .hashtag, fullText: fullText, value: value))
        }

        // Find mentions
        let mentionMatches = mentionPattern.matches(in: text, range: fullRange)
        for match in mentionMatches {
            let fullText = nsString.substring(with: match.range)
            let value = nsString.substring(with: match.range(at: 1))
            matches.append(Match(range: match.range, type: .mention, fullText: fullText, value: value))
        }

        // Sort by location
        matches.sort { $0.range.location < $1.range.location }

        // Remove overlapping matches (keep the first one)
        var filteredMatches: [Match] = []
        var lastEnd = 0
        for match in matches {
            if match.range.location >= lastEnd {
                filteredMatches.append(match)
                lastEnd = match.range.location + match.range.length
            }
        }

        // Build tokens
        var tokens: [ParsedToken] = []
        var currentIndex = 0

        for match in filteredMatches {
            // Add text before this match
            if match.range.location > currentIndex {
                let textRange = NSRange(location: currentIndex, length: match.range.location - currentIndex)
                let textContent = nsString.substring(with: textRange)
                if !textContent.isEmpty {
                    tokens.append(ParsedToken(type: .text, text: textContent, value: textContent))
                }
            }

            // Add the match
            tokens.append(ParsedToken(type: match.type, text: match.fullText, value: match.value))
            currentIndex = match.range.location + match.range.length
        }

        // Add remaining text
        if currentIndex < nsString.length {
            let remaining = nsString.substring(from: currentIndex)
            if !remaining.isEmpty {
                tokens.append(ParsedToken(type: .text, text: remaining, value: remaining))
            }
        }

        return tokens
    }

    /// Extract all hashtags from text
    static func extractHashtags(from text: String) -> [String] {
        parse(text)
            .filter { $0.type == .hashtag }
            .map { $0.value }
    }

    /// Extract all mentions from text
    static func extractMentions(from text: String) -> [String] {
        parse(text)
            .filter { $0.type == .mention }
            .map { $0.value }
    }

    /// Check if text contains any hashtags or mentions
    static func containsRichContent(_ text: String) -> Bool {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        return hashtagPattern.firstMatch(in: text, range: fullRange) != nil ||
               mentionPattern.firstMatch(in: text, range: fullRange) != nil
    }
}
