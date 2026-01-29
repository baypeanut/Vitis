//
//  Profile.swift
//  Vitis
//
//  User profile model: id, username, full_name, avatar_url, bio, social, taste snapshot, weekly goal.
//

import Foundation

struct Profile: Identifiable, Sendable {
    let id: UUID
    var username: String
    var fullName: String?
    var avatarURL: String?
    var bio: String?
    var instagramHandle: String?
    var tasteSnapshotLoves: String?
    var tasteSnapshotAvoids: String?
    var tasteSnapshotMood: String?
    var weeklyGoal: String?
    var createdAt: Date?

    init(
        id: UUID,
        username: String,
        fullName: String? = nil,
        avatarURL: String? = nil,
        bio: String? = nil,
        instagramHandle: String? = nil,
        tasteSnapshotLoves: String? = nil,
        tasteSnapshotAvoids: String? = nil,
        tasteSnapshotMood: String? = nil,
        weeklyGoal: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.bio = bio
        self.instagramHandle = instagramHandle
        self.tasteSnapshotLoves = tasteSnapshotLoves
        self.tasteSnapshotAvoids = tasteSnapshotAvoids
        self.tasteSnapshotMood = tasteSnapshotMood
        self.weeklyGoal = weeklyGoal
        self.createdAt = createdAt
    }

    /// Display name: full_name if non‑empty, else username. Use everywhere (Feed, Comments, Profile).
    var displayName: String {
        let n = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let n, !n.isEmpty { return n }
        return username
    }

    var memberSinceYear: Int? {
        guard let d = createdAt else { return nil }
        return Calendar.current.component(.year, from: d)
    }

    /// Bio capped at 140 chars for display.
    var bioTrimmed: String? {
        guard let b = bio?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty else { return nil }
        return String(b.prefix(140))
    }
}

// MARK: - Preview / Mock

#if DEBUG
extension Profile {
    static let preview = Profile(
        id: UUID(),
        username: "sommelier",
        fullName: "Ahmet",
        avatarURL: nil,
        bio: "Wine enthusiast. Rhône & Piedmont."
    )
}
#endif
