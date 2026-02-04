//
//  NotificationService.swift
//  Vitis
//
//  In-app notifications for like and comment.
//

import Foundation
import Supabase

struct NotificationItem: Identifiable, Sendable {
    let id: UUID
    let recipientId: UUID
    let actorId: UUID
    let type: String
    let postId: UUID
    let commentId: UUID?
    let createdAt: Date
    let isRead: Bool
    let actorUsername: String?
    let actorAvatarUrl: String?
    let commentPreview: String?
    let tastingTitle: String?
}

enum NotificationService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Create notification when user likes a post. Call after successful like insert.
    static func createLikeNotification(recipientId: UUID, actorId: UUID, postId: UUID) async {
        guard actorId != recipientId else { return }
        struct Insert: Encodable {
            let recipient_id: UUID
            let actor_id: UUID
            let type: String
            let post_id: UUID
        }
        _ = try? await supabase.from("notifications")
            .insert(Insert(recipient_id: recipientId, actor_id: actorId, type: "like", post_id: postId))
            .execute()
    }

    /// Create notification when user comments. Call after successful comment insert.
    static func createCommentNotification(recipientId: UUID, actorId: UUID, postId: UUID, commentId: UUID, commentPreview: String?) async {
        guard actorId != recipientId else { return }
        struct Insert: Encodable {
            let recipient_id: UUID
            let actor_id: UUID
            let type: String
            let post_id: UUID
            let comment_id: UUID
        }
        _ = try? await supabase.from("notifications")
            .insert(Insert(recipient_id: recipientId, actor_id: actorId, type: "comment", post_id: postId, comment_id: commentId))
            .execute()
    }

    /// Fetch notifications for current user. Paginated.
    static func fetchNotifications(limit: Int = 30, offset: Int = 0) async throws -> [NotificationItem] {
        guard let uid = await AuthService.currentUserId() else { return [] }
        struct Row: Decodable {
            let id: UUID
            let recipient_id: UUID
            let actor_id: UUID
            let type: String
            let post_id: UUID
            let comment_id: UUID?
            let created_at: Date
            let is_read: Bool
            let actor_profile: ActorRef?
            let comment: CommentRef?
            struct ActorRef: Decodable {
                let username: String?
                let avatar_url: String?
            }
            struct CommentRef: Decodable {
                let body: String?
            }
        }
        let rows: [Row] = try await supabase.from("notifications")
            .select("id, recipient_id, actor_id, type, post_id, comment_id, created_at, is_read")
            .eq("recipient_id", value: uid)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute().value

        let actorIds = Set(rows.map(\.actor_id))
        var actorMap: [UUID: (username: String?, avatar_url: String?)] = [:]
        if !actorIds.isEmpty {
            struct PRow: Decodable { let id: UUID; let username: String?; let avatar_url: String? }
            let profiles: [PRow] = (try? await supabase.from("profiles").select("id, username, avatar_url").in("id", values: Array(actorIds)).execute().value) ?? []
            for p in profiles { actorMap[p.id] = (p.username, p.avatar_url) }
        }

        let commentIds = rows.compactMap(\.comment_id)
        var commentMap: [UUID: String] = [:]
        if !commentIds.isEmpty {
            struct CRow: Decodable { let id: UUID; let body: String }
            let comments: [CRow] = (try? await supabase.from("comments").select("id, body").in("id", values: commentIds).execute().value) ?? []
            for c in comments {
                let preview = c.body.count > 60 ? String(c.body.prefix(60)) + "…" : c.body
                commentMap[c.id] = preview
            }
        }

        let postIds = Set(rows.map(\.post_id))
        var postMap: [UUID: (wineName: String?, wineProducer: String?, wineVintage: Int?)] = [:]
        if !postIds.isEmpty {
            struct PostRow: Decodable {
                let id: UUID
                let wine_name: String?
                let wine_producer: String?
                let wine_vintage: Int?
            }
            let posts: [PostRow] = (try? await supabase
                .from("feed_with_details")
                .select("id, wine_name, wine_producer, wine_vintage")
                .in("id", values: Array(postIds))
                .execute()
                .value) ?? []
            for p in posts {
                postMap[p.id] = (p.wine_name, p.wine_producer, p.wine_vintage)
            }
        }

        return rows.map { r in
            let actor = actorMap[r.actor_id]
            let commentPreview = r.comment_id.flatMap { commentMap[$0] }
            let post = postMap[r.post_id]
            let tastingTitle = formatTastingTitle(
                wineName: post?.wineName,
                wineProducer: post?.wineProducer,
                wineVintage: post?.wineVintage
            )
            return NotificationItem(
                id: r.id,
                recipientId: r.recipient_id,
                actorId: r.actor_id,
                type: r.type,
                postId: r.post_id,
                commentId: r.comment_id,
                createdAt: r.created_at,
                isRead: r.is_read,
                actorUsername: actor?.username,
                actorAvatarUrl: actor?.avatar_url,
                commentPreview: commentPreview,
                tastingTitle: tastingTitle
            )
        }
    }

    private static func formatTastingTitle(wineName: String?, wineProducer: String?, wineVintage: Int?) -> String? {
        let trimmedName = wineName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProducer = wineProducer?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = trimmedName?.isEmpty == false
        let hasProducer = trimmedProducer?.isEmpty == false
        guard hasName || hasProducer else { return nil }
        var parts: [String] = []
        if let producer = trimmedProducer, !producer.isEmpty { parts.append(producer) }
        if let name = trimmedName, !name.isEmpty { parts.append(name) }
        if let vintage = wineVintage { parts.append(String(vintage)) }
        return parts.joined(separator: " ")
    }

    static func markAsRead(notificationId: UUID) async throws {
        try await supabase.from("notifications").update(["is_read": true]).eq("id", value: notificationId).eq("recipient_id", value: await AuthService.currentUserId()!).execute()
    }

    static func markAllAsRead() async throws {
        guard let uid = await AuthService.currentUserId() else { return }
        try await supabase.from("notifications").update(["is_read": true]).eq("recipient_id", value: uid).execute()
    }

    static func fetchUnreadCount() async -> Int {
        guard let uid = await AuthService.currentUserId() else { return 0 }
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await supabase.from("notifications").select("id").eq("recipient_id", value: uid).eq("is_read", value: false).execute().value) ?? []
        return rows.count
    }
}
