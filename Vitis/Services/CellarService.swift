//
//  CellarService.swift
//  Vitis
//
//  Cellar Had | Wishlist (cellar_items).
//

import Foundation
import Supabase

enum CellarService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

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

    // MARK: - Wishlist (B1: cellar_items status = 'wishlist' only)

    /// Fetch wishlist items for user. Throws on failure.
    static func fetchWishlist(userId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [CellarItem] {
        try await fetchCellar(userId: userId, status: .wishlist, limit: limit, offset: offset)
    }

    /// Fetch wine IDs in wishlist for fast UI checks. Throws on failure.
    static func fetchWishlistWineIds(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let wine_id: UUID }
        let rows: [Row] = try await supabase
            .from("cellar_items")
            .select("wine_id")
            .eq("user_id", value: userId)
            .eq("status", value: "wishlist")
            .execute()
            .value
        return Set(rows.map(\.wine_id))
    }

    /// Add wine to wishlist. sourceUserId = feed poster when adding from Feed (for trust hints).
    static func addToWishlist(userId: UUID, wineId: UUID, sourceUserId: UUID? = nil) async throws {
        struct Insert: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let status: String
            let source_user_id: UUID?
        }
        let payload = Insert(user_id: userId, wine_id: wineId, status: "wishlist", source_user_id: sourceUserId)
        do {
            try await supabase.from("cellar_items").insert(payload).execute()
        } catch {
            let msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? ""
            if msg.contains("23505") || msg.lowercased().contains("unique") || msg.lowercased().contains("duplicate") { return }
            if sourceUserId != nil && (msg.contains("column") || msg.contains("does not exist")) {
                let fallback = Insert(user_id: userId, wine_id: wineId, status: "wishlist", source_user_id: nil)
                try await supabase.from("cellar_items").insert(fallback).execute()
                return
            }
            throw error
        }
    }

    /// Source user IDs of last K wishlist additions with source (for trust hint). Nulls omitted.
    static func fetchWishlistSourceUserIdsInLastK(userId: UUID, k: Int = 20) async throws -> [UUID] {
        struct Row: Decodable { let source_user_id: UUID? }
        let rows: [Row] = try await supabase
            .from("cellar_items")
            .select("source_user_id")
            .eq("user_id", value: userId)
            .eq("status", value: "wishlist")
            .order("created_at", ascending: false)
            .limit(k * 3)
            .execute()
            .value
        return Array(rows.compactMap(\.source_user_id).prefix(k))
    }

    /// Remove wine from wishlist. Throws on failure.
    static func removeFromWishlist(userId: UUID, wineId: UUID) async throws {
        try await supabase.from("cellar_items")
            .delete()
            .eq("user_id", value: userId)
            .eq("wine_id", value: wineId)
            .eq("status", value: "wishlist")
            .execute()
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

    /// Fetch recent cellar items (both had and wishlist) for a user, sorted by date
    static func fetchRecentCellarItems(userId: UUID, limit: Int = 30) async throws -> [CellarItem] {
        let raw: [CellarRow] = try await supabase
            .from("cellar_items")
            .select("id, user_id, wine_id, status, created_at, consumed_at, wines(name, producer, vintage, region, label_image_url)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
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
}
