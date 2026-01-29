//
//  SocialService.swift
//  Vitis
//
//  Likes (Cheers) and Comments via separate tables. Follow/unfollow. Uses AuthService.currentUserId (mock in DEBUG).
//

import Foundation
import Supabase

enum SocialService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Likes (Cheers)

    /// Toggle like for activity. If exists in likes → delete; otherwise insert. Uses current user (session when available).
    static func toggleLike(activityID: UUID) async throws {
        guard let uid = await AuthService.currentUserId() else { return }
        #if DEBUG
        let sessionId = (try? await supabase.auth.session)?.user.id
        print("[SocialService] toggleLike activity_id=\(activityID) user_id=\(uid) session.user.id=\(sessionId?.uuidString ?? "nil")")
        #endif
        struct Row: Decodable { let user_id: UUID }
        let rows: [Row] = try await supabase.from("likes")
            .select("user_id")
            .eq("activity_id", value: activityID)
            .eq("user_id", value: uid)
            .limit(1)
            .execute()
            .value

        if rows.first != nil {
            try await supabase.from("likes")
                .delete()
                .eq("activity_id", value: activityID)
                .eq("user_id", value: uid)
                .execute()
        } else {
            struct Insert: Encodable {
                let activity_id: UUID
                let user_id: UUID
            }
            let payload = Insert(activity_id: activityID, user_id: uid)
            #if DEBUG
            print("[SocialService] likes INSERT payload: activity_id=\(payload.activity_id) user_id=\(payload.user_id)")
            #endif
            try await supabase.from("likes")
                .insert(payload)
                .execute()
        }
    }

    /// Fetch like counts per activity. Returns [activityID: count].
    static func fetchLikeCounts(activityIDs: [UUID]) async throws -> [UUID: Int] {
        guard !activityIDs.isEmpty else { return [:] }
        struct Row: Decodable { let activity_id: UUID }
        let rows: [Row] = try await supabase.from("likes")
            .select("activity_id")
            .in("activity_id", values: activityIDs)
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for id in activityIDs { counts[id] = 0 }
        for r in rows { counts[r.activity_id, default: 0] += 1 }
        return counts
    }

    /// Fetch activity IDs the current user has liked.
    static func fetchLikedActivityIDs(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let activity_id: UUID }
        let rows: [Row] = try await supabase.from("likes")
            .select("activity_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(rows.map(\.activity_id))
    }

    // MARK: - Comments

    /// Add a comment. Inserts into comments; multiple comments per user/activity allowed.
    static func addComment(activityID: UUID, body: String) async throws {
        guard let uid = await AuthService.currentUserId() else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        struct Insert: Encodable {
            let activity_id: UUID
            let user_id: UUID
            let body: String
        }
        try await supabase.from("comments")
            .insert(Insert(activity_id: activityID, user_id: uid, body: trimmed))
            .execute()
    }

    /// Fetch comments for an activity from comments table. JOIN profiles for full_name, avatar_url.
    static func fetchComments(activityID: UUID) async throws -> [CommentWithProfile] {
        struct CRow: Decodable {
            let id: UUID
            let user_id: UUID
            let body: String
            let created_at: Date
        }
        let all: [CRow] = try await supabase.from("comments")
            .select("id, user_id, body, created_at")
            .eq("activity_id", value: activityID)
            .order("created_at", ascending: true)
            .execute()
            .value
        let userIds = Set(all.map(\.user_id))
        var displayNameMap: [UUID: String] = [:]
        var avatarMap: [UUID: String] = [:]
        if !userIds.isEmpty {
            struct PRow: Decodable { let id: UUID; let username: String?; let full_name: String?; let avatar_url: String? }
            let profiles: [PRow] = (try? await supabase.from("profiles")
                .select("id, username, full_name, avatar_url")
                .in("id", values: Array(userIds))
                .execute().value) ?? []
            for p in profiles {
                let name = (p.full_name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? p.full_name : nil) ?? p.username ?? "Unknown"
                displayNameMap[p.id] = name
                avatarMap[p.id] = p.avatar_url
            }
        }
        return all.map { r in
            CommentWithProfile(
                id: r.id,
                userId: r.user_id,
                username: displayNameMap[r.user_id] ?? "Unknown",
                avatarURL: avatarMap[r.user_id],
                body: r.body,
                createdAt: r.created_at
            )
        }
    }

    /// Fetch comment counts per activity. Returns [activityID: count].
    static func fetchCommentCounts(activityIDs: [UUID]) async throws -> [UUID: Int] {
        guard !activityIDs.isEmpty else { return [:] }
        struct Row: Decodable { let activity_id: UUID }
        let rows: [Row] = try await supabase.from("comments")
            .select("activity_id")
            .in("activity_id", values: activityIDs)
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for id in activityIDs { counts[id] = 0 }
        for r in rows { counts[r.activity_id, default: 0] += 1 }
        return counts
    }

    // MARK: - Follow

    static func followUser(targetID: UUID) async throws {
        guard let uid = await AuthService.currentUserId() else { return }
        guard uid != targetID else { return }
        struct Insert: Encodable {
            let follower_id: UUID
            let followed_id: UUID
        }
        try await supabase.from("follows")
            .upsert(Insert(follower_id: uid, followed_id: targetID), onConflict: "follower_id,followed_id")
            .execute()
    }

    static func unfollowUser(targetID: UUID) async throws {
        guard let uid = await AuthService.currentUserId() else { return }
        try await supabase.from("follows")
            .delete()
            .eq("follower_id", value: uid)
            .eq("followed_id", value: targetID)
            .execute()
    }

    static func isFollowing(targetID: UUID) async -> Bool {
        guard let uid = await AuthService.currentUserId() else { return false }
        struct Row: Decodable { let follower_id: UUID }
        let rows: [Row] = (try? await supabase.from("follows")
            .select("follower_id")
            .eq("follower_id", value: uid)
            .eq("followed_id", value: targetID)
            .limit(1)
            .execute().value) ?? []
        return !rows.isEmpty
    }

    /// Follower count for a user (how many follow them).
    static func fetchFollowerCount(userId: UUID) async -> Int {
        struct Row: Decodable { let follower_id: UUID }
        let rows: [Row] = (try? await supabase.from("follows")
            .select("follower_id")
            .eq("followed_id", value: userId)
            .execute().value) ?? []
        return rows.count
    }

    /// Following count for a user (how many they follow).
    static func fetchFollowingCount(userId: UUID) async -> Int {
        struct Row: Decodable { let follower_id: UUID }
        let rows: [Row] = (try? await supabase.from("follows")
            .select("follower_id")
            .eq("follower_id", value: userId)
            .execute().value) ?? []
        return rows.count
    }
}

struct CommentWithProfile: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarURL: String?
    let body: String
    let createdAt: Date
}
