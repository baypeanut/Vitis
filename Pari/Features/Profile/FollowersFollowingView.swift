//
//  FollowersFollowingView.swift
//  Pari
//
//  Instagram-like: Followers | Following tabs, swipe between lists, pagination.
//

import SwiftUI
import os

struct FollowersFollowingView: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    var currentUserId: UUID?
    var initialTab: Tab = .followers
    var onDismiss: () -> Void
    var onFollowChanged: (() -> Void)?

    enum Tab: String, CaseIterable { case followers = "Followers"; case following = "Following" }

    @State private var tab: Tab = .followers
    @State private var followers: [SocialService.FollowListUser] = []
    @State private var following: [SocialService.FollowListUser] = []
    @State private var errorMessage: String?
    @State private var isLoadingFollowers = true
    @State private var isLoadingFollowing = true
    @State private var followersOffset = 0
    @State private var followingOffset = 0
    @State private var selectedUserId: UUID?
    private let pageSize = 30

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                VStack(spacing: 0) {
                    if let err = errorMessage {
                        Text(err)
                            .font(PariTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { errorMessage = nil }
                    }
                    tabBar
                    TabView(selection: $tab) {
                        listContent(users: followers, isLoading: isLoadingFollowers, emptyMessage: "No followers yet.", currentUserId: currentUserId, onUserTap: { selectedUserId = $0 }, onLoad: { loadFollowers(reset: true) }, onNearBottom: { loadFollowers(reset: false) })
                        .tag(Tab.followers)

                        listContent(users: following, isLoading: isLoadingFollowing, emptyMessage: "Not following anyone yet.", currentUserId: currentUserId, onUserTap: { selectedUserId = $0 }, onLoad: { loadFollowing(reset: true) }, onNearBottom: { loadFollowing(reset: false) })
                        .tag(Tab.following)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
            }
            .fullScreenCover(item: Binding(
                get: { selectedUserId.map { IdentifiableUUID(id: $0) } },
                set: { selectedUserId = $0?.id }
            )) { wrap in
                UserProfileView(userId: wrap.id, onDismiss: { selectedUserId = nil }) {
                    onFollowChanged?()
                }
            }
        }
        .task {
            tab = initialTab
            loadFollowers(reset: true)
            loadFollowing(reset: true)
        }
        .onChange(of: initialTab) { _, t in tab = t }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(PariTheme.uiFont(size: 15, weight: tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? PariTheme.accent(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func listContent(
        users: [SocialService.FollowListUser],
        isLoading: Bool,
        emptyMessage: String,
        currentUserId: UUID?,
        onUserTap: @escaping (UUID) -> Void,
        onLoad: @escaping () -> Void,
        onNearBottom: @escaping () -> Void
    ) -> some View {
        if isLoading && users.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PariTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if users.isEmpty {
            Text(emptyMessage)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(users.enumerated()), id: \.element.id) { idx, u in
                        FollowListRowView(user: u, currentUserId: currentUserId) {
                            onFollowChanged?()
                            updateUserInList(id: u.id, isFollowing: !u.isFollowing)
                        } onTap: {
                            onUserTap(u.id)
                        }
                        if idx < users.count - 1 {
                            Rectangle().fill(PariTheme.border).frame(height: 1).padding(.leading, 24)
                        }
                    }
                    Color.clear.frame(height: 20)
                        .onAppear { onNearBottom() }
                }
                .padding(.top, 8)
            }
        }
    }

    private func updateUserInList(id: UUID, isFollowing: Bool) {
        if let i = followers.firstIndex(where: { $0.id == id }) {
            followers[i] = SocialService.FollowListUser(id: followers[i].id, username: followers[i].username, fullName: followers[i].fullName, avatarUrl: followers[i].avatarUrl, isFollowing: isFollowing)
        }
        if let i = following.firstIndex(where: { $0.id == id }) {
            following[i] = SocialService.FollowListUser(id: following[i].id, username: following[i].username, fullName: following[i].fullName, avatarUrl: following[i].avatarUrl, isFollowing: isFollowing)
        }
    }

    private func loadFollowers(reset: Bool) {
        if reset { followersOffset = 0 }
        Task {
            if reset { isLoadingFollowers = true }
            do {
                let new = try await SocialService.fetchFollowers(userId: userId, limit: pageSize, offset: followersOffset)
                if reset { followers = new } else { followers.append(contentsOf: new) }
                followersOffset += new.count
            } catch {
                Logger(subsystem: "com.ahmet.pari", category: "FollowersFollowing").error("fetchFollowers failed: \(error.localizedDescription)")
                errorMessage = ErrorMessage.userFacing(for: error)
            }
            isLoadingFollowers = false
        }
    }

    private func loadFollowing(reset: Bool) {
        if reset { followingOffset = 0 }
        Task {
            if reset { isLoadingFollowing = true }
            do {
                let new = try await SocialService.fetchFollowing(userId: userId, limit: pageSize, offset: followingOffset)
                if reset { following = new } else { following.append(contentsOf: new) }
                followingOffset += new.count
            } catch {
                Logger(subsystem: "com.ahmet.pari", category: "FollowersFollowing").error("fetchFollowing failed: \(error.localizedDescription)")
                errorMessage = ErrorMessage.userFacing(for: error)
            }
            isLoadingFollowing = false
        }
    }
}

