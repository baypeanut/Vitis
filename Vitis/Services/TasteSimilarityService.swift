//
//  TasteSimilarityService.swift
//  Vitis
//
//  Taste Twin Engine: computes and fetches pairwise taste similarity via Supabase RPCs.
//  Uses Bayesian-shrunk Pearson correlation (k = 10) with minimum 5 shared wines.
//
//  ⚠️ MANUAL SUPABASE STEPS REQUIRED:
//  1. Create `taste_similarity` table
//  2. Create `compute_taste_similarity` and `get_taste_twins` RPCs
//  See: supabase/setup_schema.sql (Section 12)
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
}
