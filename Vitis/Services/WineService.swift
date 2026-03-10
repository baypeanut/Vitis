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

    /// Escape ILIKE special characters (%, _, \) so the query is treated as literal.
    private static func escapeIlikePattern(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Full-text search across the wines catalog (name + producer). Used to surface X-Wines imports.
    static func searchCatalog(query: String, limit: Int = 30) async throws -> [Wine] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let pattern = "%\(escapeIlikePattern(q))%"
        let rows: [WineRow] = try await supabase
            .from("wines")
            .select("id, name, producer, vintage, variety, region, label_image_url, category")
            .or("name.ilike.\(pattern),producer.ilike.\(pattern)")
            .limit(limit)
            .execute()
            .value
        return rows.map { r in
            Wine(id: r.id, name: r.name, producer: r.producer, vintage: r.vintage,
                 variety: r.variety, region: r.region, labelImageURL: r.label_image_url, category: r.category)
        }
    }

    // MARK: - Label Scan Upsert

    struct ScanUpsertParams: Encodable, Sendable {
        let p_name: String
        let p_producer: String
        let p_vintage: Int?
        let p_variety: String?
        let p_region: String?
        let p_category: String?

        nonisolated func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_name, forKey: .p_name)
            try c.encode(p_producer, forKey: .p_producer)
            try c.encodeIfPresent(p_vintage, forKey: .p_vintage)
            try c.encodeIfPresent(p_variety, forKey: .p_variety)
            try c.encodeIfPresent(p_region, forKey: .p_region)
            try c.encodeIfPresent(p_category, forKey: .p_category)
        }

        enum CodingKeys: String, CodingKey {
            case p_name, p_producer, p_vintage, p_variety, p_region, p_category
        }
    }

    /// Upsert wine from label scan result. Matches on name+producer (case-insensitive).
    /// Enriches existing rows with any new fields from the scan. Creates new wine if no match.
    static func upsertFromScan(result: LabelScanResult) async throws -> Wine {
        guard let name = result.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let producer = result.producer?.trimmingCharacters(in: .whitespacesAndNewlines), !producer.isEmpty else {
            throw NSError(domain: "WineService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Wine name and producer are required from the label scan."])
        }
        let params = ScanUpsertParams(
            p_name: name,
            p_producer: producer,
            p_vintage: result.vintage,
            p_variety: result.variety?.trimmingCharacters(in: .whitespacesAndNewlines),
            p_region: result.region?.trimmingCharacters(in: .whitespacesAndNewlines),
            p_category: result.category?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let rows: [WineRow] = try await supabase
            .rpc("upsert_wine_from_scan", params: params)
            .execute()
            .value
        guard let r = rows.first else {
            throw NSError(domain: "WineService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Upsert returned no row"])
        }
        return Wine(id: r.id, name: r.name, producer: r.producer, vintage: r.vintage,
                    variety: r.variety, region: r.region, labelImageURL: r.label_image_url, category: r.category)
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
    
    /// Fetch all tastings for a specific wine with user profile info.
    /// Excludes the specified userId (typically the current user).
    static func fetchTastingsForWine(wineId: UUID, excludeUserId: UUID? = nil, limit: Int = 20) async throws -> [TastingWithProfile] {
        struct TastingRow: Decodable {
            let id: UUID
            let user_id: UUID
            let rating: Double
            let note_tags: [String]?
            let comment: String?
            let created_at: Date
        }
        
        struct ProfileRow: Decodable {
            let id: UUID
            let username: String?
            let full_name: String?
            let avatar_url: String?
        }
        
        // Fetch tastings
        var query = supabase
            .from("tastings")
            .select("id, user_id, rating, note_tags, comment, created_at")
            .eq("wine_id", value: wineId)
        
        if let userId = excludeUserId {
            query = query.neq("user_id", value: userId)
        }
        
        let tastingRows: [TastingRow] = try await query
            .order("rating", ascending: false)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        #if DEBUG
        print("[WineService] Fetched \(tastingRows.count) tasting rows for wine \(wineId)")
        #endif
        
        guard !tastingRows.isEmpty else { return [] }
        
        // Fetch profiles for all user_ids
        let userIds = Array(Set(tastingRows.map { $0.user_id }))
        let profileRows: [ProfileRow] = try await supabase
            .from("profiles")
            .select("id, username, full_name, avatar_url")
            .in("id", values: userIds)
            .execute()
            .value
        
        #if DEBUG
        print("[WineService] Fetched \(profileRows.count) profile rows")
        #endif
        
        // Create a map of user_id -> profile
        let profileMap = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })
        
        // Join tastings with profiles
        return tastingRows.compactMap { row -> TastingWithProfile? in
            guard let profile = profileMap[row.user_id] else {
                #if DEBUG
                print("[WineService] No profile found for user_id=\(row.user_id.uuidString)")
                #endif
                return nil
            }
            return TastingWithProfile(
                id: row.id,
                userId: row.user_id,
                username: profile.username ?? "Unknown",
                fullName: profile.full_name,
                avatarURL: profile.avatar_url,
                rating: row.rating,
                noteTags: row.note_tags,
                comment: row.comment,
                createdAt: row.created_at
            )
        }
    }
}
