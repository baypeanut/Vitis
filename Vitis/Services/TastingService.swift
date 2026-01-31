//
//  TastingService.swift
//  Vitis
//
//  Create tastings (wine logs with rating + notes), fetch user's tasting history.
//

import Foundation
import Supabase

enum TastingService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private struct TastingRow: Decodable {
        let id: UUID
        let user_id: UUID
        let wine_id: UUID
        let rating: Double
        let note_tags: [String]?
        let created_at: Date
        let source: String?
        let wines: WineRef?
        struct WineRef: Decodable {
            let name: String
            let producer: String
            let vintage: Int?
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
        }
    }

    /// Create a tasting and insert activity_feed row for "had_wine".
    static func createTasting(
        userId: UUID,
        wineId: UUID,
        rating: Double,
        noteTags: [String]? = nil,
        source: String? = nil
    ) async throws -> Tasting {
        // Insert tasting
        struct Insert: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let rating: Double
            let note_tags: [String]?
            let source: String?
        }
        let payload = Insert(
            user_id: userId,
            wine_id: wineId,
            rating: rating,
            note_tags: noteTags?.isEmpty == false ? noteTags : nil,
            source: source
        )
        let inserted: [TastingRow] = try await supabase
            .from("tastings")
            .insert(payload)
            .select("id, user_id, wine_id, rating, note_tags, created_at, source, wines(name, producer, vintage, variety, region, label_image_url, category)")
            .execute()
            .value

        guard let row = inserted.first, let w = row.wines else {
            throw NSError(domain: "TastingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tasting insert returned no row"])
        }

        let wine = Wine(
            id: row.wine_id,
            name: w.name,
            producer: w.producer,
            vintage: w.vintage,
            variety: w.variety,
            region: w.region,
            labelImageURL: w.label_image_url,
            category: w.category
        )

        // Insert activity_feed row for "had_wine"
        struct ActivityInsert: Encodable {
            let user_id: UUID
            let activity_type: String
            let wine_id: UUID
            let content_text: String?
        }
        let activityPayload = ActivityInsert(
            user_id: userId,
            activity_type: "had_wine",
            wine_id: wineId,
            content_text: noteTags?.isEmpty == false ? noteTags!.joined(separator: ", ") : nil
        )
        try await supabase
            .from("activity_feed")
            .insert(activityPayload)
            .execute()

        return Tasting(
            id: row.id,
            userId: row.user_id,
            wineId: row.wine_id,
            rating: row.rating,
            noteTags: row.note_tags,
            createdAt: row.created_at,
            source: row.source,
            wine: wine
        )
    }

    /// Count of user's tastings (cellar / rated wines) for profile stats.
    static func fetchTastingsCount(userId: UUID) async -> Int {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await supabase
            .from("tastings")
            .select("id")
            .eq("user_id", value: userId)
            .execute().value) ?? []
        return rows.count
    }

    /// Fetch user's tasting history (most recent first).
    static func fetchTastings(userId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [Tasting] {
        let raw: [TastingRow] = try await supabase
            .from("tastings")
            .select("id, user_id, wine_id, rating, note_tags, created_at, source, wines(name, producer, vintage, variety, region, label_image_url, category)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return raw.compactMap { row -> Tasting? in
            guard let w = row.wines else { return nil }
            let wine = Wine(
                id: row.wine_id,
                name: w.name,
                producer: w.producer,
                vintage: w.vintage,
                variety: w.variety,
                region: w.region,
                labelImageURL: w.label_image_url,
                category: w.category
            )
            return Tasting(
                id: row.id,
                userId: row.user_id,
                wineId: row.wine_id,
                rating: row.rating,
                noteTags: row.note_tags,
                createdAt: row.created_at,
                source: row.source,
                wine: wine
            )
        }
    }

    /// Delete a tasting and its associated activity_feed row.
    static func deleteTasting(id: UUID) async throws {
        // First, fetch the tasting to get user_id, wine_id, and created_at
        struct TastingInfo: Decodable {
            let user_id: UUID
            let wine_id: UUID
            let created_at: Date
        }
        let tastingInfo: [TastingInfo] = try await supabase
            .from("tastings")
            .select("user_id, wine_id, created_at")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        
        guard let info = tastingInfo.first else {
            throw NSError(domain: "TastingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tasting not found"])
        }
        
        // Delete the tasting
        try await supabase.from("tastings").delete().eq("id", value: id).execute()
        
        // Delete the associated activity_feed row (matching user_id, wine_id, activity_type='had_wine', and created_at within 1 second)
        // We use a time window because created_at might differ by milliseconds
        let oneSecondAgo = info.created_at.addingTimeInterval(-1)
        let oneSecondLater = info.created_at.addingTimeInterval(1)
        try await supabase
            .from("activity_feed")
            .delete()
            .eq("user_id", value: info.user_id)
            .eq("wine_id", value: info.wine_id)
            .eq("activity_type", value: "had_wine")
            .gte("created_at", value: ISO8601DateFormatter().string(from: oneSecondAgo))
            .lte("created_at", value: ISO8601DateFormatter().string(from: oneSecondLater))
            .execute()
    }
}
