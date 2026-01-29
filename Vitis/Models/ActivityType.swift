//
//  ActivityType.swift
//  Vitis
//
//  activity_feed.activity_type: rank_update, new_entry, duel_win.
//

import Foundation

enum ActivityType: String, Codable, Sendable {
    case rankUpdate = "rank_update"
    case newEntry = "new_entry"
    case duelWin = "duel_win"
    case hadWine = "had_wine"
}
