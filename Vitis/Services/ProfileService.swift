//
//  ProfileService.swift
//  Vitis
//
//  Username availability, taste profile (grapes/regions/styles), streak placeholder.
//

import Foundation
import Supabase

struct TasteProfileItem: Identifiable, Sendable {
    let name: String
    let count: Int
    let averageRating: Double?
    /// Dominant wine category for color (e.g. "Red", "White"). Used for regions; grapes infer from name.
    let dominantWineCategory: String?
    var id: String { name }
}

enum ProfileService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Returns true if username is available (case-insensitive). Debounce in caller (e.g. 300ms).
    static func checkUsernameAvailable(_ username: String) async -> Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return false }
        do {
            let params: [String: String] = ["p_username": u]
            let available: Bool = try await supabase
                .rpc("check_username_available", params: params)
                .execute()
                .value
            return available
        } catch {
            #if DEBUG
            print("[ProfileService] checkUsernameAvailable failed: \(error)")
            #endif
            return false
        }
    }

    /// Taste profile from user's tastings: grapes (variety), regions, styles (category). Count = tastings, with average ratings.
    static func fetchTasteProfile(userId: UUID) async throws -> (grapes: [TasteProfileItem], regions: [TasteProfileItem], styles: [TasteProfileItem]) {
        struct Row: Decodable {
            let wine_id: UUID
            let rating: Double
            let wines: Wref?
            struct Wref: Decodable {
                let name: String?
                let variety: String?
                let region: String?
                let category: String?
            }
        }
        let rows: [Row] = try await supabase
            .from("tastings")
            .select("wine_id, rating, wines(name, variety, region, category)")
            .eq("user_id", value: userId)
            .execute()
            .value

        var grapeCounts: [String: Int] = [:]
        var grapeRatings: [String: [Double]] = [:]
        var regionCounts: [String: Int] = [:]
        var regionRatings: [String: [Double]] = [:]
        var regionCategories: [String: [String]] = [:]
        var styleCounts: [String: Int] = [:]
        var styleRatings: [String: [Double]] = [:]

        let knownGrapes = ["Shiraz", "Syrah", "Malbec", "Cabernet", "Merlot", "Pinot Noir", "Nebbiolo", "Sangiovese", "Chardonnay", "Sauvignon", "Riesling", "Pinot Grigio", "Prosecco", "Grenache", "Tempranillo", "Zinfandel", "Viognier", "Barbera", "Gamay"]
        
        for r in rows {
            guard let w = r.wines else { continue }
            
            var grape: String? = (w.variety?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            if grape == nil, let name = w.name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !name.isEmpty {
                let lower = name.lowercased()
                for g in knownGrapes {
                    if lower.contains(g.lowercased()) {
                        grape = g
                        break
                    }
                }
            }
            if let variety = grape {
                grapeCounts[variety, default: 0] += 1
                grapeRatings[variety, default: []].append(r.rating)
            }
            
            if let region = (w.region?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                let normRegion = Self.normalizeRegion(region)
                regionCounts[normRegion, default: 0] += 1
                regionRatings[normRegion, default: []].append(r.rating)
                if let cat = w.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                    regionCategories[normRegion, default: []].append(cat)
                }
            }
            
            if let style = (w.category?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                styleCounts[style, default: 0] += 1
                styleRatings[style, default: []].append(r.rating)
            }
        }

        let grapes = grapeCounts.map { (key, count) -> TasteProfileItem in
            let ratings = grapeRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: nil)
        }.sorted { $0.count > $1.count }
        
        let regions = regionCounts.map { (key, count) -> TasteProfileItem in
            let ratings = regionRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            let dominant = Self.dominantCategory(from: regionCategories[key] ?? [])
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: dominant)
        }.sorted { $0.count > $1.count }
        
        let styles = styleCounts.map { (key, count) -> TasteProfileItem in
            let ratings = styleRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: nil)
        }.sorted { $0.count > $1.count }
        
        return (grapes, regions, styles)
    }

    /// Compute taste profile from tastings (avoids duplicate DB fetch when tastings already loaded).
    static func computeTasteProfile(from tastings: [Tasting]) -> (grapes: [TasteProfileItem], regions: [TasteProfileItem], styles: [TasteProfileItem]) {
        var grapeCounts: [String: Int] = [:]
        var grapeRatings: [String: [Double]] = [:]
        var regionCounts: [String: Int] = [:]
        var regionRatings: [String: [Double]] = [:]
        var regionCategories: [String: [String]] = [:]
        var styleCounts: [String: Int] = [:]
        var styleRatings: [String: [Double]] = [:]

        let knownGrapes = ["Shiraz", "Syrah", "Malbec", "Cabernet", "Merlot", "Pinot Noir", "Nebbiolo", "Sangiovese", "Chardonnay", "Sauvignon", "Riesling", "Pinot Grigio", "Prosecco", "Grenache", "Tempranillo", "Zinfandel", "Viognier", "Barbera", "Gamay"]

        for t in tastings {
            let w = t.wine
            var grape: String? = (w.variety?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            if grape == nil {
                let name = w.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    let lower = name.lowercased()
                    for g in knownGrapes {
                        if lower.contains(g.lowercased()) {
                            grape = g
                            break
                        }
                    }
                }
            }
            if let variety = grape {
                grapeCounts[variety, default: 0] += 1
                grapeRatings[variety, default: []].append(t.rating)
            }
            if let region = (w.region?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                let normRegion = Self.normalizeRegion(region)
                regionCounts[normRegion, default: 0] += 1
                regionRatings[normRegion, default: []].append(t.rating)
                if let cat = w.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                    regionCategories[normRegion, default: []].append(cat)
                }
            }
            if let style = (w.category?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                styleCounts[style, default: 0] += 1
                styleRatings[style, default: []].append(t.rating)
            }
        }

        let grapes = grapeCounts.map { (key, count) -> TasteProfileItem in
            let ratings = grapeRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: nil)
        }.sorted { $0.count > $1.count }
        let regions = regionCounts.map { (key, count) -> TasteProfileItem in
            let ratings = regionRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            let dominant = Self.dominantCategory(from: regionCategories[key] ?? [])
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: dominant)
        }.sorted { $0.count > $1.count }
        let styles = styleCounts.map { (key, count) -> TasteProfileItem in
            let ratings = styleRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating, dominantWineCategory: nil)
        }.sorted { $0.count > $1.count }
        return (grapes, regions, styles)
    }

    /// Last activity date for user (max created_at in activity_feed). For "Streak: —" placeholder when nil.
    static func fetchLastActivityDate(userId: UUID) async -> Date? {
        struct Row: Decodable { let created_at: Date }
        let rows: [Row] = (try? await supabase
            .from("activity_feed")
            .select("created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute().value) ?? []
        return rows.first?.created_at
    }

    private static func normalizeRegion(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canonical = regionMatchKey(lower)
        let displayMap: [String: String] = [
            "united states": "United States", "united kingdom": "United Kingdom"
        ]
        return displayMap[canonical] ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Canonical key for region matching (USA/United States collapse).
    static func regionMatchKey(_ lowercased: String) -> String {
        let m: [String: String] = [
            "usa": "united states", "united states": "united states",
            "uk": "united kingdom", "united kingdom": "united kingdom",
        ]
        return m[lowercased] ?? lowercased
    }

    private static func dominantCategory(from categories: [String]) -> String? {
        guard !categories.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for c in categories {
            let n = c.trimmingCharacters(in: .whitespaces).lowercased()
            if !n.isEmpty { counts[n, default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Privacy

    /// Fetch privacy visibility settings for a user.
    static func fetchPrivacySettings(userId: UUID) async throws -> PrivacySettings {
        struct Row: Decodable {
            let cellar_visibility: String?
            let wishlist_visibility: String?
            let activity_visibility: String?
        }
        let rows: [Row] = try await supabase
            .from("profiles")
            .select("cellar_visibility, wishlist_visibility, activity_visibility")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let r = rows.first else { return .default }
        return PrivacySettings(
            cellarVisibility: PrivacyVisibility(rawValue: r.cellar_visibility ?? "everyone") ?? .everyone,
            wishlistVisibility: PrivacyVisibility(rawValue: r.wishlist_visibility ?? "everyone") ?? .everyone,
            activityVisibility: PrivacyVisibility(rawValue: r.activity_visibility ?? "everyone") ?? .everyone
        )
    }

    /// Update privacy visibility. Owner-only via RLS.
    static func updatePrivacySettings(
        userId: UUID,
        cellarVisibility: PrivacyVisibility? = nil,
        wishlistVisibility: PrivacyVisibility? = nil,
        activityVisibility: PrivacyVisibility? = nil
    ) async throws {
        var payload: [String: String] = [:]
        if let v = cellarVisibility { payload["cellar_visibility"] = v.rawValue }
        if let v = wishlistVisibility { payload["wishlist_visibility"] = v.rawValue }
        if let v = activityVisibility { payload["activity_visibility"] = v.rawValue }
        guard !payload.isEmpty else { return }
        try await supabase
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
        await AuditService.log(userId: userId, eventType: "privacy_setting_changed", metadata: payload)
    }

    /// True if viewer and owner follow each other.
    static func isMutualFriend(viewerId: UUID, ownerId: UUID) async -> Bool {
        guard viewerId != ownerId else { return true }
        do {
            let params: [String: String] = [
                "p_viewer_id": viewerId.uuidString,
                "p_owner_id": ownerId.uuidString
            ]
            let result: Bool = try await supabase
                .rpc("is_mutual_friend", params: params)
                .execute()
                .value
            return result
        } catch {
            #if DEBUG
            print("[ProfileService] isMutualFriend failed: \(error)")
            #endif
            return false
        }
    }
}
