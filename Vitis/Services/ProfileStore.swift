//
//  ProfileStore.swift
//  Pari
//
//  Global @Observable current user profile. Updates propagate to Feed and Comments.
//

import Foundation

@MainActor
@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    var currentProfile: Profile?
    var tastingCount: Int = 0

    var expertiseTier: ExpertiseTier { ExpertiseTier(tastingCount: tastingCount) }

    private init() {}

    func load() async {
        guard let uid = await AuthService.currentUserId() else {
            currentProfile = nil
            return
        }
        AnalyticsService.identify(userId: uid)
        #if DEBUG
        if !AppConstants.authRequired {
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                currentProfile = dev
                tastingCount = await TastingService.fetchTastingsCount(userId: uid)
                return
            }
        }
        #endif
        do {
            currentProfile = try await AuthService.getProfile(userId: uid)
            tastingCount = await TastingService.fetchTastingsCount(userId: uid)
        } catch {
            #if DEBUG
            if !AppConstants.authRequired {
                currentProfile = Profile(id: uid, username: "Dev", fullName: nil, avatarURL: nil, bio: nil)
                tastingCount = await TastingService.fetchTastingsCount(userId: uid)
            } else {
                currentProfile = nil
            }
            #else
            currentProfile = nil
            #endif
        }
    }

    /// Increment local tasting count (called after tasting creation to keep tier fresh).
    func incrementTastingCount() {
        tastingCount += 1
    }

    /// Clear cached profile (e.g. on sign out in dev mode).
    func clearForSignOut() {
        currentProfile = nil
        tastingCount = 0
        AnalyticsService.reset()
    }

    /// Update local state after profile edit. Feed/Comments use this for current user override.
    func updateLocal(_ profile: Profile) {
        currentProfile = profile
    }
}
