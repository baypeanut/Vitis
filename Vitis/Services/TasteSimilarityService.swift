//
//  TasteSimilarityService.swift
//  Vitis
//
//  Taste Twin Engine: computes and fetches pairwise taste similarity via Supabase RPCs.
//  Hybrid blend: α × Pearson collaborative + (1-α) × cosine content-based.
//  Also provides twin-weighted ratings for wines (personalized scores).
//

import Foundation
import Supabase

private struct SimilarityRow: Decodable, Sendable {
    let user_a: UUID
    let user_b: UUID
    let score: Double
    let shared_count: Int
    let computed_at: Date
}

private struct TwinRow: Decodable, Sendable {
    let twin_id: UUID
    let username: String
    let full_name: String?
    let avatar_url: String?
    let score: Double
    let shared_count: Int
    let computed_at: Date
}

private struct TwinRatingsBatchParams: Encodable, Sendable {
    let p_user_id: String
    let p_wine_ids: [String]

    private enum CodingKeys: String, CodingKey { case p_user_id, p_wine_ids }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_user_id, forKey: .p_user_id)
        try c.encode(p_wine_ids, forKey: .p_wine_ids)
    }
}

enum TasteSimilarityService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Compute similarity between two users (on-demand, cached 7 days)

    /// Compute or retrieve cached similarity between current user and target.
    /// Returns nil if fewer than 5 shared wines or score < 30%.
    static func fetchSimilarity(targetUserId: UUID) async -> TasteSimilarity? {
        guard let currentId = await AuthService.currentUserId(), currentId != targetUserId else { return nil }

        // Canonical ordering: user_a < user_b
        let (userA, userB) = currentId.uuidString < targetUserId.uuidString
            ? (currentId, targetUserId)
            : (targetUserId, currentId)

        let params: [String: String] = [
            "p_user_a": userA.uuidString,
            "p_user_b": userB.uuidString
        ]

        do {
            let rows: [SimilarityRow] = try await supabase
                .rpc("compute_taste_similarity", params: params)
                .execute()
                .value

            guard let row = rows.first else { return nil }
            let sim = TasteSimilarity(
                userA: row.user_a,
                userB: row.user_b,
                score: row.score,
                sharedCount: row.shared_count,
                computedAt: row.computed_at
            )
            return sim.score >= TasteSimilarity.displayThreshold ? sim : nil
        } catch {
            #if DEBUG
            print("[TasteSimilarityService] fetchSimilarity error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Fetch top taste twins for a user

    /// Fetch the user's top taste twins (sorted by score desc, max `limit`).
    static func fetchTasteTwins(userId: UUID, limit: Int = 20) async -> [TasteTwin] {
        let params: [String: String] = [
            "p_user_id": userId.uuidString,
            "p_limit": String(limit)
        ]

        do {
            let rows: [TwinRow] = try await supabase
                .rpc("get_taste_twins", params: params)
                .execute()
                .value

            return rows.map { row in
                let sim = TasteSimilarity(
                    userA: userId,
                    userB: row.twin_id,
                    score: row.score,
                    sharedCount: row.shared_count,
                    computedAt: row.computed_at
                )
                return TasteTwin(
                    id: row.twin_id,
                    username: row.username,
                    fullName: row.full_name,
                    avatarURL: row.avatar_url,
                    similarity: sim
                )
            }
        } catch {
            #if DEBUG
            print("[TasteSimilarityService] fetchTasteTwins error: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Fetch twin IDs for batch checks (feed badges)

    /// Returns a set of user IDs that are taste twins of the current user (score >= threshold).
    static func fetchTwinIds(userId: UUID) async -> Set<UUID> {
        let twins = await fetchTasteTwins(userId: userId, limit: 50)
        return Set(twins.map(\.id))
    }

    // MARK: - Twin-weighted ratings

    private struct TwinRatingRow: Decodable, Sendable {
        let twin_weighted_avg: Double?
        let twin_count: Int
        let community_avg: Double?
        let community_count: Int
    }

    /// Twin-weighted + community rating for a single wine.
    static func fetchTwinWeightedRating(wineId: UUID) async -> TwinWeightedRating? {
        guard let userId = await AuthService.currentUserId() else { return nil }

        do {
            let rows: [TwinRatingRow] = try await supabase
                .rpc("get_twin_weighted_rating", params: [
                    "p_user_id": userId.uuidString,
                    "p_wine_id": wineId.uuidString
                ])
                .execute()
                .value

            guard let row = rows.first else { return nil }
            return TwinWeightedRating(
                twinWeightedAvg: row.twin_weighted_avg,
                twinCount: row.twin_count,
                communityAvg: row.community_avg,
                communityCount: row.community_count
            )
        } catch {
            #if DEBUG
            print("[TasteSimilarityService] fetchTwinWeightedRating error: \(error)")
            #endif
            return nil
        }
    }

    private struct BatchTwinRatingRow: Decodable, Sendable {
        let wine_id: UUID
        let twin_weighted_avg: Double?
        let twin_count: Int
        let community_avg: Double?
        let community_count: Int
    }

    /// Twin-weighted + community ratings for multiple wines (batch).
    static func fetchTwinWeightedRatingsBatch(wineIds: [UUID]) async -> [UUID: TwinWeightedRating] {
        guard let userId = await AuthService.currentUserId(), !wineIds.isEmpty else { return [:] }
        do {
            let rows: [BatchTwinRatingRow] = try await supabase
                .rpc("get_twin_weighted_ratings_batch", params: TwinRatingsBatchParams(
                    p_user_id: userId.uuidString,
                    p_wine_ids: wineIds.map(\.uuidString)
                ))
                .execute()
                .value

            var result: [UUID: TwinWeightedRating] = [:]
            for row in rows {
                result[row.wine_id] = TwinWeightedRating(
                    twinWeightedAvg: row.twin_weighted_avg,
                    twinCount: row.twin_count,
                    communityAvg: row.community_avg,
                    communityCount: row.community_count
                )
            }
            return result
        } catch {
            #if DEBUG
            print("[TasteSimilarityService] fetchTwinWeightedRatingsBatch error: \(error)")
            #endif
            return [:]
        }
    }
}
