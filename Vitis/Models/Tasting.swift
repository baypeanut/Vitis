//
//  Tasting.swift
//  Vitis
//
//  Wine tasting log: rating (1.0-10.0), optional notes, created_at.
//

import Foundation

/// Per-tasting visibility: public (everyone) or friends-only (mutual follow).
enum TastingVisibility: String, Codable, CaseIterable, Sendable {
    case everyone = "everyone"
    case friends = "friends"

    var displayName: String {
        switch self {
        case .everyone: return "Public"
        case .friends: return "Friends Only"
        }
    }

    var icon: String {
        switch self {
        case .everyone: return "globe"
        case .friends: return "person.2"
        }
    }
}

struct Tasting: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let wineId: UUID
    let rating: Double
    let noteTags: [String]?
    let comment: String?
    let createdAt: Date
    let source: String?
    let visibility: TastingVisibility
    let wine: Wine

    init(
        id: UUID,
        userId: UUID,
        wineId: UUID,
        rating: Double,
        noteTags: [String]? = nil,
        comment: String? = nil,
        createdAt: Date,
        source: String? = nil,
        visibility: TastingVisibility = .everyone,
        wine: Wine
    ) {
        self.id = id
        self.userId = userId
        self.wineId = wineId
        self.rating = rating
        self.noteTags = noteTags
        self.comment = comment
        self.createdAt = createdAt
        self.source = source
        self.visibility = visibility
        self.wine = wine
    }
}

extension Tasting {
    /// Format notes as comma-separated string for display (e.g. "Berry, vanilla").
    var notesDisplay: String? {
        guard let tags = noteTags, !tags.isEmpty else { return nil }
        return tags.joined(separator: ", ")
    }
}

// MARK: - TastingWithProfile

/// Tasting with user profile info for displaying other users' tastings.
struct TastingWithProfile: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let username: String
    let fullName: String?
    let avatarURL: String?
    let rating: Double
    let noteTags: [String]?
    let comment: String?
    let createdAt: Date
    
    /// Format notes as comma-separated string for display.
    var notesDisplay: String? {
        guard let tags = noteTags, !tags.isEmpty else { return nil }
        return tags.joined(separator: ", ")
    }
    
    /// Display name: full name if available, otherwise username.
    var displayName: String {
        if let full = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return full
        }
        return username
    }
}
