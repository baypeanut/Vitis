//
//  SocialWineDetailView.swift
//  Vitis
//
//  Social Wine Detail: rating dashboard, grouped reviews.
//

import SwiftUI

struct SocialWineDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let wine: Wine
    let hostItem: FeedItem
    let activityId: UUID
    let currentUserId: UUID?

    @State private var hostReview: SocialReview
    @State private var userRating: Double?
    @State private var userTasting: Tasting?
    @State private var twinRating: TwinWeightedRating?
    @State private var groupedMutual: [GroupedFriendReview] = []
    @State private var isLoading = true
    @State private var hasCheered: Bool
    @State private var cheersCount: Int
    @State private var hasWishlisted = false
    @State private var isCheering = false
    @State private var isWishlisting = false
    @State private var alreadyTastedToast = false

    init(wine: Wine, hostItem: FeedItem, activityId: UUID, currentUserId: UUID?) {
        self.wine = wine
        self.hostItem = hostItem
        self.activityId = activityId
        self.currentUserId = currentUserId
        self._hasCheered = State(initialValue: hostItem.hasCheered)
        self._cheersCount = State(initialValue: hostItem.cheersCount)
        self._hostReview = State(initialValue: Self.makeHostReview(from: hostItem))
    }

    private static func makeHostReview(from item: FeedItem) -> SocialReview {
        let tags = (item.contentText?.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }) ?? []
        return SocialReview(
            id: item.id,
            userId: item.userId,
            displayName: item.username,
            avatarURL: item.avatarURL,
            rating: item.tastingRating ?? 0,
            comment: item.tastingComment?.isEmpty == false ? item.tastingComment : nil,
            tasteTags: tags,
            createdAt: item.createdAt
        )
    }

    private var wineColor: Color {
        WineColorResolver.resolveWineDisplayColor(wine: wine, colorScheme: colorScheme)
    }

    private var shareText: String {
        var parts: [String] = []
        if !wine.producer.isEmpty { parts.append(wine.producer) }
        parts.append(wine.name)
        if let v = wine.vintage, v > 0 { parts.append(String(v)) }
        let wineTitle = parts.joined(separator: " ")
        var text = "Just tried \(wineTitle) on Vitis"
        if let rating = hostReview.rating > 0 ? hostReview.rating : nil {
            text += " — rated \(String(format: "%.1f", rating))/10"
        }
        text += " ✦ vitis.app"
        return text
    }

    /// Wine title with optional vintage (e.g. "Sancerre 2022"). No placeholder if vintage nil/0.
    private var wineTitleWithVintage: String {
        if let v = wine.vintage, v > 0 {
            return "\(VitisTheme.displayWineName(wine.name)) \(v)"
        }
        return VitisTheme.displayWineName(wine.name)
    }

    var body: some View {
        ZStack {
            VitisTheme.background(for: colorScheme).ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(VitisTheme.accent(for: colorScheme))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        headerSection
                        ratingDashboardSection
                        hostReviewSection
                        userReviewSection
                        if !groupedMutual.isEmpty {
                            mutualSection
                        }
                        Spacer(minLength: 60)
                    }
                }
                VStack {
                    Spacer()
                    cheersBar
                }
                .allowsHitTesting(true)
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                }
            }
        }
        .task { await loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .vitisWishlistUpdated)) { _ in
            Task { await refreshWishlist() }
        }
        .overlay(alignment: .center) {
            if alreadyTastedToast {
                Text("You've already tasted this wine")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(VitisTheme.secondaryElevated(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: alreadyTastedToast)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(wineTitleWithVintage)
                .font(VitisTheme.wineNameFont(for: colorScheme))
                .foregroundStyle(wineColor)
            HStack(spacing: 8) {
                if !wine.producer.isEmpty {
                    Text(wine.producer)
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }
                if let region = wine.region, !region.isEmpty {
                    Text(region)
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
                }
            }
            if currentUserId != nil {
                wishlistButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var wishlistButton: some View {
        Button {
            Task { await toggleWishlist() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasWishlisted ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14))
                Text(hasWishlisted ? "Saved" : "Save to Reserve List")
                    .font(VitisTheme.uiFont(size: 14))
            }
            .foregroundStyle(hasWishlisted ? VitisTheme.accent(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
        .disabled(isWishlisting)
        .padding(.top, 4)
    }

    // MARK: - Rating Dashboard

    private var ratingDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(VitisTheme.divider(for: colorScheme))
                .frame(height: 1)
            HStack(spacing: 0) {
                ratingColumn(label: "You", value: userRating)
                ratingColumn(label: "Twins", value: twinRating?.twinWeightedAvg, count: twinRating?.twinCount)
                ratingColumn(label: "Global", value: twinRating?.communityAvg, count: twinRating?.communityCount)
            }
        }
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .padding(.vertical, 12)
    }

    private func ratingColumn(label: String, value: Double?, count: Int? = nil) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
            Text(value != nil ? String(format: "%.1f", value!) : "\u{2014}")
                .font(VitisTheme.ratingFont())
                .foregroundStyle(value != nil ? VitisTheme.ratingColor(for: colorScheme) : VitisTheme.textTertiary(for: colorScheme))
            if let count, count > 0 {
                Text("\(count)")
                    .font(VitisTheme.uiFont(size: 11))
                    .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Host Review

    private var hostReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(VitisTheme.divider(for: colorScheme))
                .frame(height: 1)
            HStack(alignment: .top, spacing: 12) {
                reviewAvatar(url: hostReview.avatarURL, displayName: hostReview.displayName, size: 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(hostReview.displayName)
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                        Text(String(format: "%.1f", hostReview.rating))
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                    }
                    if let comment = hostReview.comment, !comment.isEmpty {
                        Text(comment)
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !hostReview.tasteTags.isEmpty {
                        tasteTagsPills(hostReview.tasteTags)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .padding(.vertical, 14)
    }

    // MARK: - User Review (current user's rate, palate, comment)

    @ViewBuilder
    private var userReviewSection: some View {
        if let t = userTasting, currentUserId != hostItem.userId {
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(VitisTheme.divider(for: colorScheme))
                    .frame(height: 1)
                HStack(alignment: .top, spacing: 12) {
                    reviewAvatar(url: nil, displayName: "You", size: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("You")
                                .font(VitisTheme.uiFont(size: 14, weight: .medium))
                                .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                            Text(String(format: "%.1f", t.rating))
                                .font(VitisTheme.uiFont(size: 14, weight: .medium))
                                .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                        }
                        if let comment = t.comment, !comment.isEmpty {
                            Text(comment)
                                .font(VitisTheme.uiFont(size: 14))
                                .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let tags = t.noteTags, !tags.isEmpty {
                            tasteTagsPills(tags)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Mutual Section (grouped, with full cards vs compact quick ratings)

    private var mutualSection: some View {
        let withComment = groupedMutual.filter { $0.hasComment }
        let quickOnly = groupedMutual.filter { !$0.hasComment }
        return VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(VitisTheme.divider(for: colorScheme))
                .frame(height: 1)
            Text("Also tasted by")
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
            if !quickOnly.isEmpty {
                quickRatingsRow(quickOnly)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(withComment) { grouped in
                    fullMutualRow(grouped)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func quickRatingsRow(_ items: [GroupedFriendReview]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { g in
                    HStack(spacing: 6) {
                        reviewAvatar(url: g.avatarURL, displayName: g.displayName, size: 28)
                        Text(String(format: "%.1f", g.primaryReview.rating))
                            .font(VitisTheme.uiFont(size: 13, weight: .medium))
                            .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(VitisTheme.placeholderBackground(for: colorScheme))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        }
        .padding(.vertical, 8)
    }

    private func fullMutualRow(_ grouped: GroupedFriendReview) -> some View {
        let r = grouped.primaryReview
        return HStack(alignment: .top, spacing: 12) {
            reviewAvatar(url: grouped.avatarURL, displayName: grouped.displayName, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(grouped.displayName)
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    if grouped.additionalCount > 0 {
                        Text("+\(grouped.additionalCount) more")
                            .font(VitisTheme.uiFont(size: 11))
                            .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
                    }
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f", r.rating))
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.ratingColor(for: colorScheme))
                    Text(relativeTime(r.createdAt))
                        .font(VitisTheme.uiFont(size: 11))
                        .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
                }
                if let comment = r.comment, !comment.isEmpty {
                    Text(comment)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                if !r.tasteTags.isEmpty {
                    tasteTagsPills(Array(r.tasteTags.prefix(3)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .padding(.vertical, 10)
    }

    private var cheersBar: some View {
        CheersButton(
            hasCheered: hasCheered,
            count: cheersCount,
            isDisabled: currentUserId == nil || isCheering,
            colorScheme: colorScheme,
            onTap: { Task { await toggleCheers() } }
        )
        .padding(.horizontal, VitisTheme.cardPaddingHorizontal)
        .padding(.vertical, 12)
        .background(VitisTheme.background(for: colorScheme).opacity(0.95))
    }

    private func reviewAvatar(url: String?, displayName: String, size: CGFloat) -> some View {
        Group {
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(displayName: displayName, size: size)
                    }
                }
            } else {
                avatarPlaceholder(displayName: displayName, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(displayName name: String, size: CGFloat) -> some View {
        let initial = name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
        let fontSize = max(11, min(size * 0.45, 18))
        return Circle()
            .fill(VitisTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(initial)
                    .font(VitisTheme.uiFont(size: fontSize, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private func tasteTagsPills(_ tags: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(VitisTheme.uiFont(size: 11))
                    .foregroundStyle(wineColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(wineColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        VitisTheme.compactTimestamp(date)
    }

    // MARK: - Data & Grouping

    private func loadData() async {
        isLoading = true
        let hostId = hostItem.userId
        do {
            let allTastings = try await WineService.fetchTastingsForWine(wineId: wine.id, excludeUserId: nil, limit: 100)
            var mutual: [TastingWithProfile] = []
            for t in allTastings {
                if t.userId != hostId, t.userId != currentUserId, await ProfileService.isMutualFriend(viewerId: hostId, ownerId: t.userId) {
                    mutual.append(t)
                }
            }
            mutual.sort { $0.createdAt > $1.createdAt }

            groupedMutual = Self.groupByUser(mutual)
            twinRating = await TasteSimilarityService.fetchTwinWeightedRating(wineId: wine.id)

            if let uid = currentUserId {
                let t = try? await TastingService.fetchUserTastingForWine(userId: uid, wineId: wine.id)
                userTasting = t
                userRating = t?.rating
            } else {
                userTasting = nil
                userRating = nil
            }
        } catch {
            groupedMutual = []
        }
        await refreshWishlist()
        isLoading = false
    }

    private static func groupByUser(_ tastings: [TastingWithProfile]) -> [GroupedFriendReview] {
        let byUser = Dictionary(grouping: tastings) { $0.userId }
        return byUser.compactMap { userId, list -> GroupedFriendReview? in
            guard !list.isEmpty else { return nil }
            let sorted = list.sorted { $0.createdAt > $1.createdAt }
            let withComment = sorted.first { ($0.comment?.isEmpty ?? true) == false }
            let primary = withComment ?? sorted.first!
            let review = SocialReview(
                id: primary.id,
                userId: primary.userId,
                displayName: primary.displayName,
                avatarURL: primary.avatarURL,
                rating: primary.rating,
                comment: primary.comment,
                tasteTags: primary.noteTags ?? [],
                createdAt: primary.createdAt
            )
            return GroupedFriendReview(
                userId: userId,
                displayName: primary.displayName,
                avatarURL: primary.avatarURL,
                primaryReview: review,
                additionalCount: list.count - 1
            )
        }
        .sorted { $0.primaryReview.createdAt > $1.primaryReview.createdAt }
    }

    private func toggleCheers() async {
        guard currentUserId != nil, !isCheering else { return }
        isCheering = true
        let prevCheered = hasCheered
        let prevCount = cheersCount
        hasCheered = !hasCheered
        cheersCount = prevCheered ? max(0, cheersCount - 1) : cheersCount + 1
        do {
            try await SocialService.toggleLike(activityID: activityId)
        } catch {
            hasCheered = prevCheered
            cheersCount = prevCount
        }
        isCheering = false
    }

    private func toggleWishlist() async {
        guard let uid = currentUserId, !isWishlisting else { return }
        isWishlisting = true
        defer { isWishlisting = false }
        if hasWishlisted {
            let wasIn = true
            hasWishlisted = false
            do {
                try await CellarService.removeFromWishlist(wineId: wine.id)
                NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
            } catch {
                hasWishlisted = wasIn
            }
            return
        }
        if await TastingService.hasTasted(userId: uid, wineId: wine.id) {
            alreadyTastedToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                alreadyTastedToast = false
            }
            return
        }
        hasWishlisted = true
        do {
            try await CellarService.addToWishlist(wineId: wine.id, sourceUserId: hostItem.userId, sourceContext: "feed")
            NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
        } catch {
            hasWishlisted = false
        }
    }

    private func refreshWishlist() async {
        guard let uid = currentUserId else { return }
        hasWishlisted = (try? await CellarService.fetchWishlistWineIds(userId: uid))?.contains(wine.id) ?? false
    }
}

// MARK: - Cheers Button

private struct CheersButton: View {
    let hasCheered: Bool
    let count: Int
    let isDisabled: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: hasCheered ? "wineglass.fill" : "wineglass")
                    .font(.system(size: 16))
                Text("Cheers")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.tertiaryText(for: colorScheme))
                }
            }
            .foregroundStyle(hasCheered ? VitisTheme.accent(for: colorScheme) : VitisTheme.textSecondary(for: colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(VitisTheme.placeholderBackground(for: colorScheme))
            .clipShape(Capsule())
        }
        .buttonStyle(CheersPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
    }
}

private struct CheersPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// FlowLayout extracted to Vitis/Utilities/FlowLayout.swift
