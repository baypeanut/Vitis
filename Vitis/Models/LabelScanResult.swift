//
//  LabelScanResult.swift
//  Vitis
//
//  Structured response from Claude Vision label analysis.
//  is_wine == false means the image is not a wine label (beer, spirits, random object).
//

import Foundation

struct LabelScanResult: Decodable, Sendable {
    let isWine: Bool
    let name: String?
    let producer: String?
    let vintage: Int?
    let variety: String?
    let region: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case isWine = "is_wine"
        case name, producer, vintage, variety, region, category
    }
}
