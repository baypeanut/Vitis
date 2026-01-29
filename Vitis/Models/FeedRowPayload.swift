//
//  FeedRowPayload.swift
//  Vitis
//
//  Decodes feed_with_details view rows.
//

import Foundation

struct FeedRowPayload: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let activityType: ActivityType
    let wineId: UUID
    let targetWineId: UUID?
    let contentText: String?
    let createdAt: Date
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let wineName: String
    let wineProducer: String
    let wineVintage: Int?
    let wineLabelUrl: String?
    let wineRegion: String?
    let wineCategory: String?
    let targetWineName: String?
    let targetWineProducer: String?
    let targetWineVintage: Int?
    let targetWineLabelUrl: String?
    let tastingNoteTags: [String]?
    let tastingRating: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case wineId = "wine_id"
        case targetWineId = "target_wine_id"
        case contentText = "content_text"
        case createdAt = "created_at"
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case wineName = "wine_name"
        case wineProducer = "wine_producer"
        case wineVintage = "wine_vintage"
        case wineLabelUrl = "wine_label_url"
        case wineRegion = "wine_region"
        case wineCategory = "wine_category"
        case targetWineName = "target_wine_name"
        case targetWineProducer = "target_wine_producer"
        case targetWineVintage = "target_wine_vintage"
        case targetWineLabelUrl = "target_wine_label_url"
        case tastingNoteTags = "tasting_note_tags"
        case tastingRating = "tasting_rating"
    }
}

extension FeedItem {
    static func from(row: FeedRowPayload, cheersCount: Int = 0, commentCount: Int = 0, hasCheered: Bool = false) -> FeedItem {
        let displayName = (row.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? row.fullName : nil) ?? row.username ?? "Unknown"
        // For had_wine, contentText contains notes if available
        let notesText = row.activityType == .hadWine ? (row.tastingNoteTags?.isEmpty == false ? row.tastingNoteTags!.joined(separator: ", ") : nil) : row.contentText
        return FeedItem(
            id: row.id,
            userId: row.userId,
            username: displayName,
            avatarURL: row.avatarUrl,
            activityType: row.activityType,
            wineName: row.wineName,
            wineProducer: row.wineProducer,
            wineVintage: row.wineVintage,
            wineLabelURL: row.wineLabelUrl,
            wineRegion: row.wineRegion,
            wineCategory: row.wineCategory,
            targetWineName: row.targetWineName,
            targetWineProducer: row.targetWineProducer,
            targetWineVintage: row.targetWineVintage,
            targetWineLabelURL: row.targetWineLabelUrl,
            contentText: notesText,
            tastingRating: row.tastingRating,
            createdAt: row.createdAt,
            cheersCount: cheersCount,
            commentCount: commentCount,
            hasCheered: hasCheered
        )
    }
}
