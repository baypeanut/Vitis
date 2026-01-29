//
//  RankingItem.swift
//  Vitis
//
//  User's ranked wine (rankings + wine details). Cellar "My Ranking" list.
//

import Foundation

struct RankingItem: Identifiable, Sendable {
    let wineId: UUID
    let position: Int
    let eloScore: Double
    let wine: Wine

    var id: UUID { wineId }
}
