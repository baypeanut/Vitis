//
//  WineCategoryResolver.swift
//  Vitis
//
//  Centralized category resolution: API type, grape/variety, name heuristics.
//  Prevents red/white/rose/sparkling from falling into "Other".
//

import Foundation

enum WineCategoryResolver {
    /// Resolved category: Red, White, Rose, Orange, Sparkling, or Other.
    static func resolve(
        category: String?,
        variety: String?,
        name: String?
    ) -> String {
        let cat = category?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let vari = variety?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let n = name?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        
        // 1. Explicit API category
        if !cat.isEmpty {
            if cat.contains("sparkling") || cat.contains("prosecco") { return "Sparkling" }
            if cat.contains("red") || cat.contains("rouge") { return "Red" }
            if cat.contains("white") || cat.contains("blanc") { return "White" }
            if cat.contains("rose") || cat.contains("rosé") { return "Rose" }
            if cat.contains("orange") { return "Orange" }
        }
        
        // 2. Grape/variety heuristics
        let redGrapes = ["shiraz", "syrah", "malbec", "cabernet", "merlot", "pinot noir", "nebbiolo", "sangiovese", "tempranillo", "zinfandel", "grenache", "mourvèdre", "petit verdot", "pinotage", "barbera", "gamay"]
        let whiteGrapes = ["chardonnay", "sauvignon", "pinot grigio", "pinot gris", "riesling", "viognier", "albariño", "grüner", "vermentino", "chenin", "moscato", "gewurztraminer"]
        let roseGrapes = ["rosé", "rose", "rosado", "blush", "grenache rosé"]
        let sparklingNames = ["prosecco", "champagne", "cava", "crémant", "sparkling", "brut", "sec", "extra dry"]
        
        if !vari.isEmpty {
            if redGrapes.contains(where: { vari.contains($0) }) { return "Red" }
            if whiteGrapes.contains(where: { vari.contains($0) }) { return "White" }
            if roseGrapes.contains(where: { vari.contains($0) }) { return "Rose" }
        }
        
        if !n.isEmpty {
            if sparklingNames.contains(where: { n.contains($0) }) { return "Sparkling" }
            if n.contains("orange wine") || n.contains("orange wine") { return "Orange" }
            if n.contains("rosé") || n.contains("rose ") || n.contains("rosado") { return "Rose" }
            if redGrapes.contains(where: { n.contains($0) }) { return "Red" }
            if whiteGrapes.contains(where: { n.contains($0) }) { return "White" }
        }
        
        return "Other"
    }
    
    /// Resolve from Wine model.
    static func resolve(wine: Wine) -> String {
        resolve(category: wine.category, variety: wine.variety, name: wine.name)
    }
}
