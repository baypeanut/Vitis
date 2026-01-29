//
//  ProfileStore.swift
//  Vitis
//
//  Global @Observable current user profile. Updates propagate to Feed and Comments.
//

import Foundation

@MainActor
@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    var currentProfile: Profile?

    private init() {}

    func load() async {
        guard let uid = await AuthService.currentUserId() else {
            currentProfile = nil
            return
        }
        #if DEBUG
        if !AppConstants.authRequired {
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                currentProfile = dev
                return
            }
            if uid == AppConstants.debugMockUserId {
                currentProfile = Profile(id: uid, username: "Dev", fullName: nil, avatarURL: nil, bio: nil)
                return
            }
        }
        #endif
        do {
            currentProfile = try await AuthService.getProfile(userId: uid)
        } catch {
            #if DEBUG
            if !AppConstants.authRequired, uid == AppConstants.debugMockUserId {
                currentProfile = Profile(id: uid, username: "Dev", fullName: nil, avatarURL: nil, bio: nil)
            } else {
                currentProfile = nil
            }
            #else
            currentProfile = nil
            #endif
        }
    }

    /// Clear cached profile (e.g. on sign out in dev mode).
    func clearForSignOut() {
        currentProfile = nil
    }

    /// Update local state after profile edit. Feed/Comments use this for current user override.
    func updateLocal(_ profile: Profile) {
        currentProfile = profile
    }
}
