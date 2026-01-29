//
//  TastingNotes.swift
//  Vitis
//
//  Category-based tasting notes (aromas/flavors). Curated sets for Red, White, Rose, Sparkling.
//

import Foundation

enum TastingNotes {
    static func notesForCategory(_ category: String?) -> [String] {
        guard let cat = category?.lowercased() else { return defaultNotes }
        if cat.contains("red") || cat.contains("rouge") {
            return redNotes
        } else if cat.contains("white") || cat.contains("blanc") {
            return whiteNotes
        } else if cat.contains("rose") || cat.contains("rosé") {
            return roseNotes
        } else if cat.contains("sparkling") {
            return sparklingNotes
        }
        return defaultNotes
    }

    static let redNotes = [
        "Blackberry", "Cherry", "Plum", "Leather", "Tobacco", "Vanilla", "Spice", "Oak", "Blackcurrant", "Earthy"
    ]

    static let whiteNotes = [
        "Citrus", "Apple", "Pear", "Stone fruit", "Mineral", "Vanilla", "Honey", "Tropical", "Herbaceous", "Crisp"
    ]

    static let roseNotes = [
        "Strawberry", "Melon", "Floral", "Citrus", "Red fruit", "Herbal", "Mineral", "Fresh"
    ]

    static let sparklingNotes = [
        "Brioche", "Apple", "Citrus", "Mineral", "Yeast", "Pear", "Almond", "Creamy"
    ]

    static let defaultNotes = [
        "Fruity", "Floral", "Earthy", "Spicy", "Mineral", "Herbal", "Oak", "Vanilla"
    ]
}
