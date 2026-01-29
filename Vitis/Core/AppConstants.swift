//
//  AppConstants.swift
//  Vitis
//
//  App-wide constants and configuration.
//

import Foundation

enum AppConstants {
    static let bundleID = "com.ahmet.vitis"

    /// When false, skip login/signup; always show main app. Set true to require auth.
    static let authRequired = false

    enum Cache {
        /// Bumped to avoid loading stale "Guest" items after cascade + Guest cleanup.
        static let feedGlobalKey = "vitis_feed_global_v2"
        static let feedFollowingKey = "vitis_feed_following_v2"
    }

    #if DEBUG
    /// Replace with your Supabase user UUID (Dashboard → Auth → Users). Dev bypass only; never in production.
    static let debugMockUserId = UUID(uuidString: "cbdc2158-6c97-4ab2-bfce-7facc315dd6f")!

    /// Fixed test account for "Sign in as test user" in dev. Create this user once in Supabase → Auth → Users.
    static let devTestEmail = "dev@vitis.test"
    static let devTestPassword = "DevTest1!"
    #endif
}

extension Notification.Name {
    /// Fired when guest session is ready (auth bypass). Cellar/Duel should refresh.
    static let vitisSessionReady = Notification.Name("vitisSessionReady")
    /// Fired when current user profile (name/avatar) is updated. Feed/Comments override without manual refresh.
    static let vitisProfileUpdated = Notification.Name("vitisProfileUpdated")
    /// Deep link vitis://auth/reset received. Dismiss login/forgot sheets so NewPasswordView is visible.
    static let vitisDeepLinkResetPassword = Notification.Name("vitisDeepLinkResetPassword")
    /// Request showing Log in sheet (e.g. after "Go to Log in" in NewPasswordView success).
    static let vitisShowLogIn = Notification.Name("vitisShowLogIn")
}
