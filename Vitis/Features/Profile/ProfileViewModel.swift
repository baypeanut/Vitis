//
//  ProfileViewModel.swift
//  Vitis
//
//  Beli-style profile data: profile, stats, recent activity, taste profile, streak.
//  Keyed by userId; never overrides with current user. All fetches use self.userId only.
//

import Foundation
import UIKit

private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

@MainActor
@Observable
final class ProfileViewModel {
    let userId: UUID
    var isOwn: Bool = false

    var profile: Profile?
    var ratedCount: Int = 0
    var followersCount: Int = 0
    var followingCount: Int = 0
    var recentActivity: [FeedItem] = []
    var allTastings: [Tasting] = []
    var tastingCheersCounts: [UUID: Int] = [:]
    var tasteGrapes: [TasteProfileItem] = []
    var tasteRegions: [TasteProfileItem] = []
    var tasteStyles: [TasteProfileItem] = []
    var wishlistPreview: [CellarItem] = []
    var myWishlistWineIds: Set<UUID> = []
    var wishlistToggleError: String?
    var privacySettings: PrivacySettings = .default
    var isViewerFriend: Bool = false
    var isLoadingInitial = true
    var isRefreshing = false
    var errorMessage: String?
    var isLoading: Bool { isLoadingInitial || isRefreshing }

    private var loadId = UUID()

    /// Top 5 tastings for Recent Activity; sorted by createdAt desc (tastedAt when in schema).
    var recentTastingsTop5: [Tasting] {
        let sorted = allTastings.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(5))
    }

    /// Visibility for another user's profile sections. Own profile: always true.
    var cellarVisible: Bool {
        isOwn || privacySettings.cellarVisibility == .everyone || (privacySettings.cellarVisibility == .friends && isViewerFriend)
    }
    var wishlistVisible: Bool {
        isOwn || privacySettings.wishlistVisibility == .everyone || (privacySettings.wishlistVisibility == .friends && isViewerFriend)
    }
    var activityVisible: Bool {
        isOwn || privacySettings.activityVisibility == .everyone || (privacySettings.activityVisibility == .friends && isViewerFriend)
    }

    init(userId: UUID) {
        self.userId = userId
    }

    func load() async {
        let uid = userId
        let currentLoadId = UUID()
        loadId = currentLoadId
        let isFirstLoad = allTastings.isEmpty && profile == nil
        if isFirstLoad {
            isLoadingInitial = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil
        wishlistToggleError = nil

        var newProfile: Profile?
        var newRatedCount: Int?
        var newFollowersCount: Int?
        var newFollowingCount: Int?
        var newTastings: [Tasting]?
        var newTasteProfile: (grapes: [TasteProfileItem], regions: [TasteProfileItem], styles: [TasteProfileItem])?
        var newWishlistPreview: [CellarItem]?
        var newMyWishlistWineIds: Set<UUID>?
        var newCheersCounts: [UUID: Int]?

        let current = await AuthService.currentUserId()
        guard loadId == currentLoadId else {
            if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }
            return
        }
        isOwn = (current == uid)

        do {
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
                newProfile = dev
            } else {
                let p = try await AuthService.getProfile(userId: uid)
                guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
                newProfile = p
            }
        } catch {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }

        let countTask = Task { await TastingService.fetchTastingsCount(userId: uid) }
        let followersTask = Task { await SocialService.fetchFollowerCount(userId: uid) }
        let followingTask = Task { await SocialService.fetchFollowingCount(userId: uid) }
        let tastingsTask = Task { try await TastingService.fetchTastings(userId: uid, limit: 200) }
        let wishlistTask = Task { try await CellarService.fetchWishlist(userId: uid, limit: 15) }
        let myWishlistTask: Task<Set<UUID>, Error>? = (current != nil && current != uid) ? Task { try await CellarService.fetchWishlistWineIds(userId: current!) } : nil
        let privacyTask = Task { try? await ProfileService.fetchPrivacySettings(userId: uid) }
        let isFriendTask: Task<Bool, Never>? = (current != nil && current != uid) ? Task { await ProfileService.isMutualFriend(viewerId: current!, ownerId: uid) } : Task { true }

        newRatedCount = await countTask.value
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
        newFollowersCount = await followersTask.value
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
        newFollowingCount = await followingTask.value
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }

        do {
            let tastings = try await tastingsTask.value
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            newTastings = tastings
            newTasteProfile = ProfileService.computeTasteProfile(from: tastings)
            newCheersCounts = await TastingService.fetchLikeCountsForTastings(tastingIds: tastings.map(\.id))
        } catch {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }

        do {
            let items = try await wishlistTask.value
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            newWishlistPreview = items
        } catch {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            if !isCancellation(error) { errorMessage = ErrorMessage.userFacing(for: error) }
        }

        if let task = myWishlistTask {
            newMyWishlistWineIds = (try? await task.value) ?? []
        }
        privacySettings = await privacyTask.value ?? .default
        isViewerFriend = await (isFriendTask?.value ?? true)

        if loadId != currentLoadId {
            if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }
            return
        }

        if let p = newProfile { profile = p }
        if let c = newRatedCount { ratedCount = c }
        if let f = newFollowersCount { followersCount = f }
        if let f = newFollowingCount { followingCount = f }
        if let t = newTastings { allTastings = t }
        if let c = newCheersCounts { tastingCheersCounts = c }
        if let w = newWishlistPreview { wishlistPreview = w }
        if let w = newMyWishlistWineIds { myWishlistWineIds = w }
        if let tp = newTasteProfile {
            tasteGrapes = tp.grapes
            tasteRegions = tp.regions
            tasteStyles = tp.styles
        }

        isLoadingInitial = false
        isRefreshing = false
    }

    /// Remove wine from own wishlist. Used when viewing own profile tab.
    func removeFromWishlist(_ item: CellarItem) async {
        do {
            try await CellarService.removeFromWishlist(wineId: item.wineId)
            wishlistPreview.removeAll { $0.id == item.id }
            NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
        } catch {
            wishlistToggleError = "Could not remove."
        }
    }

    /// Toggle wishlist from profile (when viewing another user's Want to Try). Optimistic update; reverts on failure.
    func toggleWishlistFromProfile(_ item: CellarItem) async {
        guard let cur = await AuthService.currentUserId(), cur != userId else { return }
        let wineId = item.wineId
        let wasIn = myWishlistWineIds.contains(wineId)
        wishlistToggleError = nil
        if wasIn {
            myWishlistWineIds.remove(wineId)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            do {
                try await CellarService.removeFromWishlist(wineId: wineId)
                NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
            } catch {
                myWishlistWineIds.insert(wineId)
                wishlistToggleError = "Could not update."
            }
            return
        }
        myWishlistWineIds.insert(wineId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            let added = try await CellarService.addToWishlist(wineId: wineId, sourceUserId: userId, sourceContext: "wishlist")
            if added {
                AnalyticsService.wishlistSaveFromUser(wineId: wineId, sourceUserId: userId)
                NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
            } else {
                myWishlistWineIds.remove(wineId)
                NotificationCenter.default.post(name: .vitisAlreadyTastedToast, object: nil)
            }
        } catch {
            myWishlistWineIds.remove(wineId)
            wishlistToggleError = "Could not update."
        }
    }
}
