//
//  OFFProduct.swift
//  Vitis
//
//  Open Food Facts API response. Map to Wine: brands→producer, product_name→name, image_url→label_image_url.
//

import Foundation

struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]?
}

struct OFFProduct: Decodable, Identifiable {
    let code: String
    let productName: String?
    let brands: String?
    let imageUrl: String?
    let countriesTags: [String]?
    let categoriesTags: [String]?
    let pnnsGroups2: String?

    var id: String { code }

    /// Yerel katalog için (anında arama). OFF API çağrılmadan üretilir.
    init(code: String, productName: String?, brands: String?, imageUrl: String? = nil, countriesTags: [String]? = nil, categoriesTags: [String]? = nil, pnnsGroups2: String? = nil) {
        self.code = code
        self.productName = productName
        self.brands = brands
        self.imageUrl = imageUrl
        self.countriesTags = countriesTags
        self.categoriesTags = categoriesTags
        self.pnnsGroups2 = pnnsGroups2
    }

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case imageUrl = "image_url"
        case countriesTags = "countries_tags"
        case categoriesTags = "categories_tags"
        case pnnsGroups2 = "pnns_groups_2"
    }

    /// Map OFF categories_tags / pnns_groups_2 to Red, White, Sparkling, Rose.
    var mappedCategory: String? {
        let combined = (categoriesTags ?? []).map { $0.lowercased() }.joined(separator: " ")
            + " " + (pnnsGroups2 ?? "").lowercased()
        if combined.contains("sparkling") { return "Sparkling" }
        if combined.contains("red") || combined.contains("rouge") { return "Red" }
        if combined.contains("white") || combined.contains("blanc") { return "White" }
        if combined.contains("rose") || combined.contains("rosé") { return "Rose" }
        return nil
    }

    /// Map to Wine. Uses OFF code for deterministic id when upserting. Region from first country tag (e.g. "en:italy" → "Italy").
    func toWine(id: UUID) -> Wine {
        let region = countriesTags?.first
            .map { $0.replacingOccurrences(of: "en:", with: "").capitalized } ?? nil
        return Wine(
            id: id,
            name: productName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (productName ?? "Unknown")
                : "Unknown",
            producer: brands?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (brands ?? "Unknown")
                : "Unknown",
            vintage: nil,
            variety: nil,
            region: region,
            labelImageURL: imageUrl
        )
    }
}
