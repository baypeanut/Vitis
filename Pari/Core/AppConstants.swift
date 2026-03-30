//
//  AppConstants.swift
//  Pari
//
//  App-wide constants and configuration.
//

import Foundation

enum AppConstants {
    static let bundleID = "com.ahmet.pari"

    enum URLs {
        static let privacyPolicy = URL(string: "https://pari.app/privacy")!
        static let termsOfService = URL(string: "https://pari.app/terms")!
        /// Contact / Support (App Store Guideline 1.5). Opens mail client or support page.
        static let supportContact = URL(string: "mailto:support@pari.app")!
    }

    /// When false, skip login/signup (dev/test). Set true for production / App Store.
    static let authRequired = true

    enum Cache {
        /// v5 = bump to invalidate stale cache after pariTastingCreated fix.
        static let feedGlobalKey = "pari_feed_global_v5"
        static let feedFollowingKey = "pari_feed_following_v5"
    }

    #if DEBUG
    /// Fixed test account for "Sign in as test user" in dev. Create this user once in Supabase → Auth → Users.
    static let devTestEmail = "dev@pari.test"
    static let devTestPassword = "DevTest1!"
    #endif
}

extension Notification.Name {
    /// Fired when guest session is ready (auth bypass). Cellar/Duel should refresh.
    static let pariSessionReady = Notification.Name("pariSessionReady")
    /// Fired when current user profile (name/avatar) is updated. Feed/Comments override without manual refresh.
    static let pariProfileUpdated = Notification.Name("pariProfileUpdated")
    /// Deep link pari://auth/reset received. Dismiss login/forgot sheets so NewPasswordView is visible.
    static let pariDeepLinkResetPassword = Notification.Name("pariDeepLinkResetPassword")
    /// Request showing Log in sheet (e.g. after "Go to Log in" in NewPasswordView success).
    static let pariShowLogIn = Notification.Name("pariShowLogIn")
    /// Request to switch to the Cellar tab (e.g. when user taps "Rated" on their own profile).
    static let pariSwitchToCellarTab = Notification.Name("pariSwitchToCellarTab")
    /// Wishlist updated; Feed should refresh wishlist IDs.
    static let pariWishlistUpdated = Notification.Name("pariWishlistUpdated")
    /// Tasting created; Feed should refresh to show new activity.
    static let pariTastingCreated = Notification.Name("pariTastingCreated")
    /// User tried to add an already-tasted wine to wishlist. Observers show toast.
    static let pariAlreadyTastedToast = Notification.Name("pariAlreadyTastedToast")
    /// Like toggled on an activity. userInfo: ["activityId": UUID, "hasCheered": Bool, "cheersCount": Int]
    static let pariLikeToggled = Notification.Name("pariLikeToggled")
}
