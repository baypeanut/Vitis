//
//  FeedItemView.swift
//  Vitis
//
//  Two Column Classic feed item: quiet luxury, editorial layout.
//

import SwiftUI

private struct WineNavTarget: Identifiable, Hashable {
    let id: UUID
    let wine: Wine
    let activityId: UUID
    let currentUserId: UUID?
    let sourceUserId: UUID
    let sourceContext: String
}

struct FeedItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: FeedItem
    let parts: (before: String, name: String, after: String)
    let onCheers: () -> Void
    var hasWishlisted: Bool = false
    var onWishlistToggle: (() -> Void)? = nil
    var trustHint: String? = nil
    var onUsernameTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onMute: (() -> Void)? = nil
    var canDelete: Bool = false
    var currentUserId: UUID? = nil
    var hasAlsoRated: Bool = false
    var isTasteTwin: Bool = false

    @State private var showTrustHintPopover = false
    @State private var wineNavigationTarget: WineNavTarget?
    @State private var showReportSheet = false

    private var feedShareText: String {
        var text = "@\(item.username) tried \(item.wineName)"
        if let v = item.wineVintage { text = "@\(item.username) tried \(v) \(item.wineName)" }
        if let rating = item.tastingRating {
            text += " — rated \(String(format: "%.1f", rating))/10"
        }
        text += " ✦ vitis.app"
        return text
    }
    
    /// Construct Wine object from FeedItem for navigation.
    private var wine: Wine {
        Wine(
            id: item.wineId,
            name: item.wineName,
            producer: item.wineProducer,
            vintage: item.wineVintage,
            variety: item.wineVariety,
            region: item.wineRegion,
            labelImageURL: item.wineLabelURL,
            category: item.wineCategory
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.activityType == .hadWine {
                headerRow
                twoColumnLayout
                    .padding(.top, 10)
                actionsRow
                    .padding(.top, 8)
            } else {
                legacyContent
            }
        }
        .padding(.vertical, VitisTheme.cardPaddingVertical)
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: VitisTheme.cardCornerRadius)
                .fill(VitisTheme.surface(for: colorScheme))
        )
        .clipShape(RoundedRectangle(cornerRadius: VitisTheme.cardCornerRadius))
        .shadow(
            color: VitisTheme.shadowColor(for: colorScheme),
            radius: colorScheme == .dark ? 0 : 6,
            x: 0,
            y: colorScheme == .dark ? 0 : 2
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDelete, let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            ShareLink(item: feedShareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if canDelete, let onDelete = onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete post", systemImage: "trash")
                }
            } else {
                Button {
                    onMute?()
                } label: {
                    Label("Mute @\(item.username)", systemImage: "speaker.slash")
                }
                Button {
                    showReportSheet = true
                } label: {
                    Label("Report post", systemImage: "flag")
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                contentType: .post,
                contentId: item.id,
                reportedUserId: item.userId,
                isPresented: $showReportSheet
            )
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $wineNavigationTarget) { target in
            SocialWineDetailView(wine: target.wine, hostItem: item, activityId: target.activityId, currentUserId: target.currentUserId)
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    avatar
                    Text("@\(item.username)")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onUsernameTap?()
                }
                Spacer()
            }
            HStack(spacing: 6) {
                if isTasteTwin {
                    twinBadge
                }
                if let hint = trustHint, !hint.isEmpty {
                    trustHintBadge(fullText: hint)
                }
            }
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
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .accessibilityLabel("@\(item.username) profile photo")
        .accessibilityHidden(true)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private var twinBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 9))
            Text("Taste Twin")
                .font(VitisTheme.uiFont(size: 11, weight: .medium))
        }
        .foregroundStyle(VitisTheme.accent(for: colorScheme))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(VitisTheme.accent(for: colorScheme).opacity(0.12))
        .clipShape(Capsule())
    }

    private func trustHintBadge(fullText: String) -> some View {
        HStack(spacing: 4) {
            Text("Often saved")
                .font(VitisTheme.uiFont(size: 11, weight: .medium))
                .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
            Button {
                showTrustHintPopover = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTrustHintPopover) {
                Text(fullText)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: 240)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Trust hint: \(fullText)")
        }
    }
    
    // MARK: - Two Column Layout
    
    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            // LEFT COLUMN: HStack = thumbnail + VStack(producer, wine name, notes, timestamp)
            HStack(alignment: .top, spacing: 8) {
                wineThumbnailSquare(
                    labelURL: item.wineLabelURL,
                    category: item.wineCategory,
                    wineName: item.wineName
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.wineProducer)
                        .font(VitisTheme.uiFont(size: 11, weight: .regular))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(VitisTheme.displayWineName(item.wineName))
                        .font(VitisTheme.wineNameFont(for: colorScheme))
                        .foregroundStyle(colorScheme == .dark ? VitisTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(category: item.wineCategory, wineName: item.wineName, variety: item.wineVariety, debugPostId: item.id))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    if let vintage = item.wineVintage {
                        Text(String(vintage))
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    }
                    if let comment = item.tastingComment, !comment.isEmpty {
                        Text(comment)
                            .font(VitisTheme.uiFont(size: 12).italic())
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .padding(.top, 2)
                    }
                    Text(VitisTheme.compactTimestamp(item.createdAt))
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(colorScheme == .dark ? VitisTheme.textTertiary(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                wineNavigationTarget = WineNavTarget(id: item.id, wine: wine, activityId: item.id, currentUserId: currentUserId, sourceUserId: item.userId, sourceContext: "feed")
            }
            
            // RIGHT COLUMN: rating only (trailing)
            VStack(alignment: .trailing, spacing: 4) {
                if let rating = item.tastingRating {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.1f", rating))
                            .font(colorScheme == .dark ? VitisTheme.ratingFont() : VitisTheme.uiFont(size: 22, weight: .semibold))
                            .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                        if hasAlsoRated {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                        }
                    }
                }
            }
            .frame(width: 80, alignment: .trailing)
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
        let size: CGFloat = 28
        let cornerRadius: CGFloat = 6
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(VitisTheme.secondaryElevated(for: colorScheme))
                .frame(width: size, height: size)
            if let urlString = labelURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    default:
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(WineColorResolver.resolveWineDisplayColor(category: category, wineName: wineName, colorScheme: colorScheme).opacity(0.75))
                    }
                }
                .frame(width: size, height: size)
            } else {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(WineColorResolver.resolveWineDisplayColor(category: category, wineName: wineName, colorScheme: colorScheme).opacity(0.75))
            }
        }
        .frame(width: size, height: size)
    }
    
    
    // MARK: - Actions Row (icon-first, minimal)

    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                onCheers()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.hasCheered ? "wineglass.fill" : "wineglass")
                        .font(.system(size: 13))
                        .foregroundStyle(item.hasCheered ? VitisTheme.accent(for: colorScheme) : VitisTheme.textTertiary(for: colorScheme))
                    if item.cheersCount > 0 {
                        Text("\(item.cheersCount)")
                            .font(VitisTheme.uiFont(size: 12))
                            .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cheers\(item.cheersCount > 0 ? ", \(item.cheersCount)" : "")")
            .accessibilityHint(item.hasCheered ? "Double tap to remove" : "Double tap to cheer")

            if item.activityType == .hadWine, let onWishlist = onWishlistToggle {
                Button {
                    onWishlist()
                } label: {
                    Image(systemName: hasWishlisted ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundStyle(hasWishlisted ? VitisTheme.accent(for: colorScheme) : VitisTheme.textTertiary(for: colorScheme))
                        .contentShape(Rectangle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasWishlisted ? "In wishlist" : "Want to try")
                .accessibilityHint("Double tap to \(hasWishlisted ? "remove from wishlist" : "add to wishlist")")
            }
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
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
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
