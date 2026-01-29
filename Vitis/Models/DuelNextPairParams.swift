//
//  DuelNextPairParams.swift
//  Vitis
//
//  RPC params for duel_next_pair. Sendable + nonisolated encode for Supabase.
//

import Foundation

struct DuelNextPairParams: Encodable, Sendable {
    let pUserId: UUID

    enum CodingKeys: String, CodingKey {
        case pUserId = "p_user_id"
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pUserId, forKey: .pUserId)
    }
}
