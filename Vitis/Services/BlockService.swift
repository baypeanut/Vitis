//
//  BlockService.swift
//  Pari
//
//  Block/unblock users. Blocked users are hidden from feed and profile.
//  Apple App Store Section 1.2 requirement for UGC apps.
//
//  ⚠️ MANUAL SUPABASE STEPS REQUIRED:
//  1. Create `blocks` table
//  2. Update `feed_global` and `feed_following` RPCs to filter blocked users
//  See: docs/supabase_manual_steps.md
//

import Foundation
import Supabase

enum BlockService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Block a user. Requires `blocks` table in Supabase (see manual steps).
    static func blockUser(blockedId: UUID) async throws {
        guard let blockerId = await AuthService.currentUserId() else { return }
        let payload: [String: String] = [
            "blocker_id": blockerId.uuidString,
            "blocked_id": blockedId.uuidString
        ]
        try await supabase
            .from("blocks")
            .upsert(payload)
            .execute()
    }

    /// Unblock a user.
    static func unblockUser(blockedId: UUID) async throws {
        guard let blockerId = await AuthService.currentUserId() else { return }
        try await supabase
            .from("blocks")
            .delete()
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: blockedId)
            .execute()
    }

    /// Check if the current user has blocked a given user.
    static func isBlocking(userId: UUID) async -> Bool {
        guard let blockerId = await AuthService.currentUserId() else { return false }
        struct Row: Decodable { let blocked_id: String }
        let rows: [Row] = (try? await supabase
            .from("blocks")
            .select("blocked_id")
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: userId)
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }
}
