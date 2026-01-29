//
//  Follow.swift
//  Vitis
//
//  Matches follows table: follower_id, followed_id, created_at.
//

import Foundation

struct Follow: Sendable {
    let followerId: UUID
    let followedId: UUID
    let createdAt: Date
}
