//
//  FeedItem.swift
//  Vitis
//
//  Display model for feed: statement, user, wines, cheers/comments.
//

import Foundation

struct FeedItem: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var username: String
    var avatarURL: String?
    let activityType: ActivityType
    let wineName: String
    let wineProducer: String
    let wineVintage: Int?
    let wineLabelURL: String?
    let targetWineName: String?
    let targetWineProducer: String?
    let targetWineVintage: Int?
    let targetWineLabelURL: String?
    let contentText: String?
    let createdAt: Date
    var cheersCount: Int
    var commentCount: Int
    var hasCheered: Bool

    init(
        id: UUID,
        userId: UUID,
        username: String,
        avatarURL: String?,
        activityType: ActivityType,
        wineName: String,
        wineProducer: String,
        wineVintage: Int?,
        wineLabelURL: String?,
        targetWineName: String? = nil,
        targetWineProducer: String? = nil,
        targetWineVintage: Int? = nil,
        targetWineLabelURL: String? = nil,
        contentText: String? = nil,
        createdAt: Date,
        cheersCount: Int = 0,
        commentCount: Int = 0,
        hasCheered: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.avatarURL = avatarURL
        self.activityType = activityType
        self.wineName = wineName
        self.wineProducer = wineProducer
        self.wineVintage = wineVintage
        self.wineLabelURL = wineLabelURL
        self.targetWineName = targetWineName
        self.targetWineProducer = targetWineProducer
        self.targetWineVintage = targetWineVintage
        self.targetWineLabelURL = targetWineLabelURL
        self.contentText = contentText
        self.createdAt = createdAt
        self.cheersCount = cheersCount
        self.commentCount = commentCount
        self.hasCheered = hasCheered
    }
}

#if DEBUG
extension FeedItem {
    static let preview = FeedItem(
        id: UUID(),
        userId: UUID(),
        username: "Ahmet",
        avatarURL: nil,
        activityType: .rankUpdate,
        wineName: "Sassicaia",
        wineProducer: "Tenuta San Guido",
        wineVintage: 2019,
        wineLabelURL: nil,
        targetWineName: nil,
        targetWineProducer: nil,
        targetWineVintage: nil,
        targetWineLabelURL: nil,
        contentText: "Tuscany list",
        createdAt: Date(),
        cheersCount: 3,
        commentCount: 1,
        hasCheered: false
    )

    static let previewDuel = FeedItem(
        id: UUID(),
        userId: UUID(),
        username: "Emma",
        avatarURL: nil,
        activityType: .duelWin,
        wineName: "Côte Rôtie",
        wineProducer: "Domaine Jean-Michel Gerin",
        wineVintage: 2019,
        wineLabelURL: nil,
        targetWineName: "Barolo",
        targetWineProducer: "Giacomo Conterno",
        targetWineVintage: 2017,
        targetWineLabelURL: nil,
        contentText: nil,
        createdAt: Date().addingTimeInterval(-3600),
        cheersCount: 0,
        commentCount: 0,
        hasCheered: true
    )
}
#endif

extension FeedItem {
    /// Statement parts for display (before, name, after). Name is highlighted.
    func statementParts() -> (before: String, name: String, after: String) {
        let wine = wineVintage.map { "\($0) \(wineName)" } ?? wineName
        let list = contentText ?? "their list"
        let s: String
        switch activityType {
        case .rankUpdate: s = "\(username) ranked \(wine) to #1 in \(list)."
        case .newEntry: s = "\(username) discovered \(wine)."
        case .duelWin:
            let other = targetWineVintage.map { "\($0) \(targetWineName ?? "")" }
                ?? targetWineName ?? "another wine"
            s = "\(username) ranked \(wine) higher than \(other)."
        }
        guard let r = s.range(of: username) else { return (s, "", "") }
        return (String(s[..<r.lowerBound]), username, String(s[r.upperBound...]))
    }

    /// Build from API response. Counts default to 0; service can overlay.
    static func from(entry: ActivityFeedEntry, cheersCount: Int = 0, commentCount: Int = 0, hasCheered: Bool = false) -> FeedItem? {
        guard let w = entry.wine else { return nil }
        let tw = entry.targetWine
        let u = entry.user
        return FeedItem(
            id: entry.id,
            userId: entry.userId,
            username: u?.username ?? "Unknown",
            avatarURL: u?.avatarUrl,
            activityType: entry.activityType,
            wineName: w.name,
            wineProducer: w.producer,
            wineVintage: w.vintage,
            wineLabelURL: w.labelImageUrl,
            targetWineName: tw?.name,
            targetWineProducer: tw?.producer,
            targetWineVintage: tw?.vintage,
            targetWineLabelURL: tw?.labelImageUrl,
            contentText: entry.contentText,
            createdAt: entry.createdAt,
            cheersCount: cheersCount,
            commentCount: commentCount,
            hasCheered: hasCheered
        )
    }
}
