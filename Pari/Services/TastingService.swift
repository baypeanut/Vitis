//
//  TastingService.swift
//  Pari
//
//  Create tastings (wine logs with rating + notes), fetch user's tasting history.
//

import Foundation
import Supabase

enum TastingService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// `vintage` here is the tasting's own vintage; `wines(vintage)` is the catalog row's.
    private static let selectColumns = "id, user_id, wine_id, rating, note_tags, comment, created_at, source, vintage, acidity, tannin, body, sweetness, aroma_intensity, finish, wines(name, producer, vintage, variety, region, label_image_url, category)"

    private struct TastingRow: Decodable {
        let id: UUID
        let user_id: UUID
        let wine_id: UUID
        let rating: Double
        let note_tags: [String]?
        let comment: String?
        let created_at: Date
        let source: String?
        let vintage: Int?
        let acidity: Int?
        let tannin: Int?
        let body: Int?
        let sweetness: Int?
        let aroma_intensity: Int?
        let finish: Int?
        let wines: WineRef?

        var structure: PalateStructure {
            PalateStructure(
                acidity: acidity, tannin: tannin, body: body,
                sweetness: sweetness, aromaIntensity: aroma_intensity, finish: finish
            )
        }
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
        comment: String? = nil,
        source: String? = nil,
        visibility: TastingVisibility = .everyone,
        vintage: Int? = nil,
        structure: PalateStructure = .empty,
        momentImageURL: String? = nil
    ) async throws -> Tasting {
        // Insert tasting
        struct Insert: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let rating: Double
            let note_tags: [String]?
            let comment: String?
            let source: String?
            let visibility: String?
            let vintage: Int?
            let acidity: Int?
            let tannin: Int?
            let body: Int?
            let sweetness: Int?
            let aroma_intensity: Int?
            let finish: Int?
            let moment_image_url: String?
        }
        let payload = Insert(
            user_id: userId,
            wine_id: wineId,
            rating: rating,
            note_tags: noteTags?.isEmpty == false ? noteTags : nil,
            comment: comment?.isEmpty == false ? comment : nil,
            source: source,
            visibility: visibility.rawValue,
            vintage: vintage,
            acidity: structure.acidity,
            tannin: structure.tannin,
            body: structure.body,
            sweetness: structure.sweetness,
            aroma_intensity: structure.aromaIntensity,
            finish: structure.finish,
            moment_image_url: momentImageURL
        )
        let inserted: [TastingRow] = try await supabase
            .from("tastings")
            .insert(payload)
            .select(selectColumns)
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

        // Insert activity_feed row for "had_wine" with tasting_id for deterministic join
        struct ActivityInsert: Encodable {
            let user_id: UUID
            let activity_type: String
            let wine_id: UUID
            let content_text: String?
            let tasting_id: UUID?
        }
        let activityPayload = ActivityInsert(
            user_id: userId,
            activity_type: "had_wine",
            wine_id: wineId,
            content_text: noteTags?.isEmpty == false ? noteTags!.joined(separator: ", ") : nil,
            tasting_id: row.id
        )
        try await supabase
            .from("activity_feed")
            .insert(activityPayload)
            .execute()

        NotificationCenter.default.post(name: .pariTastingCreated, object: nil)
        await ProfileStore.shared.incrementTastingCount()
        // The taste vector just moved, so anything ranked against the cached copy is
        // now scoring against a palate one wine out of date.
        await TasteVectorCache.shared.invalidate()

        // Remove from wishlist if present (user has now tried this wine)
        try? await CellarService.removeFromWishlist(wineId: wineId)

        return Tasting(
            id: row.id,
            userId: row.user_id,
            wineId: row.wine_id,
            rating: row.rating,
            noteTags: row.note_tags,
            comment: row.comment,
            createdAt: row.created_at,
            source: row.source,
            visibility: visibility,
            vintage: row.vintage,
            structure: row.structure,
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
            .select(selectColumns)
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
                comment: row.comment,
                createdAt: row.created_at,
                source: row.source,
                vintage: row.vintage,
                structure: row.structure,
                wine: wine
            )
        }
    }

    /// Fetch like (cheers) counts for a set of tastings keyed by tasting_id.
    static func fetchLikeCountsForTastings(tastingIds: [UUID]) async -> [UUID: Int] {
        guard !tastingIds.isEmpty else { return [:] }
        struct ActivityRow: Decodable {
            let id: UUID
            let tasting_id: UUID?
        }
        let activities: [ActivityRow] = (try? await supabase
            .from("activity_feed")
            .select("id, tasting_id")
            .in("tasting_id", values: tastingIds)
            .execute()
            .value) ?? []

        var activityByTasting: [UUID: UUID] = [:]
        for activity in activities {
            if let tastingId = activity.tasting_id, activityByTasting[tastingId] == nil {
                activityByTasting[tastingId] = activity.id
            }
        }

        let activityIds = Array(Set(activityByTasting.values))
        guard !activityIds.isEmpty else { return [:] }

        struct LikeRow: Decodable { let activity_id: UUID }
        let likes: [LikeRow] = (try? await supabase
            .from("likes")
            .select("activity_id")
            .in("activity_id", values: activityIds)
            .execute()
            .value) ?? []

        var countsByActivity: [UUID: Int] = [:]
        for like in likes {
            countsByActivity[like.activity_id, default: 0] += 1
        }

        var countsByTasting: [UUID: Int] = [:]
        for (tastingId, activityId) in activityByTasting {
            countsByTasting[tastingId] = countsByActivity[activityId, default: 0]
        }
        return countsByTasting
    }

    /// Update an existing tasting.
    static func updateTasting(
        id: UUID,
        rating: Double,
        noteTags: [String]? = nil,
        comment: String? = nil,
        vintage: Int? = nil
    ) async throws -> Tasting {
        struct Update: Encodable {
            let rating: Double
            let note_tags: [String]?
            let comment: String?
            let vintage: Int?
        }
        let payload = Update(
            rating: rating,
            note_tags: noteTags?.isEmpty == false ? noteTags : nil,
            comment: comment?.isEmpty == false ? comment : nil,
            vintage: vintage
        )
        let updated: [TastingRow] = try await supabase
            .from("tastings")
            .update(payload)
            .eq("id", value: id)
            .select(selectColumns)
            .execute()
            .value
        
        guard let row = updated.first, let w = row.wines else {
            throw NSError(domain: "TastingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tasting update returned no row"])
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
        
        // Update the associated activity_feed row's content_text
        try await supabase
            .from("activity_feed")
            .update(["content_text": noteTags?.isEmpty == false ? noteTags!.joined(separator: ", ") : nil])
            .eq("tasting_id", value: id)
            .execute()
        
        return Tasting(
            id: row.id,
            userId: row.user_id,
            wineId: row.wine_id,
            rating: row.rating,
            noteTags: row.note_tags,
            comment: row.comment,
            createdAt: row.created_at,
            source: row.source,
            vintage: row.vintage,
            structure: row.structure,
            wine: wine
        )
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
    
    /// Fetch wine IDs the user has tasted for fast UI checks.
    static func fetchTastedWineIds(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let wine_id: UUID }
        let rows: [Row] = try await supabase
            .from("tastings")
            .select("wine_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows.map(\.wine_id))
    }
    
    /// Check if user has tasted a specific wine.
    static func hasTasted(userId: UUID, wineId: UUID) async -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await supabase
            .from("tastings")
            .select("id")
            .eq("user_id", value: userId)
            .eq("wine_id", value: wineId)
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }
    
    /// Fetch a specific user's tasting for a wine (if exists).
    static func fetchUserTastingForWine(userId: UUID, wineId: UUID) async throws -> Tasting? {
        let raw: [TastingRow] = try await supabase
            .from("tastings")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .eq("wine_id", value: wineId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        guard let row = raw.first, let w = row.wines else { return nil }
        
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
            comment: row.comment,
            createdAt: row.created_at,
            source: row.source,
            vintage: row.vintage,
            structure: row.structure,
            wine: wine
        )
    }
}
