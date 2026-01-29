//
//  FeedService.swift
//  Vitis
//
//  Fetch feed (Global / Following), cache for instant load, Realtime updates.
//

import Foundation
import Supabase

final class FeedService {
    static let shared = FeedService()
    private let cache = FeedCache()
    private let pageSize = 30

    private init() {}

    // MARK: - Cache

    func loadFromCache(mode: FeedMode) -> [FeedItem] {
        cache.load(cacheKey(for: mode))
    }

    func saveToCache(_ items: [FeedItem], mode: FeedMode) {
        cache.save(items, key: cacheKey(for: mode))
    }

    private func cacheKey(for mode: FeedMode) -> String {
        switch mode {
        case .global: return AppConstants.Cache.feedGlobalKey
        case .following: return AppConstants.Cache.feedFollowingKey
        }
    }

    // MARK: - Fetch

    func fetchGlobal(limit: Int? = nil, offset: Int = 0) async throws -> [FeedItem] {
        try await fetchFromView(limit: limit ?? pageSize, offset: offset)
    }

    func fetchFollowing(limit: Int? = nil, offset: Int = 0) async throws -> [FeedItem] {
        let client = SupabaseManager.shared.supabase
        guard let uid = await AuthService.currentUserId() else { return [] }

        let params = FeedFollowingParams(
            pFollowerId: uid,
            pLimit: limit ?? pageSize,
            pOffset: offset
        )
        let rows: [FeedRowPayload] = try await client.rpc("feed_following", params: params).execute().value
        // Filter to only had_wine activities
        return rows.filter { $0.activityType == .hadWine }.map { FeedItem.from(row: $0) }
    }

    private func fetchFromView(limit: Int, offset: Int) async throws -> [FeedItem] {
        let client = SupabaseManager.shared.supabase
        let rows: [FeedRowPayload] = try await client
            .from("feed_with_details")
            .select()
            .eq("activity_type", value: "had_wine")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return rows.map { FeedItem.from(row: $0) }
    }

    /// Recent activity for a specific user (their rankings / duel wins). Used in profile "Recent Activity" tab.
    func fetchActivityForUser(userId: UUID, limit: Int = 30, offset: Int = 0) async throws -> [FeedItem] {
        #if DEBUG
        print("[FeedService] fetchActivityForUser requested userId=\(userId)")
        #endif
        let client = SupabaseManager.shared.supabase
        let rows: [FeedRowPayload] = try await client
            .from("feed_with_details")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        let ids = rows.map(\.id)
        let likeCounts: [UUID: Int] = (try? await SocialService.fetchLikeCounts(activityIDs: ids)) ?? [:]
        let commentCounts: [UUID: Int] = (try? await SocialService.fetchCommentCounts(activityIDs: ids)) ?? [:]
        var likedIDs: Set<UUID> = []
        if let uid = await AuthService.currentUserId() {
            likedIDs = (try? await SocialService.fetchLikedActivityIDs(userId: uid)) ?? []
        }
        return rows.map { r in
            FeedItem.from(
                row: r,
                cheersCount: likeCounts[r.id] ?? 0,
                commentCount: commentCounts[r.id] ?? 0,
                hasCheered: likedIDs.contains(r.id)
            )
        }
    }

    // MARK: - Delete

    /// Delete an activity_feed row by its ID.
    func deleteFeedActivity(activityId: UUID) async throws {
        let client = SupabaseManager.shared.supabase
        try await client
            .from("activity_feed")
            .delete()
            .eq("id", value: activityId)
            .execute()
    }

    // MARK: - Realtime

    /// Subscribe to new activity_feed inserts. Call `cancel()` to unsubscribe.
    /// On insert, invokes `onNewActivity`; ViewModel should refetch.
    func subscribeToNewActivity(onNewActivity: @escaping () -> Void) -> RealtimeChannelTask? {
        let client = SupabaseManager.shared.supabase
        let channel = client.channel("activity_feed_inserts")
        let stream = channel.postgresChange(InsertAction.self, schema: "public", table: "activity_feed")

        let task = Task { @MainActor in
            try? await channel.subscribeWithError()
            for await _ in stream {
                onNewActivity()
            }
        }
        return RealtimeChannelTask(channel: channel, task: task)
    }
}

enum FeedMode {
    case global
    case following
}

final class RealtimeChannelTask: Sendable {
    private let channel: RealtimeChannelV2
    private let task: Task<Void, Never>

    init(channel: RealtimeChannelV2, task: Task<Void, Never>) {
        self.channel = channel
        self.task = task
    }

    func cancel() {
        task.cancel()
        Task {
            await SupabaseManager.shared.supabase.removeChannel(channel)
        }
    }
}
