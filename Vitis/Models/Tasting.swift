//
//  Tasting.swift
//  Vitis
//
//  Wine tasting log: rating (1.0-10.0), optional notes, created_at.
//

import Foundation

struct Tasting: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let wineId: UUID
    let rating: Double
    let noteTags: [String]?
    let createdAt: Date
    let source: String?
    let wine: Wine

    init(
        id: UUID,
        userId: UUID,
        wineId: UUID,
        rating: Double,
        noteTags: [String]? = nil,
        createdAt: Date,
        source: String? = nil,
        wine: Wine
    ) {
        self.id = id
        self.userId = userId
        self.wineId = wineId
        self.rating = rating
        self.noteTags = noteTags
        self.createdAt = createdAt
        self.source = source
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
