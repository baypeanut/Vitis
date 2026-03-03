//
//  TasteSimilarity.swift
//  Vitis
//
//  Taste Twin Engine: similarity model between two users.
//  Uses Bayesian-shrunk Pearson correlation on shared wine ratings.
//  Formula: score = pearson_r × (n / (n + k)), k = 10.
//

import Foundation

struct TasteSimilarity: Sendable {
    let userA: UUID
    let userB: UUID
    let score: Double
    let sharedCount: Int
    let computedAt: Date

    /// 0–100 percentage for display.
    var percentage: Int { max(0, min(100, Int((score * 100).rounded()))) }

    /// Human-readable label based on similarity bracket.
    var label: String {
        switch percentage {
        case 80...100: return "Taste Twin"
        case 60..<80:  return "Very Similar"
        case 40..<60:  return "Similar"
        case 30..<40:  return "Some Overlap"
        default:       return "Different"
        }
    }

    /// Short display string, e.g. "87% match".
    var displayText: String { "\(percentage)% match" }

    /// SF Symbol for the similarity tier.
    var icon: String {
        switch percentage {
        case 80...100: return "person.2.fill"
        case 60..<80:  return "person.2"
        case 40..<60:  return "person.line.dotted.person"
        default:       return "person.2.slash"
        }
    }

    /// Minimum score (30%) to show in UI.
    static let displayThreshold: Double = 0.30
}

/// A user who is a "taste twin" — shown in the twins list on profile.
struct TasteTwin: Identifiable, Sendable {
    let id: UUID          // other user's ID
    let username: String
    let fullName: String?
    let avatarURL: String?
    let similarity: TasteSimilarity

    var displayName: String {
        if let full = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return full
        }
        return username
    }
}
