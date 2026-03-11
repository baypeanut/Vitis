//
//  AnalyticsConfig.swift
//  Pari
//
//  Reads PostHog keys from Info.plist (injected from Config/Secrets.xcconfig).
//  Paste your PostHog API key in Config/Secrets.xcconfig.
//

import Foundation

enum AnalyticsConfig {
    static var postHogAPIKey: String? {
        Bundle.main.infoDictionary?["PostHogAPIKey"] as? String
    }

    static var postHogHost: String? {
        (Bundle.main.infoDictionary?["PostHogHost"] as? String).flatMap { URL(string: $0)?.absoluteString }
    }

    static var isPostHogEnabled: Bool {
        guard let key = postHogAPIKey, !key.isEmpty, key != "phc_replace_me" else { return false }
        return true
    }
}
