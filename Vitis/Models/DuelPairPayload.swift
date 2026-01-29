//
//  DuelPairPayload.swift
//  Vitis
//
//  Decodes duel_next_pair RPC response: wine_a_*, wine_b_*.
//

import Foundation

struct DuelPairPayload: Codable, Sendable {
    let wineAId: UUID
    let wineAName: String
    let wineAProducer: String
    let wineAVintage: Int?
    let wineARegion: String?
    let wineALabelUrl: String?
    let wineAIsNew: Bool
    let wineBId: UUID
    let wineBName: String
    let wineBProducer: String
    let wineBVintage: Int?
    let wineBRegion: String?
    let wineBLabelUrl: String?

    enum CodingKeys: String, CodingKey {
        case wineAId = "wine_a_id"
        case wineAName = "wine_a_name"
        case wineAProducer = "wine_a_producer"
        case wineAVintage = "wine_a_vintage"
        case wineARegion = "wine_a_region"
        case wineALabelUrl = "wine_a_label_url"
        case wineAIsNew = "wine_a_is_new"
        case wineBId = "wine_b_id"
        case wineBName = "wine_b_name"
        case wineBProducer = "wine_b_producer"
        case wineBVintage = "wine_b_vintage"
        case wineBRegion = "wine_b_region"
        case wineBLabelUrl = "wine_b_label_url"
    }

    var wineA: Wine {
        Wine(
            id: wineAId,
            name: wineAName,
            producer: wineAProducer,
            vintage: wineAVintage,
            variety: nil,
            region: wineARegion,
            labelImageURL: wineALabelUrl
        )
    }

    var wineB: Wine {
        Wine(
            id: wineBId,
            name: wineBName,
            producer: wineBProducer,
            vintage: wineBVintage,
            variety: nil,
            region: wineBRegion,
            labelImageURL: wineBLabelUrl
        )
    }
}
