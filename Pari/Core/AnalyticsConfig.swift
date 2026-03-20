//
//  AnalyticsConfig.swift
//  Pari
//
//  PostHog is currently disabled. Re-enable when ready by setting isPostHogEnabled = true
//  and providing keys in Config/Secrets.xcconfig.
//

import Foundation

enum AnalyticsConfig {
    static var postHogAPIKey: String? {
        Bundle.main.infoDictionary?["PostHogAPIKey"] as? String
    }

    static var postHogHost: String? {
        (Bundle.main.infoDictionary?["PostHogHost"] as? String).flatMap { URL(string: $0)?.absoluteString }
    }

    // PostHog disabled — set to true when ready to enable analytics.
    static var isPostHogEnabled: Bool { false }
}
