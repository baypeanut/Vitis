//
//  CellarService.swift
//  Vitis
//
//  Fetch user's ranking list (My Ranking). Cellar Had | Wishlist (cellar_items).
//

import Foundation
import Supabase

enum CellarService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private struct FlatRow: Decodable {
        let wine_id: UUID
        let position: Int
        let elo_score: Double
        let wines: WineRef?
        struct WineRef: Decodable {
            let name: String
            let producer: String
            let vintage: Int?
            let region: String?
            let label_image_url: String?
        }
    }

    /// Fetch current user's ranked wines (rankings + wines). Returns [] when not logged in.
    static func fetchMyRanking(userId: UUID) async throws -> [RankingItem] {
        let flat: [FlatRow] = try await supabase
            .from("rankings")
            .select("wine_id, position, elo_score, wines(name, producer, vintage, region, label_image_url)")
            .eq("user_id", value: userId)
            .order("position", ascending: true)
            .execute()
            .value

        return flat.compactMap { row -> RankingItem? in
            guard let w = row.wines else { return nil }
            let wine = Wine(
                id: row.wine_id,
                name: w.name,
                producer: w.producer,
                vintage: w.vintage,
                variety: nil,
                region: w.region,
                labelImageURL: w.label_image_url
            )
            return RankingItem(wineId: row.wine_id, position: row.position, eloScore: row.elo_score, wine: wine)
        }
    }

    // MARK: - Cellar (Had | Wishlist)

    private struct CellarRow: Decodable {
        let id: UUID
        let user_id: UUID
        let wine_id: UUID
        let status: String
        let created_at: Date
        let consumed_at: Date?
        let wines: WineRef?
        struct WineRef: Decodable {
            let name: String
            let producer: String
            let vintage: Int?
            let region: String?
            let label_image_url: String?
        }
    }

    static func fetchCellar(userId: UUID, status: CellarItem.CellarStatus, limit: Int = 100, offset: Int = 0) async throws -> [CellarItem] {
        let raw: [CellarRow] = try await supabase
            .from("cellar_items")
            .select("id, user_id, wine_id, status, created_at, consumed_at, wines(name, producer, vintage, region, label_image_url)")
            .eq("user_id", value: userId)
            .eq("status", value: status.rawValue)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return raw.compactMap { row -> CellarItem? in
            guard let w = row.wines,
                  let st = CellarItem.CellarStatus(rawValue: row.status) else { return nil }
            let wine = Wine(
                id: row.wine_id,
                name: w.name,
                producer: w.producer,
                vintage: w.vintage,
                variety: nil,
                region: w.region,
                labelImageURL: w.label_image_url
            )
            return CellarItem(
                id: row.id,
                userId: row.user_id,
                wineId: row.wine_id,
                status: st,
                createdAt: row.created_at,
                consumedAt: row.consumed_at,
                wine: wine
            )
        }
    }

    static func addToCellar(userId: UUID, wineId: UUID, status: CellarItem.CellarStatus) async throws {
        struct Insert: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let status: String
            let consumed_at: String?
        }
        let consumed: String? = status == .had ? ISO8601DateFormatter().string(from: Date()) : nil
        let payload = Insert(user_id: userId, wine_id: wineId, status: status.rawValue, consumed_at: consumed)
        try await supabase.from("cellar_items").insert(payload).execute()
    }

    static func moveItem(id: UUID, toStatus: CellarItem.CellarStatus) async throws {
        struct Row: Decodable { let user_id: UUID; let wine_id: UUID }
        let rows: [Row] = try await supabase.from("cellar_items")
            .select("user_id, wine_id")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        guard let r = rows.first else { return }
        try await supabase.from("cellar_items").delete().eq("id", value: id).execute()
        try await addToCellar(userId: r.user_id, wineId: r.wine_id, status: toStatus)
    }

    static func removeItem(id: UUID) async throws {
        try await supabase.from("cellar_items").delete().eq("id", value: id).execute()
    }
}
