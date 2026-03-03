//
//  AppConstants.swift
//  Vitis
//
//  App-wide constants and configuration.
//

import Foundation

enum AppConstants {
    static let bundleID = "com.ahmet.vitis"

    enum URLs {
        static let privacyPolicy = URL(string: "https://vitis.app/privacy")!
        static let termsOfService = URL(string: "https://vitis.app/terms")!
        /// Contact / Support (App Store Guideline 1.5). Opens mail client or support page.
        static let supportContact = URL(string: "mailto:support@vitis.app")!
    }

    /// When false, skip login/signup; always show main app. Set true to require auth.
    static let authRequired = false

    enum Cache {
        /// v5 = bump to invalidate stale cache after vitisTastingCreated fix.
        static let feedGlobalKey = "vitis_feed_global_v5"
        static let feedFollowingKey = "vitis_feed_following_v5"
    }

    #if DEBUG
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
    /// Request to switch to the Cellar tab (e.g. when user taps "Rated" on their own profile).
    static let vitisSwitchToCellarTab = Notification.Name("vitisSwitchToCellarTab")
    /// Wishlist updated; Feed should refresh wishlist IDs.
    static let vitisWishlistUpdated = Notification.Name("vitisWishlistUpdated")
    /// Tasting created; Feed should refresh to show new activity.
    static let vitisTastingCreated = Notification.Name("vitisTastingCreated")
    /// User tried to add an already-tasted wine to wishlist. Observers show toast.
    static let vitisAlreadyTastedToast = Notification.Name("vitisAlreadyTastedToast")
}
