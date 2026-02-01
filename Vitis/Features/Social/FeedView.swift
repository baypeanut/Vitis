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
    @State private var showNotificationSheet = false
    @State private var unreadCount = 0
    @State private var notificationItems: [NotificationItem] = []
    @State private var currentUserId: UUID?

    var body: some View {
        mainContent
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
            .sheet(isPresented: $showNotificationSheet) {
                notificationSheetContent
            }
            .navigationDestination(item: $profileSheetItem) { item in
                profileNavigationContent(for: item)
            }
            .task { currentUserId = await AuthService.currentUserId() }
            .task { unreadCount = await NotificationService.fetchUnreadCount() }
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
        VStack(spacing: 16) {
            Text("Follow people to see their tastings here.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        onWishlistToggle: (viewModel.currentUserId != nil && viewModel.currentUserId != item.userId) ? { Task { await viewModel.toggleWishlist(item) } } : nil,
                        trustHint: viewModel.trustHint(for: item),
                        onUsernameTap: {
                            #if DEBUG
                            print("[FeedView] tap profile tappedUserId=\(item.userId) tappedUsername=\(item.username)")
                            #endif
                            profileSheetItem = ProfileSheetItem(userId: item.userId, username: item.username)
                        },
                        onDelete: { Task { await viewModel.deleteFeedItem(item) } },
                        canDelete: viewModel.currentUserId == item.userId
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

    private func openNotificationSheet() async {
        do {
            notificationItems = try await NotificationService.fetchNotifications()
            _ = try? await NotificationService.markAllAsRead()
            unreadCount = 0
        } catch {}
        showNotificationSheet = true
    }

    @ViewBuilder
    private var notificationSheetContent: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                if notificationItems.isEmpty {
                    Text("No notifications yet.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notificationItems) { n in
                                notificationRow(n)
                                Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 24)
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showNotificationSheet = false }
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: showNotificationSheet) { _, v in
            if !v {
                Task { unreadCount = await NotificationService.fetchUnreadCount() }
            }
        }
    }

    private func notificationRow(_ n: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(url: n.actorAvatarUrl, name: n.actorUsername ?? "?")
            VStack(alignment: .leading, spacing: 4) {
                notificationText(n)
                Text(VitisTheme.compactTimestamp(n.createdAt))
                    .font(VitisTheme.uiFont(size: 12))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            showNotificationSheet = false
        }
    }

    @ViewBuilder
    private func notificationText(_ n: NotificationItem) -> some View {
        let name = n.actorUsername ?? "Someone"
        if n.type == "like" {
            (Text(name).fontWeight(.medium).foregroundStyle(VitisTheme.accent) + Text(" liked your tasting.").foregroundStyle(.primary))
                .font(VitisTheme.uiFont(size: 15))
        } else {
            VStack(alignment: .leading, spacing: 2) {
                (Text(name).fontWeight(.medium).foregroundStyle(VitisTheme.accent) + Text(" commented: ").foregroundStyle(.primary))
                    .font(VitisTheme.uiFont(size: 15))
                if let prev = n.commentPreview {
                    Text(prev)
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }

    private func avatar(url: String?, name: String) -> some View {
        Group {
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { p in
                    switch p {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(name)
                    }
                }
            } else {
                avatarPlaceholder(name)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ name: String) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }
}

#Preview {
    FeedView()
}
