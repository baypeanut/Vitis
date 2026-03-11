//
//  PrivacySettings.swift
//  Pari
//
//  Visibility policy: Everyone vs Friends (mutual follow).
//

import Foundation

enum PrivacyVisibility: String, Codable, CaseIterable {
    case everyone = "everyone"
    case friends = "friends"

    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends"
        }
    }
}

struct PrivacySettings: Sendable {
    var cellarVisibility: PrivacyVisibility
    var wishlistVisibility: PrivacyVisibility
    var activityVisibility: PrivacyVisibility

    static let `default` = PrivacySettings(
        cellarVisibility: .everyone,
        wishlistVisibility: .everyone,
        activityVisibility: .everyone
    )
}
