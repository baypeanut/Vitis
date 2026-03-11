//
//  AnalyticsService.swift
//  Pari
//
//  PostHog analytics. Fire-and-forget. No PII. Keys from Config/Secrets.xcconfig.
//

import Foundation
import PostHog

enum AnalyticsService {
    private static var isConfigured = false

    static func setup() {
        guard !isConfigured else { return }
        guard AnalyticsConfig.isPostHogEnabled,
              let key = AnalyticsConfig.postHogAPIKey,
              let host = AnalyticsConfig.postHogHost else { return }
        let config = PostHogConfig(apiKey: key, host: host)
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    static func identify(userId: UUID) {
        guard AnalyticsConfig.isPostHogEnabled else { return }
        PostHogSDK.shared.identify(userId.uuidString)
    }

    static func reset() {
        guard AnalyticsConfig.isPostHogEnabled else { return }
        PostHogSDK.shared.reset()
    }

    static func track(_ event: String, properties: [String: Any]? = nil) {
        #if DEBUG
        var msg = "[Analytics] \(event)"
        if let p = properties, !p.isEmpty { msg += " \(p)" }
        print(msg)
        #endif
        guard AnalyticsConfig.isPostHogEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties ?? [:])
    }

    static func signupStarted() { track("signup_started") }
    static func signupCompleted() { track("signup_completed") }
    static func firstTastingStarted() { track("first_tasting_started") }
    static func firstTastingSaved(wineId: UUID, rating: Double) {
        track("first_tasting_saved", properties: ["wine_id": wineId.uuidString, "rating": rating])
    }
    static func follow(userId: UUID, added: Bool) {
        track("follow", properties: ["target_user_id": userId.uuidString, "added": added])
    }
    static func like(activityId: UUID, added: Bool) {
        track("like", properties: ["activity_id": activityId.uuidString, "added": added])
    }
    static func wishlistAdd(wineId: UUID) {
        track("wishlist_add", properties: ["wine_id": wineId.uuidString])
    }
    static func wishlistRemove(wineId: UUID) {
        track("wishlist_remove", properties: ["wine_id": wineId.uuidString])
    }
    static func wishlistSaveFromUser(wineId: UUID, sourceUserId: UUID) {
        track("wishlist_save_from_user", properties: ["wine_id": wineId.uuidString, "source_user_id": sourceUserId.uuidString])
    }
    static func profileView(userId: UUID) {
        track("profile_view", properties: ["user_id": userId.uuidString])
    }
    static func wantToTryOpened(userId: UUID) {
        track("want_to_try_opened", properties: ["user_id": userId.uuidString])
    }
    static func feedView() { track("feed_view") }
    static func wishlistView() { track("wishlist_view") }
    static func tastingCreate(wineId: UUID, rating: Double) {
        track("tasting_create", properties: ["wine_id": wineId.uuidString, "rating": rating])
    }

    /// Legacy alias for like
    static func likeToggle(activityId: UUID, added: Bool) { like(activityId: activityId, added: added) }
}
