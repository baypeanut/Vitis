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

    /// Tertiary/muted text for low-emphasis elements (e.g. timestamps).
    static let tertiaryText = Color(white: 0.58)

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
        f.dateFormat = "MMM d, yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Absolute short format for comments and quiet UI: "Jan 28 · 9:42 PM"
    private static let shortAbsoluteTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Absolute short timestamp: "Jan 28 · 9:42 PM". Use for comments and minimal date/time.
    static func shortAbsoluteTimestamp(_ date: Date) -> String {
        shortAbsoluteTimestampFormatter.string(from: date)
    }

    /// Relative time format: "5 minutes ago", "1 hour ago", "a week ago", or full date if too old.
    static func compactTimestamp(_ date: Date) -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        
        // Less than a minute
        if seconds < 60 {
            return "just now"
        }
        
        // Less than an hour
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        
        // Less than a day
        let hours = Int(seconds / 3600)
        if hours < 24 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        
        // Less than a week
        let days = Int(seconds / 86400)
        if days < 7 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        
        // Less than 4 weeks
        let weeks = Int(seconds / 604800)
        if weeks < 4 {
            return weeks == 1 ? "a week ago" : "\(weeks) weeks ago"
        }
        
        // More than 4 weeks, show full date
        return compactTimestampFormatter.string(from: date)
    }

    /// Fix common wine name typos for display.
    static func displayWineName(_ name: String) -> String {
        var s = name
        if s.contains("Cabarnet") { s = s.replacingOccurrences(of: "Cabarnet", with: "Cabernet") }
        return s
    }
}
