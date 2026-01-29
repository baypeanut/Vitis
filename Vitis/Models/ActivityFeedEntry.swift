//
//  ActivityFeedEntry.swift
//  Vitis
//
//  API model for activity_feed with nested profile, wine, target_wine.
//  Used for Global / Following feed and Realtime payloads.
//

import Foundation

struct ActivityFeedEntry: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let activityType: ActivityType
    let wineId: UUID
    let targetWineId: UUID?
    let contentText: String?
    let createdAt: Date

    let user: ProfilePayload?
    let wine: WinePayload?
    let targetWine: WinePayload?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case wineId = "wine_id"
        case targetWineId = "target_wine_id"
        case contentText = "content_text"
        case createdAt = "created_at"
        case user
        case wine
        case targetWine = "target_wine"
    }
}

struct ProfilePayload: Codable, Sendable {
    let id: UUID
    let username: String
    let avatarUrl: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case avatarUrl = "avatar_url"
    }
}

struct WinePayload: Codable, Sendable {
    let id: UUID
    let name: String
    let producer: String
    let vintage: Int?
    let variety: String?
    let region: String?
    let labelImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, producer, vintage, variety, region
        case labelImageUrl = "label_image_url"
    }
}
