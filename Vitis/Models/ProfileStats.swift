//
//  ProfileStats.swift
//  Vitis
//
//  Taste Analytics from ranking history: Style Preference, Avg Vintage Age, Top Region.
//

import Foundation

struct ProfileStats: Sendable {
    let stylePreference: String
    let averageVintageAge: Double?
    let topRegion: String?

    static func from(ranking: [RankingItem]) -> ProfileStats {
        let stylePreference = Self.computeStylePreference(ranking)
        let averageVintageAge = Self.computeAverageVintageAge(ranking)
        let topRegion = Self.computeTopRegion(ranking)
        return ProfileStats(
            stylePreference: stylePreference,
            averageVintageAge: averageVintageAge,
            topRegion: topRegion
        )
    }

    private static func computeStylePreference(_ items: [RankingItem]) -> String {
        let oldWorld = Set(["france", "bordeaux", "burgundy", "rhône", "rhone", "champagne", "alsace", "loire",
                           "italy", "tuscany", "piedmont", "veneto", "sicily",
                           "spain", "rioja", "ribera", "priorat",
                           "germany", "portugal", "austria", "greece", "hungary"])
        var old = 0, new = 0
        for it in items {
            let r = (it.wine.region ?? "").lowercased()
            if !r.isEmpty {
                if oldWorld.contains(where: { r.contains($0) }) { old += 1 }
                else { new += 1 }
            }
        }
        if old + new == 0 { return "-" }
        if old >= new { return "Old World" }
        return "New World"
    }

    private static func computeAverageVintageAge(_ items: [RankingItem]) -> Double? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let ages = items.compactMap { item -> Int? in
            guard let v = item.wine.vintage, v > 0, v <= currentYear else { return nil }
            return currentYear - v
        }
        guard !ages.isEmpty else { return nil }
        return Double(ages.reduce(0, +)) / Double(ages.count)
    }

    private static func computeTopRegion(_ items: [RankingItem]) -> String? {
        var count: [String: Int] = [:]
        for it in items {
            let r = (it.wine.region ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !r.isEmpty { count[r, default: 0] += 1 }
        }
        return count.max(by: { $0.value < $1.value })?.key
    }
}
