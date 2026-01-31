//
//  AnalyticsService.swift
//  Vitis
//
//  Minimal analytics. Fire-and-forget. No PII. Swap implementation for Mixpanel/Amplitude/PostHog.
//

import Foundation

enum AnalyticsService {
    static func track(_ event: String, properties: [String: Any]? = nil) {
        #if DEBUG
        var msg = "[Analytics] \(event)"
        if let p = properties, !p.isEmpty {
            msg += " \(p)"
        }
        print(msg)
        #endif
        // TODO: Wire to Mixpanel/Amplitude/PostHog when chosen
    }

    static func feedView() { track("feed_view") }
    static func likeToggle(activityId: UUID, added: Bool) { track("like_toggle", properties: ["added": added]) }
    static func wishlistAdd(wineId: UUID) { track("wishlist_add") }
    static func wishlistRemove(wineId: UUID) { track("wishlist_remove") }
    static func wishlistView() { track("wishlist_view") }
    static func tastingCreate(wineId: UUID, rating: Double) { track("tasting_create", properties: ["rating": rating]) }
}
