//
//  FeedGlobalParams.swift
//  Vitis
//
//  RPC params for feed_global. viewer_id can be nil for anonymous (shows only everyone-visible activity).
//

import Foundation

struct FeedGlobalParams: Encodable, Sendable {
    let pViewerId: UUID?
    let pLimit: Int
    let pOffset: Int
    enum CodingKeys: String, CodingKey {
        case pViewerId = "p_viewer_id"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(pViewerId, forKey: .pViewerId)
        try c.encode(pLimit, forKey: .pLimit)
        try c.encode(pOffset, forKey: .pOffset)
    }
}
