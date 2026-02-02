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
    var suggestedUsers: [SocialService.FollowListUser] = []
    var wishlistWineIds: Set<UUID> = []
    var tastedWineIds: Set<UUID> = []
    var wishlistSourceUserIds: [UUID] = []
    var wishlistErrorToast: String?
    var isRefreshing = false
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
        isRefreshing = true
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
            var likedIDs: Set<UUID> = []
            let uid = await AuthService.currentUserId()
            currentUserId = uid
            if let uid = uid {
                async let lc = SocialService.fetchLikeCounts(activityIDs: ids)
                async let lid = SocialService.fetchLikedActivityIDs(userId: uid)
                likeCounts = (try? await lc) ?? [:]
                likedIDs = (try? await lid) ?? []
            } else {
                likeCounts = (try? await SocialService.fetchLikeCounts(activityIDs: ids)) ?? [:]
            }
            for i in fetched.indices {
                var it = fetched[i]
                let id = it.id
                it.cheersCount = likeCounts[id] ?? 0
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
            if let uid = currentUserId {
                do {
                    wishlistWineIds = try await CellarService.fetchWishlistWineIds(userId: uid)
                } catch {
                    if !isCancellation(error) { wishlistErrorToast = ErrorMessage.unknown }
                }
                tastedWineIds = (try? await TastingService.fetchTastedWineIds(userId: uid)) ?? []
                wishlistSourceUserIds = (try? await CellarService.fetchWishlistSourceUserIdsInLastK(userId: uid, k: WishlistSourceStore.windowSize)) ?? []
            }
        } catch {
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }
        if tab == .following && items.isEmpty {
            suggestedUsers = await SocialService.fetchSuggestedUsersToFollow(limit: 5)
        } else {
            suggestedUsers = []
        }
        isRefreshing = false
    }

    func refreshWishlistIds() async {
        guard let uid = currentUserId else { return }
        wishlistWineIds = (try? await CellarService.fetchWishlistWineIds(userId: uid)) ?? wishlistWineIds
        wishlistSourceUserIds = (try? await CellarService.fetchWishlistSourceUserIdsInLastK(userId: uid, k: WishlistSourceStore.windowSize)) ?? wishlistSourceUserIds
    }

    func isInWishlist(wineId: UUID) -> Bool { wishlistWineIds.contains(wineId) }
    
    func hasTasted(wineId: UUID) -> Bool { tastedWineIds.contains(wineId) }

    /// Toggle wishlist for feed item's wine. Optimistic update; reverts and shows toast on failure.
    func toggleWishlist(_ item: FeedItem) async {
        guard await AuthService.currentUserId() != nil else { return }
        let wineId = item.wineId
        let wasIn = wishlistWineIds.contains(wineId)
        wishlistWineIds = wasIn ? wishlistWineIds.filter { $0 != wineId } : wishlistWineIds.union([wineId])
        wishlistErrorToast = nil
        do {
            if wasIn {
                try await CellarService.removeFromWishlist(wineId: wineId)
            } else {
                try await CellarService.addToWishlist(wineId: wineId, sourceUserId: item.userId, sourceContext: "feed")
            }
        } catch {
            wishlistWineIds = wasIn ? wishlistWineIds.union([wineId]) : wishlistWineIds.filter { $0 != wineId }
            wishlistErrorToast = ErrorMessage.unknown
        }
        if wishlistErrorToast == nil && !wasIn {
            wishlistSourceUserIds = [item.userId] + wishlistSourceUserIds
            AnalyticsService.wishlistAdd(wineId: wineId)
            if currentUserId != item.userId {
                AnalyticsService.wishlistSaveFromUser(wineId: wineId, sourceUserId: item.userId)
            }
            NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
        } else if wishlistErrorToast == nil && wasIn {
            AnalyticsService.wishlistRemove(wineId: wineId)
        }
    }

    /// Trust hint: "You often save wines from {name}" when save affinity >= threshold (backend + local).
    func trustHint(for item: FeedItem) -> String? {
        guard currentUserId != item.userId else { return nil }
        let count = wishlistSourceUserIds.prefix(WishlistSourceStore.windowSize).filter { $0 == item.userId }.count
        guard count >= WishlistSourceStore.threshold else { return nil }
        return "You often save wines from \(item.username)"
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
            AnalyticsService.likeToggle(activityId: item.id, added: u.hasCheered)
            FeedService.shared.saveToCache(items, mode: mode)
            if u.hasCheered, let actorId = currentUserId, actorId != item.userId {
                Task { await NotificationService.createLikeNotification(recipientId: item.userId, actorId: actorId, postId: item.id) }
            }
        } catch {
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
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
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }
    }
}
