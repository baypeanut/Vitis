//
//  WineRecommendation.swift
//  Pari
//
//  A wine suggested by recommend_wines, with the signals behind the suggestion so the
//  UI can say why it is there.
//

import Foundation

struct WineRecommendation: Identifiable, Sendable {
    /// Why this wine surfaced. Mirrors the `reason` column of recommend_wines.
    enum Reason: String, Sendable {
        /// People whose ratings track yours have scored it.
        case twins
        /// No twin coverage, but the wider community has rated it.
        case community
        /// Nobody comparable has rated it; it matches the shape of what you like.
        case tasteMatch = "taste_match"
        /// Cold start: you have no tastings yet, so this is a community favourite.
        case popular

        init(rawValue: String) {
            switch rawValue {
            case "twins": self = .twins
            case "community": self = .community
            case "popular": self = .popular
            default: self = .tasteMatch
            }
        }
    }

    let wine: Wine
    /// Cosine similarity between the wine and the user's taste vector, 0...1.
    /// Nil during cold start, where there is no taste vector to compare against.
    let affinity: Double?
    let twinAvg: Double?
    let twinCount: Int
    let communityAvg: Double?
    let communityCount: Int
    let score: Double
    let reason: Reason

    var id: UUID { wine.id }

    /// The rating worth showing: what your twins scored, else what everyone scored.
    var headlineRating: Double? { twinAvg ?? communityAvg }

    /// Short explanation for the card. Nil when there is nothing honest to claim.
    var explanation: String? {
        switch reason {
        case .twins:
            let people = twinCount == 1 ? "1 taste twin" : "\(twinCount) taste twins"
            return "Rated by \(people)"
        case .community:
            let people = communityCount == 1 ? "1 rating" : "\(communityCount) ratings"
            return "\(people) from the community"
        case .tasteMatch:
            guard let affinity else { return "Matches your taste" }
            return "\(Int((affinity * 100).rounded()))% match to your taste"
        case .popular:
            guard communityCount > 0 else { return nil }
            let people = communityCount == 1 ? "1 rating" : "\(communityCount) ratings"
            return "Popular right now · \(people)"
        }
    }
}
