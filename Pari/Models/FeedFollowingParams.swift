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
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pViewerId = "p_viewer_id"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pViewerId, forKey: .pViewerId)
        try c.encode(pLimit, forKey: .pLimit)
        try c.encode(pOffset, forKey: .pOffset)
    }
}
