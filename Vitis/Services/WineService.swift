//
//  WineService.swift
//  Vitis
//
//  Upsert wine from Open Food Facts. Uses upsert_wine_from_off RPC.
//

import Foundation
import Supabase

enum WineService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    struct UpsertParams: Encodable, Sendable {
        let p_off_code: String
        let p_name: String
        let p_producer: String
        let p_region: String?
        let p_label_url: String?
        let p_category: String?

        enum CodingKeys: String, CodingKey {
            case p_off_code, p_name, p_producer, p_region, p_label_url, p_category
        }

        nonisolated func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_off_code, forKey: .p_off_code)
            try c.encode(p_name, forKey: .p_name)
            try c.encode(p_producer, forKey: .p_producer)
            try c.encodeIfPresent(p_region, forKey: .p_region)
            try c.encodeIfPresent(p_label_url, forKey: .p_label_url)
            try c.encodeIfPresent(p_category, forKey: .p_category)
        }
    }

    struct WineRow: Decodable {
        let id: UUID
        let name: String
        let producer: String
        let vintage: Int?
        let variety: String?
        let region: String?
        let label_image_url: String?
        let category: String?
    }

    /// Upsert wine from OFF product. Returns upserted Wine.
    static func upsertFromOFF(product: OFFProduct) async throws -> Wine {
        let params = UpsertParams(
            p_off_code: product.code,
            p_name: product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown",
            p_producer: product.brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown",
            p_region: product.countriesTags?.first
                .map { $0.replacingOccurrences(of: "en:", with: "").capitalized },
            p_label_url: product.imageUrl,
            p_category: product.mappedCategory
        )
        let rows: [WineRow] = try await supabase
            .rpc("upsert_wine_from_off", params: params)
            .execute()
            .value
        guard let r = rows.first else { throw NSError(domain: "WineService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upsert returned no row"]) }
        return Wine(
            id: r.id,
            name: r.name,
            producer: r.producer,
            vintage: r.vintage,
            variety: r.variety,
            region: r.region,
            labelImageURL: r.label_image_url,
            category: r.category
        )
    }
}
