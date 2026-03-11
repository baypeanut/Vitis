//
//  TwinWeightedRating.swift
//  Pari
//
//  Twin-weighted rating for a wine: personalized score from taste twins + community average.
//

import Foundation

struct TwinWeightedRating: Sendable {
    let twinWeightedAvg: Double?
    let twinCount: Int
    let communityAvg: Double?
    let communityCount: Int
}
