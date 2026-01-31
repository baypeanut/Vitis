//
//  FeedCache.swift
//  Vitis
//
//  Persist feed items to disk for instant load; fetch fresh in background.
//

import Foundation

struct FeedCache {
    private let fileManager = FileManager.default
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: s) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            guard let d = fmt.date(from: s) else {
                let ctx = DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ISO8601 date: \(s)",
                    underlyingError: nil
                )
                throw DecodingError.dataCorrupted(ctx)
            }
            return d
        }
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(fmt.string(from: date))
        }
        return e
    }()

    func cacheURL(_ key: String) -> URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("\(key).json", isDirectory: false)
    }

    func load(_ key: String) -> [FeedItem] {
        guard let url = cacheURL(key),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let cached = try? decoder.decode([FeedItemCacheDTO].self, from: data) else {
            return []
        }
        return cached.compactMap { $0.toFeedItem() }
    }

    func save(_ items: [FeedItem], key: String) {
        guard let url = cacheURL(key),
              let data = try? encoder.encode(items.map { FeedItemCacheDTO.from($0) }) else { return }
        try? data.write(to: url)
    }
}

private struct FeedItemCacheDTO: Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarURL: String?
    let activityTypeRaw: String
    let wineName: String
    let wineProducer: String
    let wineVintage: Int?
    let wineLabelURL: String?
    let wineRegion: String?
    let wineCategory: String?
    let wineVariety: String?
    let targetWineName: String?
    let targetWineProducer: String?
    let targetWineVintage: Int?
    let targetWineLabelURL: String?
    let contentText: String?
    let tastingRating: Double?
    let createdAt: Date
    let cheersCount: Int
    let commentCount: Int
    let hasCheered: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId, username, avatarURL
        case activityTypeRaw = "activityType"
        case wineName, wineProducer, wineVintage, wineLabelURL
        case wineRegion, wineCategory, wineVariety
        case targetWineName, targetWineProducer, targetWineVintage, targetWineLabelURL
        case contentText, tastingRating, createdAt, cheersCount, commentCount, hasCheered
    }

    static func from(_ item: FeedItem) -> FeedItemCacheDTO {
        FeedItemCacheDTO(
            id: item.id,
            userId: item.userId,
            username: item.username,
            avatarURL: item.avatarURL,
            activityTypeRaw: item.activityType.rawValue,
            wineName: item.wineName,
            wineProducer: item.wineProducer,
            wineVintage: item.wineVintage,
            wineLabelURL: item.wineLabelURL,
            wineRegion: item.wineRegion,
            wineCategory: item.wineCategory,
            wineVariety: item.wineVariety,
            targetWineName: item.targetWineName,
            targetWineProducer: item.targetWineProducer,
            targetWineVintage: item.targetWineVintage,
            targetWineLabelURL: item.targetWineLabelURL,
            contentText: item.contentText,
            tastingRating: item.tastingRating,
            createdAt: item.createdAt,
            cheersCount: item.cheersCount,
            commentCount: item.commentCount,
            hasCheered: item.hasCheered
        )
    }

    func toFeedItem() -> FeedItem? {
        guard let type = ActivityType(rawValue: activityTypeRaw) else { return nil }
        return FeedItem(
            id: id,
            userId: userId,
            username: username,
            avatarURL: avatarURL,
            activityType: type,
            wineName: wineName,
            wineProducer: wineProducer,
            wineVintage: wineVintage,
            wineLabelURL: wineLabelURL,
            wineRegion: wineRegion,
            wineCategory: wineCategory,
            wineVariety: wineVariety,
            targetWineName: targetWineName,
            targetWineProducer: targetWineProducer,
            targetWineVintage: targetWineVintage,
            targetWineLabelURL: targetWineLabelURL,
            contentText: contentText,
            tastingRating: tastingRating,
            createdAt: createdAt,
            cheersCount: cheersCount,
            commentCount: commentCount,
            hasCheered: hasCheered
        )
    }
}
