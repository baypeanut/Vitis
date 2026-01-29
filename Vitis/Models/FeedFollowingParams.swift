//
//  FeedFollowingParams.swift
//  Vitis
//
//  RPC params for feed_following. Explicit Sendable + nonisolated encode
//  so encoding works from non–MainActor contexts (Supabase default isolation).
//

import Foundation

struct FeedFollowingParams: Encodable, Sendable {
    let pFollowerId: UUID
    let pLimit: Int
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pFollowerId = "p_follower_id"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pFollowerId, forKey: .pFollowerId)
        try c.encode(pLimit, forKey: .pLimit)
        try c.encode(pOffset, forKey: .pOffset)
    }
}
