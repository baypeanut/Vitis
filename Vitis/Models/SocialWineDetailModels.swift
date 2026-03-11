//
//  SocialWineDetailModels.swift
//  Pari
//
//  Host-centric social wine detail: host review + mutual friends who tasted.
//

import Foundation

/// A single review (host or mutual friend) for Social Wine Detail.
struct SocialReview: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let avatarURL: String?
    let rating: Double
    let comment: String?
    let tasteTags: [String]
    let createdAt: Date
}

/// Grouped by user: one entry per friend, primary review (most recent with comment, or most recent).
struct GroupedFriendReview: Identifiable, Sendable {
    let userId: UUID
    let displayName: String
    let avatarURL: String?
    let primaryReview: SocialReview
    let additionalCount: Int
    var id: UUID { userId }
    var hasComment: Bool { primaryReview.comment?.isEmpty == false }
}
