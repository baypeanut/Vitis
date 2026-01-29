//
//  FeedItemView.swift
//  Vitis
//
//  Two Column Classic feed item: quiet luxury, editorial layout.
//

import SwiftUI

struct FeedItemView: View {
    let item: FeedItem
    let parts: (before: String, name: String, after: String)
    let onCheers: () -> Void
    let onComment: () -> Void
    var onUsernameTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var canDelete: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.activityType == .hadWine {
                // Header row: avatar + username + "tasted"
                headerRow
                
                // Two column layout: left = thumbnail + wine identity + notes; right = rating, region, timestamp (10-12pt below header)
                twoColumnLayout
                    .padding(.top, 10)
                
                // Actions row (8-10pt below main block)
                actionsRow
                    .padding(.top, 8)
            } else {
                // Fallback for non-had_wine activities (keep old style)
                legacyContent
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDelete, let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            avatar
            HStack(spacing: 4) {
                Text(item.username)
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.accent)
                Text("tasted")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            Spacer()
        }
    }
    
    private var avatar: some View {
        Group {
            if let urlString = item.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty: avatarPlaceholder
                    @unknown default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .contentShape(Circle())
        .onTapGesture {
            onUsernameTap?()
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }
    
    // MARK: - Two Column Layout
    
    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            // LEFT COLUMN: HStack = thumbnail + VStack(producer, wine name, notes)
            HStack(alignment: .top, spacing: 10) {
                wineThumbnailSquare(
                    labelURL: item.wineLabelURL,
                    category: item.wineCategory,
                    wineName: item.wineName
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.wineProducer)
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                    
                    Text(item.wineName)
                        .font(VitisTheme.wineNameFont())
                        .foregroundStyle(wineNameColor(category: item.wineCategory, wineName: item.wineName))
                    
                    if let vintage = item.wineVintage {
                        Text(String(vintage))
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    
                    if let notes = formattedNotes, !notes.isEmpty {
                        Text(notes)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // RIGHT COLUMN: rating, region, timestamp (trailing)
            VStack(alignment: .trailing, spacing: 4) {
                if let rating = item.tastingRating {
                    Text(String(format: "%.1f", rating))
                        .font(VitisTheme.uiFont(size: 24, weight: .semibold))
                        .foregroundStyle(VitisTheme.accent)
                }
                
                if let region = item.wineRegion, !region.isEmpty {
                    Text(region)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                
                Text(VitisTheme.compactTimestamp(item.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(width: 100, alignment: .trailing)
        }
    }
    
    private var formattedNotes: String? {
        guard let notes = item.contentText, !notes.isEmpty else { return nil }
        let components = notes.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        if components.count <= 3 {
            return notes
        } else {
            let firstThree = components.prefix(3).joined(separator: ", ")
            let remaining = components.count - 3
            return "\(firstThree) +\(remaining)"
        }
    }
    
    /// Small thumbnail (32-36pt) for left column; label image or category icon.
    private func wineThumbnailSquare(labelURL: String?, category: String?, wineName: String?) -> some View {
        let size: CGFloat = 34
        let cornerRadius: CGFloat = 6
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.97))
                .frame(width: size, height: size)
            if let urlString = labelURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    default:
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(thumbnailTint(category: category, wineName: wineName))
                    }
                }
                .frame(width: size, height: size)
            } else {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(thumbnailTint(category: category, wineName: wineName))
            }
        }
        .frame(width: size, height: size)
    }
    
    /// Wine name text color by category; if category is nil/empty, infer from wine name. Used for wine name only.
    private func wineNameColor(category: String?, wineName: String?) -> Color {
        let cat = category?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let name = wineName?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        // First try explicit category
        if !cat.isEmpty {
            if cat.contains("red") || cat.contains("rouge") {
                return Color(red: 0x6B/255, green: 0x0F/255, blue: 0x1A/255) // #6B0F1A
            }
            if cat.contains("white") || cat.contains("blanc") {
                return Color(red: 0x7D/255, green: 0x62/255, blue: 0x20/255) // #7D6220
            }
            if cat.contains("rose") || cat.contains("rosé") {
                return Color(red: 0xB0/255, green: 0x4A/255, blue: 0x6A/255) // #B04A6A
            }
            if cat.contains("orange") {
                return Color(red: 0xB4/255, green: 0x4E/255, blue: 0x1D/255) // #B44E1D
            }
            if cat.contains("sparkling") || cat.contains("prosecco") {
                return Color(red: 0xA8/255, green: 0x95/255, blue: 0x6A/255) // #A8956A
            }
        }
        // Fallback: infer from wine name when category is missing (e.g. API returns nil)
        if !name.isEmpty {
            let redGrapes = ["shiraz", "syrah", "malbec", "cabernet", "merlot", "pinot noir", "nebbiolo", "sangiovese", "tempranillo", "zinfandel", "grenache", "mourvèdre", "petit verdot"]
            let whiteGrapes = ["chardonnay", "sauvignon", "pinot grigio", "pinot gris", "riesling", "viognier", "albariño", "grüner", "vermentino", "chenin"]
            let sparklingNames = ["prosecco", "champagne", "cava", "crémant", "sparkling", "brut", "sec"]
            let roseNames = ["rosé", "rose", "rosado", "blush"]
            if redGrapes.contains(where: { name.contains($0) }) {
                return Color(red: 0x6B/255, green: 0x0F/255, blue: 0x1A/255)
            }
            if whiteGrapes.contains(where: { name.contains($0) }) {
                return Color(red: 0x7D/255, green: 0x62/255, blue: 0x20/255)
            }
            if sparklingNames.contains(where: { name.contains($0) }) {
                return Color(red: 0xA8/255, green: 0x95/255, blue: 0x6A/255)
            }
            if roseNames.contains(where: { name.contains($0) }) {
                return Color(red: 0xB0/255, green: 0x4A/255, blue: 0x6A/255)
            }
        }
        return .primary
    }
    
    /// Thumbnail icon tint; uses same category/name logic as wine name color, with opacity.
    private func thumbnailTint(category: String?, wineName: String?) -> Color {
        wineNameColor(category: category, wineName: wineName).opacity(0.75)
    }
    
    // MARK: - Actions Row
    
    private var actionsRow: some View {
        HStack(spacing: 24) {
            Button {
                onCheers()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.hasCheered ? "wineglass.fill" : "wineglass")
                        .font(.system(size: 14))
                        .foregroundStyle(item.hasCheered ? VitisTheme.accent : VitisTheme.secondaryText)
                    Text("Cheers")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(item.hasCheered ? VitisTheme.accent : VitisTheme.secondaryText)
                    if item.cheersCount > 0 {
                        Text("\(item.cheersCount)")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                onComment()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14))
                    Text("Comment")
                        .font(VitisTheme.uiFont(size: 13))
                    if item.commentCount > 0 {
                        Text("\(item.commentCount)")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                .foregroundStyle(VitisTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Legacy Content (for non-had_wine activities)
    
    private var legacyContent: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 12) {
                (Text(parts.before)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(.primary)
                + Text(parts.name)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(VitisTheme.accent)
                + Text(parts.after)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(.primary))
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    onUsernameTap?()
                }
                actionsRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