private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

@MainActor
private struct FollowListRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let user: SocialService.FollowListUser
    var currentUserId: UUID?
    var onFollowChanged: () -> Void
    var onTap: () -> Void

    @State private var isFollowing: Bool
    @State private var isToggling = false

    init(user: SocialService.FollowListUser, currentUserId: UUID?, onFollowChanged: @escaping () -> Void, onTap: @escaping () -> Void) {
        self.user = user
        self.currentUserId = currentUserId
        self.onFollowChanged = onFollowChanged
        self.onTap = onTap
        _isFollowing = State(initialValue: user.isFollowing)
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName ?? user.username)
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text("@\(user.username)")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if currentUserId != user.id {
                followButton
            } else {
                Text("You")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var avatar: some View {
        Group {
            if let s = user.avatarUrl, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String((user.fullName ?? user.username).prefix(1)).uppercased())
                    .font(PariTheme.uiFont(size: 18, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            )
    }

    private var followButton: some View {
        Button {
            Task { await toggleFollow() }
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(PariTheme.uiFont(size: 14, weight: .medium))
                .foregroundStyle(isFollowing ? PariTheme.secondaryText(for: colorScheme) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isFollowing ? PariTheme.placeholderBackground(for: colorScheme) : PariTheme.accent(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }

    private func toggleFollow() async {
        guard !isToggling else { return }
        isToggling = true
        let prev = isFollowing
        isFollowing.toggle()
        onFollowChanged()
        do {
            if prev {
                try await SocialService.unfollowUser(targetID: user.id)
            } else {
                try await SocialService.followUser(targetID: user.id)
                AnalyticsService.follow(userId: user.id, added: true)
            }
        } catch {
            isFollowing = prev
            onFollowChanged()
        }
        isToggling = false
    }
}

// MARK: - FollowersFollowingViewContent (for navigation push, no NavigationStack wrapper)

struct FollowersFollowingViewContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    var currentUserId: UUID?
    var initialTab: FollowersFollowingView.Tab = .followers
    var onFollowChanged: (() -> Void)?

    @State private var tab: FollowersFollowingView.Tab = .followers
    @State private var followers: [SocialService.FollowListUser] = []
    @State private var following: [SocialService.FollowListUser] = []
    @State private var errorMessage: String?
    @State private var isLoadingFollowers = true
    @State private var isLoadingFollowing = true
    @State private var followersOffset = 0
    @State private var followingOffset = 0
    @State private var selectedUserId: UUID?
    private let pageSize = 30

    var body: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                if let err = errorMessage {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { errorMessage = nil }
                }
                tabBar
                TabView(selection: $tab) {
                    listContent(users: followers, isLoading: isLoadingFollowers, emptyMessage: "No followers yet.", currentUserId: currentUserId, onUserTap: { selectedUserId = $0 }, onLoad: { loadFollowers(reset: true) }, onNearBottom: { loadFollowers(reset: false) })
                    .tag(FollowersFollowingView.Tab.followers)

                    listContent(users: following, isLoading: isLoadingFollowing, emptyMessage: "Not following anyone yet.", currentUserId: currentUserId, onUserTap: { selectedUserId = $0 }, onLoad: { loadFollowing(reset: true) }, onNearBottom: { loadFollowing(reset: false) })
                    .tag(FollowersFollowingView.Tab.following)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(
            get: { selectedUserId.map { IdentifiableUUID(id: $0) } },
            set: { selectedUserId = $0?.id }
        )) { wrap in
            UserProfileView(userId: wrap.id, onDismiss: { selectedUserId = nil }) {
                onFollowChanged?()
            }
        }
        .task {
            tab = initialTab
            loadFollowers(reset: true)
            loadFollowing(reset: true)
        }
        .onChange(of: initialTab) { _, t in tab = t }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FollowersFollowingView.Tab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(PariTheme.uiFont(size: 15, weight: tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? PariTheme.accent(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func listContent(
        users: [SocialService.FollowListUser],
        isLoading: Bool,
        emptyMessage: String,
        currentUserId: UUID?,
        onUserTap: @escaping (UUID) -> Void,
        onLoad: @escaping () -> Void,
        onNearBottom: @escaping () -> Void
    ) -> some View {
        if isLoading && users.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PariTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if users.isEmpty {
            Text(emptyMessage)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(users.enumerated()), id: \.element.id) { idx, u in
                        FollowListRowView(user: u, currentUserId: currentUserId) {
                            onFollowChanged?()
                            updateUserInList(id: u.id, isFollowing: !u.isFollowing)
                        } onTap: {
                            onUserTap(u.id)
                        }
                        if idx < users.count - 1 {
                            Rectangle().fill(PariTheme.border).frame(height: 1).padding(.leading, 24)
                        }
                    }
                    Color.clear.frame(height: 20)
                        .onAppear { onNearBottom() }
                }
                .padding(.top, 8)
            }
        }
    }

    private func updateUserInList(id: UUID, isFollowing: Bool) {
        if let i = followers.firstIndex(where: { $0.id == id }) {
            followers[i] = SocialService.FollowListUser(id: followers[i].id, username: followers[i].username, fullName: followers[i].fullName, avatarUrl: followers[i].avatarUrl, isFollowing: isFollowing)
        }
        if let i = following.firstIndex(where: { $0.id == id }) {
            following[i] = SocialService.FollowListUser(id: following[i].id, username: following[i].username, fullName: following[i].fullName, avatarUrl: following[i].avatarUrl, isFollowing: isFollowing)
        }
    }

    private func loadFollowers(reset: Bool) {
        if reset { followersOffset = 0 }
        Task {
            if reset { isLoadingFollowers = true }
            do {
                let new = try await SocialService.fetchFollowers(userId: userId, limit: pageSize, offset: followersOffset)
                if reset { followers = new } else { followers.append(contentsOf: new) }
                followersOffset += new.count
            } catch {
                Logger(subsystem: "com.ahmet.pari", category: "FollowersFollowing").error("fetchFollowers failed: \(error.localizedDescription)")
                errorMessage = ErrorMessage.userFacing(for: error)
            }
            isLoadingFollowers = false
        }
    }

    private func loadFollowing(reset: Bool) {
        if reset { followingOffset = 0 }
        Task {
            if reset { isLoadingFollowing = true }
            do {
                let new = try await SocialService.fetchFollowing(userId: userId, limit: pageSize, offset: followingOffset)
                if reset { following = new } else { following.append(contentsOf: new) }
                followingOffset += new.count
            } catch {
                Logger(subsystem: "com.ahmet.pari", category: "FollowersFollowing").error("fetchFollowing failed: \(error.localizedDescription)")
                errorMessage = ErrorMessage.userFacing(for: error)
            }
            isLoadingFollowing = false
        }
    }
}
