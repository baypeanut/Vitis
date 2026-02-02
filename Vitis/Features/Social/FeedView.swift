//
//  FeedView.swift
//  Vitis
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
            .onReceive(NotificationCenter.default.publisher(for: .vitisProfileUpdated)) { _ in
                viewModel.patchCurrentUserOverrides()
            }
            .navigationDestination(item: $profileSheetItem) { item in
                profileNavigationContent(for: item)
            }
            .task { currentUserId = await AuthService.currentUserId() }
            .onReceive(NotificationCenter.default.publisher(for: .vitisWishlistUpdated)) { _ in
                Task { await viewModel.refreshWishlistIds() }
            }
    }

    private var mainContent: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
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
            tabButton(.global, label: "Global")
            tabButton(.following, label: "Following")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func tabButton(_ tab: FeedViewModel.Tab, label: String) -> some View {
        Button {
            viewModel.switchTab(to: tab)
        } label: {
            Text(label)
                .font(VitisTheme.uiFont(size: 15, weight: viewModel.tab == tab ? .semibold : .regular))
                .foregroundStyle(viewModel.tab == tab ? VitisTheme.accent : VitisTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var feedContent: some View {
        if let err = viewModel.errorMessage {
            Text(err)
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
        } else if viewModel.isRefreshing && viewModel.items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitisTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tab == .following && viewModel.items.isEmpty {
            followingEmptyState
        } else {
            feedList
        }
    }
    
    private var followingEmptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Follow people to see their tastings here.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if !viewModel.suggestedUsers.isEmpty {
                    Text("People you might like")
                        .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                        .foregroundStyle(VitisTheme.secondaryText)
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
                                        .font(VitisTheme.uiFont(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("@\(u.username)")
                                        .font(VitisTheme.uiFont(size: 13))
                                        .foregroundStyle(VitisTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(VitisTheme.secondaryText)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.98))
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
            .fill(Color(white: 0.94))
            .overlay(
                Text(String((u.fullName ?? u.username).prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 18, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
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
                        canDelete: viewModel.currentUserId == item.userId,
                        currentUserId: viewModel.currentUserId
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, index > 0 && index % 5 == 0 ? 0 : 6)
                    .padding(.bottom, 6)
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
                .fill(VitisTheme.border)
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
