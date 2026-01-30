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
                let variety: String?
                let region: String?
                let category: String?
            }
        }
        let rows: [Row] = try await supabase
            .from("tastings")
            .select("wine_id, rating, wines(variety, region, category)")
            .eq("user_id", value: userId)
            .execute()
            .value

        var grapeCounts: [String: Int] = [:]
        var grapeRatings: [String: [Double]] = [:]
        var regionCounts: [String: Int] = [:]
        var regionRatings: [String: [Double]] = [:]
        var styleCounts: [String: Int] = [:]
        var styleRatings: [String: [Double]] = [:]

        for r in rows {
            guard let w = r.wines else { continue }
            
            if let variety = (w.variety?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                grapeCounts[variety, default: 0] += 1
                grapeRatings[variety, default: []].append(r.rating)
            }
            
            if let region = (w.region?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                regionCounts[region, default: 0] += 1
                regionRatings[region, default: []].append(r.rating)
            }
            
            if let style = (w.category?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                styleCounts[style, default: 0] += 1
                styleRatings[style, default: []].append(r.rating)
            }
        }

        let grapes = grapeCounts.map { key, count -> TasteProfileItem in
            let ratings = grapeRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating)
        }.sorted { $0.count > $1.count }
        
        let regions = regionCounts.map { key, count -> TasteProfileItem in
            let ratings = regionRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating)
        }.sorted { $0.count > $1.count }
        
        let styles = styleCounts.map { key, count -> TasteProfileItem in
            let ratings = styleRatings[key] ?? []
            let avgRating = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            return TasteProfileItem(name: key, count: count, averageRating: avgRating)
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

    /// Rankings count for profile stats.
    static func fetchRankingsCount(userId: UUID) async -> Int {
        struct Row: Decodable { let wine_id: UUID }
        let rows: [Row] = (try? await supabase
            .from("rankings")
            .select("wine_id")
            .eq("user_id", value: userId)
            .execute().value) ?? []
        return rows.count
    }
}
