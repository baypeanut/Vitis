//
//  PalateStructure.swift
//  Pari
//
//  The WSET Systematic Approach to Tasting, as data. Six ordinal dimensions that
//  describe a wine's structure rather than judging it.
//
//  This is deliberately the standard vocabulary rather than one of our own. It is
//  taught in over 70 countries and 15 languages, so a trained taster already knows
//  the scale, and anyone learning it here is learning something portable.
//

import Foundation

/// One structural dimension of a tasting, on the standard five-point scale.
///
/// The scale is descriptive. High tannin is not better than low tannin, and no
/// part of the app may present it that way.
enum PalateDimension: String, CaseIterable, Sendable {
    case acidity
    case tannin
    case body
    case sweetness
    case aromaIntensity
    case finish

    var label: String {
        switch self {
        case .acidity: return "Acidity"
        case .tannin: return "Tannin"
        case .body: return "Body"
        case .sweetness: return "Sweetness"
        case .aromaIntensity: return "Aroma"
        case .finish: return "Finish"
        }
    }

    /// Endpoint words for the 1 and 5 positions. WSET uses different words per
    /// dimension, and using the right ones is most of what makes the scale legible.
    var endpoints: (low: String, high: String) {
        switch self {
        case .acidity:        return ("Low", "High")
        case .tannin:         return ("Low", "High")
        case .body:           return ("Light", "Full")
        case .sweetness:      return ("Dry", "Sweet")
        case .aromaIntensity: return ("Light", "Pronounced")
        case .finish:         return ("Short", "Long")
        }
    }

    /// Tannin is meaningless on most whites and sparkling wines. Asking anyway
    /// trains people to answer at random, which is worse than not asking.
    func applies(toCategory category: String?) -> Bool {
        guard self == .tannin else { return true }
        let c = (category ?? "").lowercased()
        return c.contains("red") || c.contains("rouge") || c.isEmpty
    }
}

/// A tasting's structural reading. Every dimension is optional, always.
struct PalateStructure: Equatable, Sendable {
    var acidity: Int?
    var tannin: Int?
    var body: Int?
    var sweetness: Int?
    var aromaIntensity: Int?
    var finish: Int?

    static let empty = PalateStructure()

    init(
        acidity: Int? = nil,
        tannin: Int? = nil,
        body: Int? = nil,
        sweetness: Int? = nil,
        aromaIntensity: Int? = nil,
        finish: Int? = nil
    ) {
        self.acidity = acidity
        self.tannin = tannin
        self.body = body
        self.sweetness = sweetness
        self.aromaIntensity = aromaIntensity
        self.finish = finish
    }

    subscript(dimension: PalateDimension) -> Int? {
        get {
            switch dimension {
            case .acidity:        return acidity
            case .tannin:         return tannin
            case .body:           return body
            case .sweetness:      return sweetness
            case .aromaIntensity: return aromaIntensity
            case .finish:         return finish
            }
        }
        set {
            let clamped = newValue.map { min(5, max(1, $0)) }
            switch dimension {
            case .acidity:        acidity = clamped
            case .tannin:         tannin = clamped
            case .body:           body = clamped
            case .sweetness:      sweetness = clamped
            case .aromaIntensity: aromaIntensity = clamped
            case .finish:         finish = clamped
            }
        }
    }

    /// True when nothing has been recorded, so callers can skip sending it entirely.
    var isEmpty: Bool {
        PalateDimension.allCases.allSatisfy { self[$0] == nil }
    }

    /// How many dimensions were answered. Used to show progress without nagging.
    var answeredCount: Int {
        PalateDimension.allCases.reduce(0) { $0 + (self[$1] == nil ? 0 : 1) }
    }
}
