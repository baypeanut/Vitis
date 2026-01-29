//
//  TasteSnapshotOptions.swift
//  Vitis
//
//  Predefined options for Taste Snapshot (Loves, Avoids, Mood) and Weekly goal.
//  Stored as option id (string) in profiles.
//

import Foundation

enum TasteSnapshotOptions {
    static let loves: [(id: String, label: String)] = [
        ("nebbiolo", "Nebbiolo"),
        ("cabernet_sauvignon", "Cabernet Sauvignon"),
        ("syrah", "Syrah"),
        ("chardonnay", "Chardonnay"),
        ("pinot_noir", "Pinot Noir"),
        ("sangiovese", "Sangiovese"),
        ("tempranillo", "Tempranillo"),
        ("riesling", "Riesling"),
        ("gamay", "Gamay"),
        ("grenache", "Grenache"),
        ("none", "None")
    ]

    static let avoids: [(id: String, label: String)] = [
        ("oak", "Heavy oak"),
        ("sweet", "Sweet"),
        ("tannic", "Very tannic"),
        ("none", "None")
    ]

    static let mood: [(id: String, label: String)] = [
        ("bold_red", "Bold red"),
        ("crisp_white", "Crisp white"),
        ("bubbles", "Bubbles"),
        ("chillable_red", "Chillable red"),
        ("none", "None")
    ]

    static let weeklyGoal: [(id: String, label: String)] = [
        ("none", "None"),
        ("rank_3", "Rank 3 wines this week"),
        ("rank_5", "Rank 5 wines this week"),
        ("rank_10", "Rank 10 wines this week")
    ]

    static func labelForLoves(id: String?) -> String {
        guard let id, id != "none" else { return "-" }
        return loves.first { $0.id == id }?.label ?? id
    }

    static func labelForAvoids(id: String?) -> String {
        guard let id, id != "none" else { return "-" }
        return avoids.first { $0.id == id }?.label ?? id
    }

    static func labelForMood(id: String?) -> String {
        guard let id, id != "none" else { return "-" }
        return mood.first { $0.id == id }?.label ?? id
    }

    static func labelForWeeklyGoal(id: String?) -> String {
        guard let id, id != "none" else { return "None" }
        return weeklyGoal.first { $0.id == id }?.label ?? id
    }
}
