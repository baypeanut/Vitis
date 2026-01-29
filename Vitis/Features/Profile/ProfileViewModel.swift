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
    var recentTastings: [Tasting] = []
    var tasteGrapes: [TasteProfileItem] = []
    var tasteRegions: [TasteProfileItem] = []
    var tasteStyles: [TasteProfileItem] = []
    var lastActivityDate: Date?
    var isLoading = true
    var errorMessage: String?

    private var loadId = UUID()

    init(userId: UUID) {
        self.userId = userId
    }

    func load() async {
        let uid = userId
        let currentLoadId = UUID()
        loadId = currentLoadId
        isLoading = true
        errorMessage = nil
        #if DEBUG
        print("[ProfileViewModel] load start userId=\(uid)")
        #endif

        let current = await AuthService.currentUserId()
        guard loadId == currentLoadId else { isLoading = false; return }
        isOwn = (current == uid)

        do {
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                guard loadId == currentLoadId else { isLoading = false; return }
                profile = dev
            } else {
                let p = try await AuthService.getProfile(userId: uid)
                guard loadId == currentLoadId else { isLoading = false; return }
                profile = p
            }
        } catch {
            guard loadId == currentLoadId else { isLoading = false; return }
            errorMessage = error.localizedDescription
            profile = nil
        }

        let ratedCount = await TastingService.fetchTastingsCount(userId: uid)
        guard loadId == currentLoadId else { isLoading = false; return }
        rankingsCount = ratedCount

        let followers = await SocialService.fetchFollowerCount(userId: uid)
        guard loadId == currentLoadId else { isLoading = false; return }
        followersCount = followers

        let following = await SocialService.fetchFollowingCount(userId: uid)
        guard loadId == currentLoadId else { isLoading = false; return }
        followingCount = following

        #if DEBUG
        print("[ProfileViewModel] fetchRecentTastings requested userId=\(uid)")
        #endif
        let tastings = (try? await TastingService.fetchTastings(userId: uid, limit: 30)) ?? []
        guard loadId == currentLoadId else { isLoading = false; return }
        recentTastings = tastings

        let t = try? await ProfileService.fetchTasteProfile(userId: uid)
        guard loadId == currentLoadId else { isLoading = false; return }
        tasteGrapes = t?.grapes ?? []
        tasteRegions = t?.regions ?? []
        tasteStyles = t?.styles ?? []

        let last = await ProfileService.fetchLastActivityDate(userId: uid)
        guard loadId == currentLoadId else { isLoading = false; return }
        lastActivityDate = last

        isLoading = false
    }
}
