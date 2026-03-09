import SwiftUI
import Foundation

enum VitisTheme {
    // MARK: - Semantic Color Tokens (Light + Dark)
    // Dark mode is intentional, layered, premium - not a dimmed overlay.

    // Light mode base — ivory "Old Money" palette
    private static let lightBackgroundPrimary = Color(red: 0xFA / 255, green: 0xF8 / 255, blue: 0xF5 / 255)  // #FAF8F5 ivory
    private static let lightBackgroundSecondary = Color(red: 0xF0 / 255, green: 0xEB / 255, blue: 0xE3 / 255) // #F0EBE3 warm cream
    private static let lightSurface = Color.white                          // white cards pop on ivory bg
    private static let lightSurfaceElevated = Color.white
    private static let lightSurfaceSelected = Color(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE8 / 255)
    private static let lightBorderSubtle = Color(red: 0xDC / 255, green: 0xD4 / 255, blue: 0xC8 / 255)        // warm border
    private static let lightDivider = Color(red: 0xE4 / 255, green: 0xDD / 255, blue: 0xD4 / 255)             // warm divider
    private static let lightTextPrimary = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0C / 255)
    private static let lightTextSecondary = Color(red: 0x3A / 255, green: 0x3A / 255, blue: 0x45 / 255)
    private static let lightTextTertiary = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x75 / 255)
    private static let lightTextDisabled = Color(white: 0.6)
    private static let lightAccentWine = Color(red: 0x4A / 255, green: 0x0E / 255, blue: 0x0E / 255)
    private static let lightAccentWineHover = Color(red: 0x5A / 255, green: 0x12 / 255, blue: 0x12 / 255)
    private static let lightAccentWineMuted = Color(red: 0x4A / 255, green: 0x0E / 255, blue: 0x0E / 255).opacity(0.5)

    // Dark mode tokens (premium editorial: near-black charcoal, restrained accent)
    // Background: #0E0F11 | Card: #16181C | Divider: #1F1F1F
    private static let darkBackgroundPrimary = Color(red: 0x0E / 255, green: 0x0F / 255, blue: 0x11 / 255)
    private static let darkBackgroundSecondary = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255)
    private static let darkCardSurface = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255)
    private static let darkSurface = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255)
    private static let darkSurfaceElevated = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255)
    private static let darkSurfaceSelected = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255)
    private static let darkDivider = Color(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255)
    private static let darkTextPrimary = Color(red: 0xED / 255, green: 0xED / 255, blue: 0xED / 255)
    private static let darkTextSecondary = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x9A / 255)
    private static let darkTextTertiary = Color(red: 0x6F / 255, green: 0x6F / 255, blue: 0x6F / 255)
    private static let darkTextDisabled = Color(red: 0x6F / 255, green: 0x6F / 255, blue: 0x6F / 255).opacity(0.6)
    private static let darkAccentWine = Color(red: 0x7A / 255, green: 0x1E / 255, blue: 0x2D / 255)
    private static let darkAccentWineSecondary = Color(red: 0xB8 / 255, green: 0x9B / 255, blue: 0x5C / 255)
    private static let darkAccentWineMuted = Color(red: 0x9B / 255, green: 0x4A / 255, blue: 0x55 / 255)
    private static let darkDangerMuted = Color(red: 0x8B / 255, green: 0x35 / 255, blue: 0x3D / 255)
    private static let darkTabBarInactive = Color(red: 0x77 / 255, green: 0x77 / 255, blue: 0x77 / 255)

    // Emerald accent — Taste Twin badge, Reserve List bookmark.
    // Gold tones are already semantically occupied by white/sparkling wine category colors.
    // Deep forest green reads as "premium social signal" (Harrods, heritage) without colliding.
    private static let lightAccentEmerald = Color(red: 0x1E / 255, green: 0x5C / 255, blue: 0x3A / 255)  // #1E5C3A deep forest
    private static let darkAccentEmerald  = Color(red: 0x5B / 255, green: 0xAF / 255, blue: 0x82 / 255)  // #5BAF82 mint emerald

    // Status tokens (shared)
    static let danger = Color(red: 1, green: 0x45 / 255, blue: 0x3A / 255)
    static let success = Color(red: 0x32 / 255, green: 0xD7 / 255, blue: 0x4B / 255)
    static let warning = Color(red: 1, green: 0xD6 / 255, blue: 0x0A / 255)

    // MARK: - Legacy / Alias (for compatibility)
    // Prefer scheme-aware APIs: background(for:), textPrimary(for:), etc.
    static let accent = lightAccentWine
    static let background: Color = lightBackgroundPrimary
    static let secondaryText: Color = lightTextSecondary
    static let tertiaryText: Color = lightTextTertiary
    static let border: Color = lightDivider

    // MARK: - Semantic API (scheme-aware)

    static func backgroundPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackgroundPrimary : lightBackgroundPrimary
    }

    static func backgroundSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackgroundSecondary : lightBackgroundSecondary
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurface : lightSurface
    }

    static func surfaceElevated(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurfaceElevated : lightSurfaceElevated
    }

    static func surfaceSelected(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurfaceSelected : lightSurfaceSelected
    }

    static func borderSubtle(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkDivider : lightBorderSubtle
    }

    static func divider(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkDivider : lightDivider
    }

    /// Muted red for danger zone text. Never use bright red fills.
    static func dangerMuted(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkDangerMuted : Color(red: 0x8B / 255, green: 0x35 / 255, blue: 0x3D / 255)
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTextPrimary : lightTextPrimary
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTextSecondary : lightTextSecondary
    }

    static func textTertiary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTextTertiary : lightTextTertiary
    }

    static func textDisabled(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTextDisabled : lightTextDisabled
    }

    static func accentWine(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWine : lightAccentWine
    }

    static func accentWineHover(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWineMuted : lightAccentWineHover
    }

    /// Muted accent for text only. Never use as background fill.
    static func accentWineMuted(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWineMuted : lightAccentWineMuted
    }

    static func accentOnDark(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWineMuted : lightAccentWine
    }

    /// Wine names only (dark mode). Returns #C9A24D. Light mode uses generic accent for wine when not using WineColorResolver.
    static func wineNameColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWineSecondary : lightAccentWine
    }

    /// Ratings: primary accent, 85% opacity in dark.
    static func ratingColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentWine.opacity(0.85) : lightAccentWine
    }

    /// Tab bar inactive icon. Dark: #777.
    static func tabBarInactiveColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkTabBarInactive : lightTextTertiary
    }

    /// Emerald: Taste Twin badge + Reserve List bookmark. Never use for wine type coloring.
    static func accentEmerald(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkAccentEmerald : lightAccentEmerald
    }

    /// Rating color: standard wine accent. No special treatment for 9.0+ — the number speaks.
    static func ratingColorAdaptive(rating: Double, for scheme: ColorScheme) -> Color {
        ratingColor(for: scheme)
    }

    // Legacy alias kept for any callsites not yet updated.
    static func accentGold(for scheme: ColorScheme) -> Color {
        accentEmerald(for: scheme)
    }

    /// Dark: no glow. Light: subtle shadow.
    static func shadowColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .clear : Color.black.opacity(0.04)
    }

    // MARK: - Adaptive helpers (map to semantic tokens)

    static func background(for scheme: ColorScheme) -> Color {
        backgroundPrimary(for: scheme)
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        textPrimary(for: scheme)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        textSecondary(for: scheme)
    }

    static func tertiaryText(for scheme: ColorScheme) -> Color {
        textTertiary(for: scheme)
    }

    static func border(for scheme: ColorScheme) -> Color {
        divider(for: scheme)
    }

    static func borderStrong(for scheme: ColorScheme) -> Color {
        borderSubtle(for: scheme)
    }

    /// Card / list row surface. Clear hierarchy from background.
    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        surface(for: scheme)
    }

    /// Modals, sheets, tab bar.
    static func secondaryElevated(for scheme: ColorScheme) -> Color {
        surfaceElevated(for: scheme)
    }

    static func profileSectionBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackgroundPrimary : lightSurface
    }

    static func placeholderBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurface : Color(white: 0.94)
    }

    static func tabPillBackground(for scheme: ColorScheme) -> Color {
        surfaceSelected(for: scheme)
    }

    static func accent(for scheme: ColorScheme) -> Color {
        accentWine(for: scheme)
    }

    static func accentSecondary(for scheme: ColorScheme) -> Color {
        accentWine(for: scheme)
    }

    static func accentSoft(for scheme: ColorScheme, opacity: Double = 0.15) -> Color {
        scheme == .dark ? darkAccentWineMuted.opacity(opacity) : lightAccentWine.opacity(0.1)
    }

    /// Tab bar. Dark: lighter, more transparent, never competes with content.
    static func tabBarBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackgroundPrimary.opacity(0.75) : lightBackgroundPrimary
    }

    // MARK: - Typography

    static func producerFont() -> Font {
        .system(.caption, design: .default, weight: .medium)
            .lowercaseSmallCaps()
    }

    static func wineNameFont(weight: Font.Weight = .regular) -> Font {
        .system(.title2, design: .serif, weight: weight)
    }

    /// Wine name font. Dark: medium weight. Light: regular.
    static func wineNameFont(for scheme: ColorScheme) -> Font {
        .system(.title2, design: .serif, weight: scheme == .dark ? .medium : .regular)
    }

    static func detailFont() -> Font {
        .system(.caption, design: .serif, weight: .regular)
    }

    static func titleFont() -> Font {
        .system(.title, design: .serif, weight: .regular)
    }

    /// Rating font. Slightly smaller than wine name, medium weight.
    static func ratingFont() -> Font {
        .system(size: 18, weight: .medium, design: .default)
    }

    static func uiFont(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

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

    private static let shortAbsoluteTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func shortAbsoluteTimestamp(_ date: Date) -> String {
        shortAbsoluteTimestampFormatter.string(from: date)
    }

    static func compactTimestamp(_ date: Date) -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return hours == 1 ? "1 hour ago" : "\(hours) hours ago" }
        let days = Int(seconds / 86400)
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        let weeks = Int(seconds / 604800)
        if weeks < 4 { return weeks == 1 ? "a week ago" : "\(weeks) weeks ago" }
        return compactTimestampFormatter.string(from: date)
    }

    // MARK: - Card System (canonical layout)

    /// Card corner radius. Subtle, consistent.
    static let cardCornerRadius: CGFloat = 10

    /// Card horizontal padding.
    static let cardPaddingHorizontal: CGFloat = 18

    /// Card vertical padding.
    static let cardPaddingVertical: CGFloat = 16

    /// Vertical spacing between cards in lists.
    static let cardSpacingVertical: CGFloat = 12

    static func displayWineName(_ name: String) -> String {
        var s = name
        if s.contains("Cabarnet") { s = s.replacingOccurrences(of: "Cabarnet", with: "Cabernet") }
        return s
    }
}
