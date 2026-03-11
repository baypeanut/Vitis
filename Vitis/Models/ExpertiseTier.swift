//
//  ExpertiseTier.swift
//  Pari
//
//  Expertise-adaptive UI density: novice/intermediate/expert tiers
//  based on tasting count. Controls note palette complexity and UI guidance.
//

import Foundation

enum ExpertiseTier: String, Sendable {
    case novice       // 0-10 tastings
    case intermediate // 11-50 tastings
    case expert       // 50+ tastings

    init(tastingCount: Int) {
        switch tastingCount {
        case 0...10:  self = .novice
        case 11...50: self = .intermediate
        default:      self = .expert
        }
    }
}
