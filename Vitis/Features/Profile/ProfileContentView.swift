//
//  ProfileContentView.swift
//  Vitis
//
//  Beli-style profile layout: header, Taste Snapshot + Streak/Goal cards, Recent Activity | Taste Profile tabs.
//

import SwiftUI

struct ProfileContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    var viewModel: ProfileViewModel
    var isOwn: Bool
    var isFollowing: Bool
    var isTogglingFollow: Bool = false
    var followError: String?
    var tasteSimilarity: TasteSimilarity?
    var tasteTwins: [TasteTwin] = []
    var onEdit: (() -> Void)?
    var onFollowToggle: (() -> Void)?
    var onSignOut: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onActivityTap: ((FeedItem) -> Void)?
    var onFollowChanged: (() -> Void)?
    var onFollowersTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?
    var onRegionTap: ((String) -> Void)?
    var onGrapeTap: ((String) -> Void)?
    var onRatedTap: (() -> Void)?
    var onWantToTryTap: (() -> Void)?
    var onAddWishlistSearch: (() -> Void)?
    var onWantToTryToggle: ((CellarItem) async -> Void)?
    var onRemoveWishlistItem: ((CellarItem) async -> Void)?
    var onMarkAsTasted: ((CellarItem) -> Void)?
    var onTwinTap: ((UUID) -> Void)?

    enum MainTab: String, CaseIterable { case recentActivity = "Recently"; case tasteProfile = "Taste"; case wantToTry = "Reserve List" }
    enum TasteSubTab: String, CaseIterable { case regions = "Regions"; case grapes = "Grapes" }

    @State private var mainTab: MainTab = .recentActivity
    @State private var tasteSubTab: TasteSubTab = .regions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let err = viewModel.errorMessage, !viewModel.isLoading {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VitisTheme.dangerMuted(for: colorScheme).opacity(0.15))
                }
                if let p = viewModel.profile {
                    header(p)
                    tasteSnapshotCard(p)
                    if isOwn, !tasteTwins.isEmpty {
                        WineTwinsView(
                            userId: viewModel.userId,
                            twins: tasteTwins,
                            onTwinTap: onTwinTap
                        )
                    }
                    tabs
                    tabContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func wantToTrySearchBar(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                Text("Search wines to add")
                    .font(VitisTheme.uiFont(size: 16))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(VitisTheme.secondaryElevated(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    private func header(_ p: Profile) -> some View {
        VStack(spacing: 12) {
            avatar(p)
            HStack(spacing: 8) {
                Text("@\(p.username)")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                if let h = p.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
                    InstagramIconButton(handle: h)
                }
            }
            if let b = p.bioTrimmed, !b.isEmpty {
                Text(b)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            statsRow
            if !isOwn {
                primaryButton(p)
                if let sim = tasteSimilarity {
                    TasteTwinBadge(similarity: sim)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VitisTheme.profileSectionBackground(for: colorScheme))
        )
    }

    private func avatar(_ p: Profile) -> some View {
        Group {
            if let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(p)
                    }
                }
            } else {
                avatarPlaceholder(p)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ p: Profile) -> some View {
        Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(p.displayName.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 32, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            Button {
                onRatedTap?()
            } label: {
                statItem(value: "\(viewModel.ratedCount)", label: "Rated")
            }
            .buttonStyle(.plain)
            Button {
                onFollowersTap?()
            } label: {
                statItem(value: "\(viewModel.followersCount)", label: "Followers")
            }
            .buttonStyle(.plain)
            Button {
                onFollowingTap?()
            } label: {
                statItem(value: "\(viewModel.followingCount)", label: "Following")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
            Text(label)
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
        }
    }

    private func primaryButton(_ p: Profile) -> some View {
        Group {
            if isGuestProfile(p) {
                Text("User not found")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            } else {
                VStack(spacing: 4) {
                    Button {
                        onFollowToggle?()
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(isFollowing ? VitisTheme.secondaryText(for: colorScheme) : .white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(isFollowing ? VitisTheme.placeholderBackground(for: colorScheme) : VitisTheme.accent(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isTogglingFollow)
                    if let e = followError {
                        Text(e)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func isGuestProfile(_ p: Profile) -> Bool {
        p.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "guest"
    }


    private func tasteSnapshotCard(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 8) {
                tasteSnapshotBox(
                    icon: "heart.fill",
                    value: TasteSnapshotOptions.labelForLoves(id: p.tasteSnapshotLoves)
                )
                tasteSnapshotBox(
                    icon: "hand.thumbsdown.fill",
                    value: TasteSnapshotOptions.labelForAvoids(id: p.tasteSnapshotAvoids)
                )
                tasteSnapshotBox(
                    icon: "face.smiling.fill",
                    value: TasteSnapshotOptions.labelForMood(id: p.tasteSnapshotMood)
                )
            }
        }
    }
    
    @ViewBuilder
    private func tasteSnapshotBox(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
            Text(value)
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(VitisTheme.surfaceElevated(for: colorScheme))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VitisTheme.divider(for: colorScheme), lineWidth: 1))
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mainTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(VitisTheme.uiFont(size: 15, weight: .regular))
                        .foregroundStyle(mainTab == tab ? (colorScheme == .dark ? VitisTheme.accentWine(for: colorScheme) : VitisTheme.textPrimary(for: colorScheme)) : (colorScheme == .dark ? VitisTheme.textTertiary(for: colorScheme) : VitisTheme.textSecondary(for: colorScheme)))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(VitisTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch mainTab {
        case .recentActivity:
            recentActivityList
        case .tasteProfile:
            tasteProfileContent
        case .wantToTry:
            wantToTryTabContent
        }
    }

    @ViewBuilder
    private var wantToTryTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isOwn, let onSearch = onAddWishlistSearch {
                wantToTrySearchBar(onTap: onSearch)
            }
            if !viewModel.wishlistVisible {
                Text("Wishlist is visible to friends.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else if viewModel.wishlistPreview.isEmpty {
                Text(isOwn
                    ? "No wines saved yet. Tap the bookmark on any feed post to add."
                    : "No wines in their list.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(viewModel.wishlistPreview.prefix(5))) { item in
                    wantToTryRow(item, onRemove: isOwn ? { item in Task { await onRemoveWishlistItem?(item) } } : nil)
                    Rectangle().fill(VitisTheme.border(for: colorScheme)).frame(height: 1).padding(.leading, 0)
                }
                if let onTap = onWantToTryTap {
                    Button {
                        onTap()
                    } label: {
                        Text("Open full list")
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(VitisTheme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func wantToTryRow(_ item: CellarItem, onRemove: ((CellarItem) -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.wine.producer)
                    .font(colorScheme == .dark ? VitisTheme.uiFont(size: 13, weight: .regular) : VitisTheme.producerSerifFont())
                    .foregroundStyle(colorScheme == .dark ? VitisTheme.textTertiary(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                Text(VitisTheme.displayWineName(item.wine.name))
                    .font(VitisTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(colorScheme == .dark ? VitisTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: item.wine))
                if let r = item.wine.region, !r.isEmpty {
                    Text(r)
                        .font(VitisTheme.uiFont(size: 12))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isOwn {
                Button("Mark as Tasted") {
                    onMarkAsTasted?(item)
                }
                .font(VitisTheme.uiFont(size: 14, weight: .medium))
                .foregroundStyle(VitisTheme.accent(for: colorScheme))
            } else if let onToggle = onWantToTryToggle {
                Button {
                    Task { await onToggle(item) }
                } label: {
                    Image(systemName: viewModel.myWishlistWineIds.contains(item.wineId) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.myWishlistWineIds.contains(item.wineId) ? VitisTheme.accent(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if isOwn, onMarkAsTasted != nil {
                Button {
                    onMarkAsTasted?(item)
                } label: {
                    Label("Tasted", systemImage: "checkmark.circle")
                }
                .tint(VitisTheme.accent(for: colorScheme))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var recentActivityList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.activityVisible {
                Text("Activity is visible to friends.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else if viewModel.recentTastingsTop5.isEmpty {
                Text("No tastings yet.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.recentTastingsTop5) { tasting in
                    tastingActivityRow(tasting)
                    Rectangle().fill(VitisTheme.border(for: colorScheme)).frame(height: 1).padding(.leading, 0)
                }
            }
        }
    }

    private func tastingActivityRow(_ tasting: Tasting) -> some View {
        let wine = tasting.wine.vintage.map { "\($0) \(tasting.wine.name)" } ?? tasting.wine.name
        let cheersCount = viewModel.tastingCheersCounts[tasting.id] ?? 0
        return NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: viewModel.userId, sourceUserId: viewModel.userId, sourceContext: "profile")) {
            HStack(alignment: .top, spacing: 12) {
                cellarAvatarCircle()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tasting.wine.producer)
                                .font(colorScheme == .dark ? VitisTheme.uiFont(size: 13, weight: .regular) : VitisTheme.producerSerifFont())
                                .foregroundStyle(colorScheme == .dark ? VitisTheme.textTertiary(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                            Text(wine)
                                .font(VitisTheme.wineNameFont(for: colorScheme))
                                .foregroundStyle(colorScheme == .dark ? VitisTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                        }
                        Spacer(minLength: 8)
                        Text(String(format: "%.1f", tasting.rating))
                            .font(colorScheme == .dark ? VitisTheme.ratingFont() : VitisTheme.uiFont(size: 18, weight: .semibold))
                            .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                    }
                    
                    if let comment = tasting.comment, !comment.isEmpty {
                        Text(comment)
                            .font(VitisTheme.uiFont(size: 12).italic())
                            .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        if cheersCount > 0 {
                            HStack(spacing: 4) {
                                Text("\(cheersCount)")
                                    .font(VitisTheme.uiFont(size: 11))
                                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                                Image(systemName: "wineglass.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                            }
                        }
                        Text(VitisTheme.compactTimestamp(tasting.createdAt))
                            .font(VitisTheme.uiFont(size: 12))
                            .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func recentActivityRow(_ item: FeedItem) -> some View {
        let parts = item.statementParts()
        return HStack(alignment: .top, spacing: 12) {
            avatarCircle(item)
            (Text(parts.before)
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(colorScheme == .dark ? VitisTheme.textPrimary(for: colorScheme) : .primary)
            + Text(parts.name)
                .font(VitisTheme.wineNameFont(for: colorScheme))
                .foregroundStyle(colorScheme == .dark ? VitisTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(category: item.wineCategory, wineName: item.wineName, variety: item.wineVariety, debugPostId: item.id))
            + Text(parts.after)
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(colorScheme == .dark ? VitisTheme.textPrimary(for: colorScheme) : .primary))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onActivityTap?(item) }
    }

    private func cellarAvatarCircle() -> some View {
        Group {
            if let p = viewModel.profile, let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: cellarAvatarPlaceholder()
                    }
                }
            } else {
                cellarAvatarPlaceholder()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private func cellarAvatarPlaceholder() -> some View {
        Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(viewModel.profile?.displayName.prefix(1) ?? "U").uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func avatarCircle(_ item: FeedItem) -> some View {
        Group {
            if let u = item.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: circlePlaceholder(item)
                    }
                }
            } else {
                circlePlaceholder(item)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func circlePlaceholder(_ item: FeedItem) -> some View {
        Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private var tasteProfileContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                ForEach(TasteSubTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tasteSubTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(VitisTheme.surfaceElevated(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(tasteSubTab == tab ? VitisTheme.accentWine(for: colorScheme) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            tasteProfileList
        }
    }

    @ViewBuilder
    private var tasteProfileList: some View {
        let items: [TasteProfileItem] = {
            switch tasteSubTab {
            case .regions: return viewModel.tasteRegions
            case .grapes: return viewModel.tasteGrapes
            }
        }()
        if items.isEmpty {
            Text("No data yet. Rate wines to build your taste profile.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { it in
                    tasteProfileRow(it)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tasteSubTab == .regions {
                                onRegionTap?(it.name)
                            } else {
                                onGrapeTap?(it.name)
                            }
                        }
                    Rectangle().fill(VitisTheme.border(for: colorScheme)).frame(height: 1)
                }
            }
        }
    }

    private func tasteProfileRow(_ it: TasteProfileItem) -> some View {
        let nameColor: Color = colorScheme == .dark ? VitisTheme.wineNameColor(for: colorScheme) : (tasteSubTab == .grapes ? WineColorResolver.resolveWineDisplayColor(category: nil, wineName: it.name, variety: it.name) : Color.primary)
        return HStack {
            Text(it.name)
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(nameColor)
            Spacer()
            HStack(spacing: 8) {
                if let avgRating = it.averageRating {
                    Text(String(format: "%.1f", avgRating))
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? VitisTheme.ratingColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(category: nil, wineName: it.name, variety: it.name))
                    Text("·")
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
                }
                Text("\(it.count) \(it.count == 1 ? "tasting" : "tastings")")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.textTertiary(for: colorScheme))
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Instagram icon button (app or Safari)

private struct InstagramIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let handle: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openInstagram(handle: handle)
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func openInstagram(handle: String) {
        let escaped = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        let appURL = URL(string: "instagram://user?username=\(escaped)")
        let webURL = URL(string: "https://www.instagram.com/\(escaped)/")
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let webURL {
            openURL(webURL)
        }
    }
}
