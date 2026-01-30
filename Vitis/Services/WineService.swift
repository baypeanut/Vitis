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

    /// Extract region/country from OFF product. Tries countriesTags first, then other fields.
    private static func extractRegion(from product: OFFProduct) -> String? {
        // Try countriesTags first (most reliable)
        if let countries = product.countriesTags, !countries.isEmpty {
            let first = countries[0]
            // Remove "en:" prefix if present
            let cleaned = first.replacingOccurrences(of: "en:", with: "")
                .replacingOccurrences(of: "fr:", with: "")
                .replacingOccurrences(of: "de:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                // Capitalize properly (e.g., "italy" -> "Italy", "united states" -> "United States")
                let words = cleaned.split(separator: " ").map { $0.capitalized }
                return words.joined(separator: " ")
            }
        }
        return nil
    }

    /// Fetch all wines from database, ordered by name.
    static func fetchAllWines(limit: Int = 100) async throws -> [Wine] {
        let rows: [WineRow] = try await supabase
            .from("wines")
            .select("id, name, producer, vintage, variety, region, label_image_url, category")
            .order("name", ascending: true)
            .limit(limit)
            .execute()
            .value
        
        return rows.map { r in
            Wine(
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

    /// Upsert wine from OFF product. Returns upserted Wine.
    static func upsertFromOFF(product: OFFProduct) async throws -> Wine {
        let params = UpsertParams(
            p_off_code: product.code,
            p_name: product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown",
            p_producer: product.brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown",
            p_region: extractRegion(from: product),
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
