//
//  FeedViewModel.swift
//  Vitis
//
//  MVVM for feed: load from cache, fetch + enrich with likes/comments from DB, update state only after confirm.
//

import Foundation

private func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let u = error as? URLError, u.code == .cancelled { return true }
    return error.localizedDescription.lowercased().contains("cancelled")
}

@MainActor
@Observable
final class FeedViewModel {
    enum Tab { case global, following }

    var tab: Tab = .global
    var items: [FeedItem] = []
    var isLoading = false
    var errorMessage: String?
    private var realtimeTask: RealtimeChannelTask?
    private(set) var currentUserId: UUID?

    var mode: FeedMode {
        switch tab {
        case .global: return .global
        case .following: return .following
        }
    }

    func loadFromCache() {
        let raw = FeedService.shared.loadFromCache(mode: mode)
        items = raw.filter { $0.username.trimmingCharacters(in: .whitespaces).lowercased() != "guest" }
    }

    func refresh() async {
        loadFromCache()
        isLoading = true
        errorMessage = nil
        do {
            var fetched: [FeedItem]
            switch mode {
            case .global:
                fetched = try await FeedService.shared.fetchGlobal()
            case .following:
                fetched = try await FeedService.shared.fetchFollowing()
            }
            let ids = fetched.map(\.id)
            let likeCounts: [UUID: Int]
            let commentCounts: [UUID: Int]
            var likedIDs: Set<UUID> = []
            let uid = await AuthService.currentUserId()
            currentUserId = uid
            if let uid = uid {
                async let lc = SocialService.fetchLikeCounts(activityIDs: ids)
                async let cc = SocialService.fetchCommentCounts(activityIDs: ids)
                async let lid = SocialService.fetchLikedActivityIDs(userId: uid)
                likeCounts = (try? await lc) ?? [:]
                commentCounts = (try? await cc) ?? [:]
                likedIDs = (try? await lid) ?? []
            } else {
                likeCounts = (try? await SocialService.fetchLikeCounts(activityIDs: ids)) ?? [:]
                commentCounts = (try? await SocialService.fetchCommentCounts(activityIDs: ids)) ?? [:]
            }
            for i in fetched.indices {
                var it = fetched[i]
                let id = it.id
                it.cheersCount = likeCounts[id] ?? 0
                it.commentCount = commentCounts[id] ?? 0
                it.hasCheered = likedIDs.contains(id)
                fetched[i] = it
            }
            let filtered = fetched.filter { $0.username.trimmingCharacters(in: .whitespaces).lowercased() != "guest" }
            #if DEBUG
            if filtered.count != fetched.count {
                print("[FeedViewModel] filtered out \(fetched.count - filtered.count) Guest feed items")
            }
            #endif
            items = filtered
            patchCurrentUserOverrides()
            FeedService.shared.saveToCache(items, mode: mode)
        } catch {
            if !isCancellation(error) { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func switchTab(to newTab: Tab) {
        guard newTab != tab else { return }
        tab = newTab
        loadFromCache()
        Task { await refresh() }
    }

    func subscribeRealtime() {
        realtimeTask?.cancel()
        realtimeTask = FeedService.shared.subscribeToNewActivity { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func unsubscribeRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    /// Toggle like. Updates local state only after Supabase confirms (no optimistic update).
    func cheer(_ item: FeedItem) async {
        do {
            try await SocialService.toggleLike(activityID: item.id)
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
            var u = items[idx]
            u.hasCheered.toggle()
            u.cheersCount += u.hasCheered ? 1 : -1
            items[idx] = u
            FeedService.shared.saveToCache(items, mode: mode)
            if u.hasCheered, let actorId = currentUserId, actorId != item.userId {
                Task { await NotificationService.createLikeNotification(recipientId: item.userId, actorId: actorId, postId: item.id) }
            }
        } catch {
            if !isCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    func statement(for item: FeedItem) -> String {
        let name = item.username
        let wine = item.wineVintage.map { "\($0) \(item.wineName)" } ?? item.wineName
        switch item.activityType {
        case .rankUpdate:
            let list = item.contentText ?? "their list"
            return "\(name) ranked \(wine) to #1 in \(list)."
        case .newEntry:
            return "\(name) discovered \(wine)."
        case .duelWin:
            let other = item.targetWineVintage.map { "\($0) \(item.targetWineName ?? "")" }
                ?? item.targetWineName ?? "another wine"
            return "\(name) ranked \(wine) higher than \(other)."
        case .hadWine:
            return "\(name) had \(wine)."
        }
    }

    func statementParts(for item: FeedItem) -> (before: String, name: String, after: String) {
        let s = statement(for: item)
        let name = item.username
        guard let r = s.range(of: name) else { return (s, "", "") }
        return (
            String(s[..<r.lowerBound]),
            name,
            String(s[r.upperBound...])
        )
    }

    /// Override username/avatar for current user from ProfileStore. Call after refresh and on vitisProfileUpdated.
    func patchCurrentUserOverrides() {
        guard let uid = currentUserId, let p = ProfileStore.shared.currentProfile else { return }
        for i in items.indices where items[i].userId == uid {
            items[i].username = p.displayName
            items[i].avatarURL = p.avatarURL
        }
        FeedService.shared.saveToCache(items, mode: mode)
    }

    /// Delete a feed item (only for own posts). Removes from DB and local state.
    func deleteFeedItem(_ item: FeedItem) async {
        guard let uid = currentUserId, item.userId == uid else { return }
        do {
            try await FeedService.shared.deleteFeedActivity(activityId: item.id)
            items.removeAll { $0.id == item.id }
            FeedService.shared.saveToCache(items, mode: mode)
        } catch {
            if !isCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}
