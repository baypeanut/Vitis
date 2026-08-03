//
//  RecommendationService.swift
//  Pari
//
//  Personalised wine discovery via the recommend_wines RPC: HNSW retrieval over the
//  user's taste vector, reranked by twin and community ratings.
//

import Foundation
import Supabase

enum RecommendationService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private struct Row: Decodable, Sendable {
        let id: UUID
        let name: String
        let producer: String
        let vintage: Int?
        let variety: String?
        let region: String?
        let label_image_url: String?
        let category: String?
        let affinity: Double?
        let twin_avg: Double?
        let twin_count: Int
        let community_avg: Double?
        let community_count: Int
        let score: Double
        let reason: String
    }

    private struct Params: Encodable, Sendable {
        let p_user_id: String
        let p_limit: Int

        private enum CodingKeys: String, CodingKey { case p_user_id, p_limit }
        nonisolated func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_user_id, forKey: .p_user_id)
            try c.encode(p_limit, forKey: .p_limit)
        }
    }

    /// Wines to try next, best first. Empty on failure - discovery is not worth an
    /// error banner over the feed.
    static func fetchRecommendations(limit: Int = 20) async -> [WineRecommendation] {
        guard let userId = await AuthService.currentUserId() else { return [] }

        do {
            let rows: [Row] = try await supabase
                .rpc("recommend_wines", params: Params(p_user_id: userId.uuidString, p_limit: limit))
                .execute()
                .value

            return rows.map { row in
                WineRecommendation(
                    wine: Wine(
                        id: row.id,
                        name: row.name,
                        producer: row.producer,
                        vintage: row.vintage,
                        variety: row.variety,
                        region: row.region,
                        labelImageURL: row.label_image_url,
                        category: row.category
                    ),
                    affinity: row.affinity,
                    twinAvg: row.twin_avg,
                    twinCount: row.twin_count,
                    communityAvg: row.community_avg,
                    communityCount: row.community_count,
                    score: row.score,
                    reason: WineRecommendation.Reason(rawValue: row.reason)
                )
            }
        } catch {
            #if DEBUG
            print("[RecommendationService] fetchRecommendations error: \(error)")
            #endif
            return []
        }
    }
}
