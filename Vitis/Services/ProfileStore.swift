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
            // Try dev account first (from dev_accounts table)
            if let dev = await DevSignupService.fetchDevAccount(userId: uid) {
                currentProfile = dev
                return
            }
        }
        #endif
        do {
            // Try real profile from profiles table
            currentProfile = try await AuthService.getProfile(userId: uid)
        } catch {
            #if DEBUG
            if !AppConstants.authRequired {
                // Fallback: create minimal profile if profile doesn't exist yet
                // This allows dev mode to work even without a profile row
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
