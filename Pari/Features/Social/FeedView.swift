//
//  FeedView.swift
//  Pari
//
//  Global / Following tabs, LazyVStack feed, minimalist header.
//

import SwiftUI

/// Identifiable item for profile sheet. Unique id per tap so sheet/VM never reuse.
private struct ProfileSheetItem: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let username: String
    init(userId: UUID, username: String) {
        self.id = UUID()
        self.userId = userId
        self.username = username
    }
}

struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FeedViewModel()
    @State private var profileSheetItem: ProfileSheetItem?
    @State private var currentUserId: UUID?

    var body: some View {
        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .task {
                viewModel.loadFromCache()
                viewModel.subscribeRealtime()
                Task { await viewModel.refresh() }
                AnalyticsService.feedView()
            }
            .onDisappear { viewModel.unsubscribeRealtime() }
            .onReceive(NotificationCenter.default.publisher(for: .pariProfileUpdated)) { _ in
                viewModel.patchCurrentUserOverrides()
            }
            .navigationDestination(item: $profileSheetItem) { item in
                profileNavigationContent(for: item)
            }
            .task { currentUserId = await AuthService.currentUserId() }
            .onReceive(NotificationCenter.default.publisher(for: .pariWishlistUpdated)) { _ in
                Task { await viewModel.refreshWishlistIds() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pariTastingCreated)) { _ in
                Task { await viewModel.refresh() }
            }
    }

    private var mainContent: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                tabBar
                feedContent
            }
        }
    }

    @ViewBuilder
    private func profileSheetContent(for item: ProfileSheetItem) -> some View {
        UserProfileView(userId: item.userId, onDismiss: { profileSheetItem = nil }) {
            Task { await viewModel.refresh() }
        }
        #if DEBUG
        .onAppear { print("[FeedView] profile sheet route userId=\(item.userId) username=\(item.username)") }
        #endif
    }
    
    @ViewBuilder
    private func profileNavigationContent(for item: ProfileSheetItem) -> some View {
        UserProfileViewContent(userId: item.userId) {
            Task { await viewModel.refresh() }
        }
        #if DEBUG
        .onAppear { print("[FeedView] profile navigation route userId=\(item.userId) username=\(item.username)") }
        #endif
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(.global, label: "Global")
                tabButton(.following, label: "Following")
            }
            Spacer()
            NavigationLink {
                UserDiscoveryView()
            } label: {
                ZStack {
                    Circle()
                        .fill(PariTheme.surfaceElevated(for: colorScheme))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, x: 0, y: 4)
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
                .frame(width: 34, height: 34)
                .accessibilityLabel("Discover people")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: FeedViewModel.Tab, label: String) -> some View {
        let isActive = viewModel.tab == tab
        return Button {
            viewModel.switchTab(to: tab)
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(PariTheme.uiFont(size: 15, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? PariTheme.accent(for: colorScheme) : (colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme)))
                Rectangle()
                    .fill(isActive ? PariTheme.accentWine(for: colorScheme) : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    @ViewBuilder
    private var feedContent: some View {
        if let err = viewModel.errorMessage {
            Text(err)
                .font(PariTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
        } else if viewModel.isRefreshing && viewModel.items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PariTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tab == .following && viewModel.items.isEmpty {
            followingEmptyState
        } else if viewModel.items.isEmpty {
            globalEmptyState
        } else {
            feedList
        }
    }

    private var globalEmptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "wineglass")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundStyle(PariTheme.accentWine(for: colorScheme).opacity(0.25))
                    .padding(.top, 64)
                Text("The evening hasn't started yet.")
                    .font(.system(.title3, design: .serif, weight: .regular))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                Text("Be the first to open a bottle.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var followingEmptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("The best conversations about wine")
                        .font(.system(.body, design: .serif, weight: .regular))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    Text("haven't started yet.")
                        .font(.system(.body, design: .serif, weight: .regular))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    Text("Follow someone with your taste.")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                if !viewModel.suggestedUsers.isEmpty {
                    Text("People you might like")
                        .font(PariTheme.uiFont(size: 13, weight: .semibold))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    ForEach(viewModel.suggestedUsers) { u in
                        Button {
                            profileSheetItem = ProfileSheetItem(userId: u.id, username: u.username)
                        } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let s = u.avatarUrl, let url = URL(string: s) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                                            default: avatarPlaceholder(u)
                                            }
                                        }
                                    } else {
                                        avatarPlaceholder(u)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.fullName ?? u.username)
                                        .font(PariTheme.uiFont(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("@\(u.username)")
                                        .font(PariTheme.uiFont(size: 13))
                                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(PariTheme.elevatedSurface(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func avatarPlaceholder(_ u: SocialService.FollowListUser) -> some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String((u.fullName ?? u.username).prefix(1)).uppercased())
                    .font(PariTheme.uiFont(size: 18, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            )
    }

    private var feedList: some View {
        List {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 0) {
                    if index > 0 && index % 5 == 0 {
                        editorialPause
                    }
                    FeedItemView(
                        item: item,
                        parts: viewModel.statementParts(for: item),
                        onCheers: { Task { await viewModel.cheer(item) } },
                        hasWishlisted: viewModel.isInWishlist(wineId: item.wineId),
                        onWishlistToggle: (viewModel.currentUserId != nil && viewModel.currentUserId != item.userId && !viewModel.hasTasted(wineId: item.wineId)) ? { Task { await viewModel.toggleWishlist(item) } } : nil,
                        trustHint: viewModel.trustHint(for: item),
                        onUsernameTap: {
                            #if DEBUG
                            print("[FeedView] tap profile tappedUserId=\(item.userId) tappedUsername=\(item.username)")
                            #endif
                            profileSheetItem = ProfileSheetItem(userId: item.userId, username: item.username)
                        },
                        onDelete: { Task { await viewModel.deleteFeedItem(item) } },
                        onMute: viewModel.currentUserId != item.userId ? { viewModel.muteUser(item) } : nil,
                        canDelete: viewModel.currentUserId == item.userId,
                        currentUserId: viewModel.currentUserId,
                        hasAlsoRated: viewModel.currentUserId != item.userId && viewModel.hasTasted(wineId: item.wineId),
                        isTasteTwin: viewModel.isTwin(userId: item.userId)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, index > 0 && index % 5 == 0 ? 0 : PariTheme.cardSpacingVertical / 2)
                    .padding(.bottom, PariTheme.cardSpacingVertical / 2)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    private var editorialPause: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PariTheme.border(for: colorScheme))
                .frame(height: 1)
                .padding(.horizontal, 24)
            Spacer()
                .frame(height: 10)
        }
        .padding(.top, 6)
    }
}

#Preview {
    FeedView()
}
