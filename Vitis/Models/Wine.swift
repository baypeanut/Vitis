//
//  Wine.swift
//  Vitis
//
//  Domain model matching wines table: id, name, producer, vintage, variety, region.
//

import Foundation

struct Wine: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let producer: String
    let vintage: Int?
    let variety: String?
    let region: String?
    var labelImageURL: String?
    var category: String?

    init(
        id: UUID,
        name: String,
        producer: String,
        vintage: Int? = nil,
        variety: String? = nil,
        region: String? = nil,
        labelImageURL: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.producer = producer
        self.vintage = vintage
        self.variety = variety
        self.region = region
        self.labelImageURL = labelImageURL
        self.category = category
    }
}

// MARK: - Preview / Mock

#if DEBUG
extension Wine {
    static let preview = Wine(
        id: UUID(),
        name: "Côte Rôtie",
        producer: "Domaine Jean-Michel Gerin",
        vintage: 2019,
        variety: "Syrah",
        region: "Rhône Valley",
        labelImageURL: nil
    )

    static let previewB = Wine(
        id: UUID(),
        name: "Barolo",
        producer: "Giacomo Conterno",
        vintage: 2017,
        variety: "Nebbiolo",
        region: "Piedmont",
        labelImageURL: nil
    )
}
#endif
