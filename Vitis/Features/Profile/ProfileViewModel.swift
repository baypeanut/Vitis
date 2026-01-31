//
//  ProfileViewModel.swift
//  Vitis
//
//  Beli-style profile data: profile, stats, recent activity, taste profile, streak.
//  Keyed by userId; never overrides with current user. All fetches use self.userId only.
//

import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    let userId: UUID
    var isOwn: Bool = false

    var profile: Profile?
    var rankingsCount: Int = 0
    var followersCount: Int = 0
    var followingCount: Int = 0
    var recentActivity: [FeedItem] = []
    var allTastings: [Tasting] = []
    var tasteGrapes: [TasteProfileItem] = []
    var tasteRegions: [TasteProfileItem] = []
    var tasteStyles: [TasteProfileItem] = []
    var lastActivityDate: Date?
    var isLoadingInitial = true
    var isRefreshing = false
    var errorMessage: String?
    var isLoading: Bool { isLoadingInitial || isRefreshing }

    private var loadId = UUID()

    /// Top 5 tastings for Recent Activity; sorted by createdAt desc (tastedAt equivalent).
    var recentTastingsTop5: [Tasting] {
        Array(allTastings.prefix(5))
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
        #if DEBUG
        print("[ProfileViewModel] load start userId=\(uid)")
        #endif

        var newProfile: Profile?
        var newRankingsCount: Int?
        var newFollowersCount: Int?
        var newFollowingCount: Int?
        var newTastings: [Tasting]?
        var newTasteProfile: (grapes: [TasteProfileItem], regions: [TasteProfileItem], styles: [TasteProfileItem])?
        var newLastActivityDate: Date?

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
            errorMessage = error.localizedDescription
        }

        let countResult = await TastingService.fetchTastingsCount(userId: uid)
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
        newRankingsCount = countResult

        let followersResult = await SocialService.fetchFollowerCount(userId: uid)
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
        newFollowersCount = followersResult

        let followingResult = await SocialService.fetchFollowingCount(userId: uid)
        guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
        newFollowingCount = followingResult

        if let tastings = try? await TastingService.fetchTastings(userId: uid, limit: 200) {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            newTastings = tastings
        }

        if let t = try? await ProfileService.fetchTasteProfile(userId: uid) {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            newTasteProfile = (t.grapes, t.regions, t.styles)
        }

        if let last = await ProfileService.fetchLastActivityDate(userId: uid) {
            guard loadId == currentLoadId else { if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }; return }
            newLastActivityDate = last
        }

        if loadId != currentLoadId {
            if isFirstLoad { isLoadingInitial = false } else { isRefreshing = false }
            return
        }

        if let p = newProfile { profile = p }
        if let c = newRankingsCount { rankingsCount = c }
        if let f = newFollowersCount { followersCount = f }
        if let f = newFollowingCount { followingCount = f }
        if let t = newTastings { allTastings = t }
        if let tp = newTasteProfile {
            tasteGrapes = tp.grapes
            tasteRegions = tp.regions
            tasteStyles = tp.styles
        }
        if let d = newLastActivityDate { lastActivityDate = d }

        isLoadingInitial = false
        isRefreshing = false
    }
}
