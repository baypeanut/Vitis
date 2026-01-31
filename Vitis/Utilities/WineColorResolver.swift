//
//  WineColorResolver.swift
//  Vitis
//
//  Centralized wine display color: maps type/category to brand palette.
//  Never returns black; fallback is a neutral "old money" burgundy.
//

import SwiftUI

enum NormalizedWineType: String, CaseIterable {
    case red
    case white
    case rose
    case orange
    case sparkling
}

enum WineColorResolver {

    // MARK: - Palette (hex from spec)

    static let colorRed = Color(red: 0x6B / 255, green: 0x0F / 255, blue: 0x1A / 255)        // #6B0F1A
    static let colorWhite = Color(red: 0x7D / 255, green: 0x62 / 255, blue: 0x20 / 255)      // #7D6220
    static let colorRose = Color(red: 0xB0 / 255, green: 0x4A / 255, blue: 0x6A / 255)       // #B04A6A
    static let colorOrange = Color(red: 0xB4 / 255, green: 0x4E / 255, blue: 0x1D / 255)     // #B44E1D
    static let colorSparkling = Color(red: 0xA8 / 255, green: 0x95 / 255, blue: 0x6A / 255)  // #A8956A
    /// Fallback when type unknown: muted burgundy, readable on white, never black.
    static let colorFallback = Color(red: 0x5C / 255, green: 0x2A / 255, blue: 0x2A / 255)   // #5C2A2A

    // MARK: - Synonym mappings (lowercased, normalized)

    private static let sparklingSynonyms = ["sparkling", "prosecco", "champagne", "cava", "spumante", "cremant", "crémant", "brut", "sec", "extra dry"]
    private static let orangeSynonyms = ["orange", "amber", "skin-contact", "skin contact", "skincontact"]
    private static let roseSynonyms = ["rose", "rosé", "rosado", "blush"]
    private static let redGrapes = ["shiraz", "syrah", "malbec", "cabernet", "merlot", "pinot noir", "nebbiolo", "sangiovese", "tempranillo", "zinfandel", "grenache", "mourvèdre", "mourvedre", "petit verdot", "pinotage", "barbera", "gamay"]
    private static let whiteGrapes = ["chardonnay", "sauvignon", "pinot grigio", "pinot gris", "riesling", "viognier", "albariño", "albarino", "grüner", "gruener", "vermentino", "chenin", "moscato", "gewurztraminer"]

    // MARK: - Resolve

    /// Returns display color for wine name/title. Never returns .primary/black.
    static func resolveWineDisplayColor(
        category: String?,
        wineName: String?,
        variety: String? = nil,
        debugPostId: UUID? = nil
    ) -> Color {
        if let type = normalizeWineType(category) {
            return color(for: type)
        }
        if let type = inferFromName(wineName ?? "") {
            return color(for: type)
        }
        if let type = inferFromName(variety ?? "") {
            return color(for: type)
        }
        #if DEBUG
        print("[WineColorResolver] fallback - postId: \(debugPostId?.uuidString ?? "nil") wineName: \(wineName ?? "nil") category: \(category ?? "nil") variety: \(variety ?? "nil") branch: none_matched")
        #endif
        return colorFallback
    }

    /// Convenience for Wine model.
    static func resolveWineDisplayColor(wine: Wine) -> Color {
        resolveWineDisplayColor(category: wine.category, wineName: wine.name, variety: wine.variety)
    }

    /// Convenience for FeedItem (no variety in payload).
    static func resolveWineDisplayColor(category: String?, wineName: String?, postId: UUID? = nil) -> Color {
        resolveWineDisplayColor(category: category, wineName: wineName, variety: nil, debugPostId: postId)
    }

    /// Convenience when only wine name is available (e.g. OFF search result).
    static func resolveWineDisplayColor(wineName: String?) -> Color {
        resolveWineDisplayColor(category: nil, wineName: wineName, variety: nil)
    }

    /// Normalize raw API type string to enum. Handles casing, whitespace, diacritics.
    static func normalizeWineType(_ raw: String?) -> NormalizedWineType? {
        let s = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            ?? ""
        guard !s.isEmpty else { return nil }

        if s.contains("red") || s.contains("rouge") || s.contains("rosso") { return .red }
        if s.contains("white") || s.contains("blanc") || s.contains("blanco") || s.contains("bianco") { return .white }
        if roseSynonyms.contains(where: { s.contains($0) }) { return .rose }
        if orangeSynonyms.contains(where: { s.contains($0) }) { return .orange }
        if sparklingSynonyms.contains(where: { s.contains($0) }) { return .sparkling }

        return nil
    }

    private static func color(for type: NormalizedWineType) -> Color {
        switch type {
        case .red: return colorRed
        case .white: return colorWhite
        case .rose: return colorRose
        case .orange: return colorOrange
        case .sparkling: return colorSparkling
        }
    }

    private static func inferFromName(_ name: String) -> NormalizedWineType? {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        guard !n.isEmpty else { return nil }

        if sparklingSynonyms.contains(where: { n.contains($0) }) { return .sparkling }
        if n.contains("orange wine") || orangeSynonyms.contains(where: { n.contains($0) }) { return .orange }
        if roseSynonyms.contains(where: { n.contains($0) }) { return .rose }
        if redGrapes.contains(where: { n.contains($0) }) { return .red }
        if whiteGrapes.contains(where: { n.contains($0) }) { return .white }

        return nil
    }
}
