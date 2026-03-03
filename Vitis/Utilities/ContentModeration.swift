//
//  ContentModeration.swift
//  Vitis
//
//  App Store Guideline 1.2: method for filtering objectionable material before posting.
//  Simple client-side keyword check for tasting notes and comments.
//

import Foundation

enum ContentModeration {
    /// Blocklist of objectionable terms (lowercased). Kept minimal; expand as needed.
    private static let blocklist: Set<String> = [
        "fuck", "shit", "ass", "bitch", "damn", "crap", "dick", "pussy", "cock",
        "nigger", "nigga", "faggot", "fag", "retard", "rape", "nazi", "hitler",
        "kill yourself", "kys", "die"
    ]

    /// Returns true if the text contains objectionable content (blocked from posting).
    static func containsObjectionableContent(_ text: String) -> Bool {
        let normalized = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let words = normalized
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        for word in words {
            if blocklist.contains(word) { return true }
        }
        for term in blocklist where term.contains(" ") {
            if normalized.contains(term) { return true }
        }
        return false
    }

    /// User-facing message when content is blocked (Quiet Luxury tone).
    static let blockedMessage = "We value refined conversation. Please adjust your note for clarity and tone."
}
