//
//  VitisTheme.swift
//  Vitis
//
//  Quiet Luxury: zero clutter, no heavy shadows, corners ≤12pt.
//  Background #FFFFFF, Accent #4A0E0E. Serif for wine names, SF Pro for data.
//

import SwiftUI
import Foundation

enum VitisTheme {
    // MARK: - Colors

    /// #4A0E0E — deep burgundy for highlights and active states. Use sparingly.
    static let accent = Color(red: 0x4A / 255, green: 0x0E / 255, blue: 0x0E / 255)

    /// #FFFFFF — pure white backgrounds.
    static let background = Color.white

    /// Muted gray for secondary text.
    static let secondaryText = Color(white: 0.45)

    /// Subtle border or divider.
    static let border = Color(white: 0.92)

    // MARK: - Typography

    /// Producer: small caps, minimal, understated.
    static func producerFont() -> Font {
        .system(.caption, design: .default, weight: .medium)
            .lowercaseSmallCaps()
    }

    /// Wine name: serif, editorial.
    static func wineNameFont() -> Font {
        .system(.title2, design: .serif, weight: .regular)
    }

    /// Supporting detail (vintage, region, variety).
    static func detailFont() -> Font {
        .system(.caption, design: .serif, weight: .regular)
    }

    /// Section or screen title.
    static func titleFont() -> Font {
        .system(.title, design: .serif, weight: .regular)
    }

    /// SF Pro for UI elements (tabs, buttons, metadata).
    static func uiFont(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Serif for wine producers; maintain editorial look.
    static func producerSerifFont() -> Font {
        .system(.subheadline, design: .serif, weight: .regular)
    }

    // MARK: - Timestamps

    private static let compactTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Compact quiet format, e.g. "Jan 28 · 9:42 PM". Comments, cellar rows.
    static func compactTimestamp(_ date: Date) -> String {
        compactTimestampFormatter.string(from: date)
    }
}
