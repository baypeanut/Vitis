//
//  FeedFollowingParams.swift
//  Pari
//
//  RPC params for feed_following. Explicit Sendable + nonisolated encode
//  so encoding works from non–MainActor contexts (Supabase default isolation).
//

import Foundation

struct FeedFollowingParams: Encodable, Sendable {
    let pViewerId: UUID
    let pLimit: Int
    let pCursor: Date?

    enum CodingKeys: String, CodingKey {
        case pViewerId = "p_viewer_id"
        case pLimit = "p_limit"
        case pCursor = "p_cursor"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pViewerId, forKey: .pViewerId)
        try c.encode(pLimit, forKey: .pLimit)
        try c.encodeIfPresent(pCursor, forKey: .pCursor)
    }
}
