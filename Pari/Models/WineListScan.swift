//
//  WineListScan.swift
//  Pari
//
//  A photographed restaurant wine list, from raw extraction through to a ranked
//  set of suggestions.
//
//  The type deliberately keeps unmatched lines. A wine list with forty entries and
//  thirty-two catalog matches should show all forty, with eight marked as unknown.
//  Hiding the misses would make the feature look better and be worse: the person is
//  holding the list and can see what is on it.
//

import Foundation

/// One line as read off the list, before any catalog lookup.
struct WineListItem: Identifiable, Sendable, Codable {
    let id: UUID
    let name: String
    let producer: String?
    let vintage: Int?
    let region: String?
    /// Printed exactly as it appears, currency and all. Never converted.
    let price: String?
    let byGlass: Bool

    init(
        id: UUID = UUID(),
        name: String,
        producer: String? = nil,
        vintage: Int? = nil,
        region: String? = nil,
        price: String? = nil,
        byGlass: Bool = false
    ) {
        self.id = id
        self.name = name
        self.producer = producer
        self.vintage = vintage
        self.region = region
        self.price = price
        self.byGlass = byGlass
    }
}

/// A list line after catalog matching, with whatever we could work out about it.
struct MatchedWineListItem: Identifiable, Sendable {
    let listItem: WineListItem
    /// Nil when nothing cleared the confidence floor. This is a normal outcome.
    let wine: Wine?
    let matchConfidence: Double?
    /// The matched wine's style vector, kept so the list can be re-ranked offline.
    let embedding: [Double]?
    /// Cosine affinity to the viewer's palate, computed on device. Nil without a
    /// match or without a taste profile.
    var affinity: Double?

    var id: UUID { listItem.id }

    var isMatched: Bool { wine != nil }

    /// What to show as the wine's name: the catalog's tidy version when we matched,
    /// otherwise whatever was printed on the list.
    var displayName: String { wine?.name ?? listItem.name }
    var displayProducer: String? { wine?.producer ?? listItem.producer }
}

/// The result of reading one list.
struct WineListScanResult: Sendable {
    let isWineList: Bool
    let items: [WineListItem]

    static let notAList = WineListScanResult(isWineList: false, items: [])
}
