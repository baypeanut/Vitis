//
//  DuelService.swift
//  Vitis
//
//  Fetch duel pair, submit comparison, write activity_feed. Beli-style pairwise flow.
//

import Foundation
import Supabase

enum DuelService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Fetch next A vs B pair for duel. Returns (wineA, wineB, wineAIsNew) or nil if fewer than 2 wines.
    static func fetchNextPair(userId: UUID) async throws -> (Wine, Wine, Bool)? {
        let params = DuelNextPairParams(pUserId: userId)
        let rows: [DuelPairPayload] = try await supabase
            .rpc("duel_next_pair", params: params)
            .execute()
            .value
        guard let first = rows.first else { return nil }
        return (first.wineA, first.wineB, first.wineAIsNew)
    }

    /// Persist comparison, upsert rankings (Elo-style), insert activity_feed duel_win.
    static func submitComparison(
        userId: UUID,
        wineA: Wine,
        wineB: Wine,
        winnerId: UUID
    ) async throws {
        struct ComparisonInsert: Encodable {
            let user_id: UUID
            let wine_a_id: UUID
            let wine_b_id: UUID
            let winner_id: UUID
        }
        try await supabase.from("comparisons")
            .insert(ComparisonInsert(
                user_id: userId,
                wine_a_id: wineA.id,
                wine_b_id: wineB.id,
                winner_id: winnerId
            ))
            .execute()

        try await upsertRankingsElo(userId: userId, wineA: wineA, wineB: wineB, winnerId: winnerId)

        let wineId = winnerId
        let targetId = winnerId == wineA.id ? wineB.id : wineA.id
        struct ActivityInsert: Encodable {
            let user_id: UUID
            let activity_type: String
            let wine_id: UUID
            let target_wine_id: UUID
        }
        try await supabase.from("activity_feed")
            .insert(ActivityInsert(
                user_id: userId,
                activity_type: "duel_win",
                wine_id: wineId,
                target_wine_id: targetId
            ))
            .execute()
    }

    private static let kFactor = 32.0
    private static let defaultElo = 1500.0

    private static func upsertRankingsElo(
        userId: UUID,
        wineA: Wine,
        wineB: Wine,
        winnerId: UUID
    ) async throws {
        let (winId, loseId) = winnerId == wineA.id ? (wineA.id, wineB.id) : (wineB.id, wineA.id)

        struct Row: Decodable { let elo_score: Double }
        var sWin = defaultElo
        var sLose = defaultElo
        let rWin: [Row] = try await supabase.from("rankings").select("elo_score")
            .eq("user_id", value: userId).eq("wine_id", value: winId).limit(1).execute().value
        let rLose: [Row] = try await supabase.from("rankings").select("elo_score")
            .eq("user_id", value: userId).eq("wine_id", value: loseId).limit(1).execute().value
        if let r = rWin.first { sWin = r.elo_score }
        if let r = rLose.first { sLose = r.elo_score }

        let ea = 1.0 / (1.0 + pow(10, (sLose - sWin) / 400))
        let eb = 1.0 - ea
        let newWin = sWin + kFactor * (1 - ea)
        let newLose = sLose + kFactor * (0 - eb)

        struct RankRow: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let elo_score: Double
            let position: Int
            let updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try await supabase.from("rankings")
            .upsert([
                RankRow(user_id: userId, wine_id: winId, elo_score: newWin, position: 0, updated_at: now),
                RankRow(user_id: userId, wine_id: loseId, elo_score: newLose, position: 0, updated_at: now)
            ])
            .execute()

        Task { _ = try? await repositionRankings(userId: userId) }
    }

    private static func repositionRankings(userId: UUID) async throws {
        struct Row: Decodable { let wine_id: UUID }
        let rows: [Row] = try await supabase.from("rankings")
            .select("wine_id")
            .eq("user_id", value: userId)
            .order("elo_score", ascending: false)
            .execute()
            .value

        struct Update: Encodable {
            let position: Int
            let updated_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        for (idx, row) in rows.enumerated() {
            _ = try? await supabase.from("rankings")
                .update(Update(position: idx + 1, updated_at: now))
                .eq("user_id", value: userId)
                .eq("wine_id", value: row.wine_id)
                .execute()
        }
    }
}
