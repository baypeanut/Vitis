//
//  CommentCheers.swift
//  Vitis
//
//  comments_cheers: comment_body null => Cheer; non-null => Comment.
//

import Foundation

struct CommentCheers: Codable, Sendable {
    let id: UUID
    let activityId: UUID
    let userId: UUID
    let commentBody: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case userId = "user_id"
        case commentBody = "comment_body"
        case createdAt = "created_at"
    }

    var isCheer: Bool { commentBody == nil || commentBody?.isEmpty == true }
}
