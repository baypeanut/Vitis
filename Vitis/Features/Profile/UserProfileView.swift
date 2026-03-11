//
//  UserProfileView.swift
//  Pari
//
//  Other user's profile from feed. Uses ProfileViewModel + ProfileContentView.
//  Never uses current user for profile data; always fetches by passed userId.
//

import SwiftUI

private struct UserProfileDrillDownTarget: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let filterType: TasteProfileDrillDownView.FilterType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UserProfileDrillDownTarget, rhs: UserProfileDrillDownTarget) -> Bool {
        lhs.id == rhs.id
    }
}

struct UserProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    var onDismiss: () -> Void
    var onFollowChanged: (() -> Void)?

    @State private var viewModel: ProfileViewModel
    @State private var isFollowing = false
    @State private var isTogglingFollow = false
    @State private var followError: String?
    @State private var commentActivityID: UUID?
    @State private var showCommentSheet = false
    @State private var showFollowersFollowing = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: UserProfileDrillDownTarget?
    @State private var currentUserId: UUID?
    @State private var showUserCellar = false
    @State private var showWantToTry = false
    @State private var alreadyTastedToast = false
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false
    @State private var isBlocked = false
    @State private var blockToast: String?
    @State private var tasteSimilarity: TasteSimilarity?
    @State private var tasteTwins: [TasteTwin] = []

    init(userId: UUID, onDismiss: @escaping () -> Void, onFollowChanged: (() -> Void)? = nil) {
        self.userId = userId
        self.onDismiss = onDismiss
        self.onFollowChanged = onFollowChanged
        _viewModel = State(initialValue: ProfileViewModel(userId: userId))
        #if DEBUG
        print("[UserProfileView] init userId=\(userId)")
        #endif
    }

    var body: some View {
        ZStack {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(PariTheme.accent(for: colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.profile != nil {
                    ProfileContentView(
                        viewModel: viewModel,
                        isOwn: viewModel.isOwn,
                        isFollowing: isFollowing,
                        isTogglingFollow: isTogglingFollow,
                        followError: followError,
                        tasteSimilarity: tasteSimilarity,
                        tasteTwins: tasteTwins,
                        onFollowToggle: { Task { await toggleFollow() } },
                        onActivityTap: { item in
                            commentActivityID = item.id
                            showCommentSheet = true
                        },
                        onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowing = true },
                        onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowing = true },
                        onRegionTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .region($0)) },
                        onGrapeTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .grape($0)) },
                        onRatedTap: { showUserCellar = true },
                        onWantToTryTap: { showWantToTry = true },
                        onWantToTryToggle: { item in await viewModel.toggleWishlistFromProfile(item) },
                        onRemoveWishlistItem: nil,
                        onMarkAsTasted: nil
                    )
                    .onAppear { AnalyticsService.profileView(userId: userId) }
                } else {
                    VStack(spacing: 12) {
                        Text("User not found")
                            .font(PariTheme.uiFont(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("This account may have been deleted.")
                            .font(PariTheme.uiFont(size: 14))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if DEBUG
                    .onAppear { print("[UserProfileView] profile nil userId=\(userId) (never followable)") }
                    #endif
                }
            }
            .navigationTitle(viewModel.profile?.displayName ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
                if !viewModel.isOwn {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showReportSheet = true
                            } label: {
                                Label("Report user", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label(isBlocked ? "Unblock user" : "Block user", systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18))
                                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        }
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportSheetView(
                    contentType: .user,
                    contentId: userId,
                    reportedUserId: userId,
                    isPresented: $showReportSheet
                )
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                isBlocked ? "Unblock \(viewModel.profile?.displayName ?? "user")?" : "Block \(viewModel.profile?.displayName ?? "user")?",
                isPresented: $showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button(isBlocked ? "Unblock" : "Block", role: isBlocked ? .none : .destructive) {
                    Task { await toggleBlock() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if !isBlocked {
                    Text("Blocked users cannot see your profile or interact with your posts.")
                }
            }
            .navigationDestination(item: $drillDownTarget) { target in
                TasteProfileDrillDownView(
                    title: target.title,
                    filterType: target.filterType,
                    tastings: viewModel.allTastings,
                    currentUserId: currentUserId
                )
            }
            .navigationDestination(isPresented: $showFollowersFollowing) {
                FollowersFollowingViewContent(
                    userId: userId,
                    currentUserId: currentUserId,
                    initialTab: followersFollowingInitialTab
                ) {
                    Task { await load() }
                }
            }
            .navigationDestination(isPresented: $showUserCellar) {
                UserCellarView(
                    userId: userId,
                    userName: viewModel.profile?.displayName ?? "User",
                    cellarLocked: !viewModel.cellarVisible
                )
            }
            .sheet(isPresented: $showWantToTry) {
                WantToTryView(
                    userId: userId,
                    username: viewModel.profile?.username ?? "",
                    onDismiss: { showWantToTry = false }
                )
            }
        }
        if alreadyTastedToast {
            Color.clear
                .ignoresSafeArea()
                .overlay(alignment: .center) {
                    Text("You've already tasted this wine")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PariTheme.secondaryElevated(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                }
                .allowsHitTesting(false)
        }
        }
        .animation(.easeInOut(duration: 0.2), value: alreadyTastedToast)
        .onReceive(NotificationCenter.default.publisher(for: .vitisAlreadyTastedToast)) { _ in
            alreadyTastedToast = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                alreadyTastedToast = false
            }
        }
        .id(userId)
        .task(id: userId) {
            #if DEBUG
            print("[UserProfileView] task id=\(userId)")
            #endif
            currentUserId = await AuthService.currentUserId()
            await load()
        }
        .sheet(isPresented: $showCommentSheet) {
            if let aid = commentActivityID {
                CommentSheetView(
                    activityID: aid,
                    postOwnerId: userId,
                    currentUserId: currentUserId,
                    isPresented: $showCommentSheet,
                    onPosted: { onFollowChanged?() },
                    onCommentsChanged: { onFollowChanged?() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: commentActivityID) { _, id in showCommentSheet = id != nil }
        .onChange(of: showCommentSheet) { _, v in if !v { commentActivityID = nil } }
    }

    private func load() async {
        await viewModel.load()
        if !viewModel.isOwn {
            async let following = SocialService.isFollowing(targetID: userId)
            async let blocked = BlockService.isBlocking(userId: userId)
            async let sim = TasteSimilarityService.fetchSimilarity(targetUserId: userId)
            isFollowing = await following
            isBlocked = await blocked
            tasteSimilarity = await sim
        }
        if let uid = currentUserId {
            tasteTwins = await TasteSimilarityService.fetchTasteTwins(userId: uid, limit: 10)
        }
    }

    private func toggleBlock() async {
        do {
            if isBlocked {
                try await BlockService.unblockUser(blockedId: userId)
                isBlocked = false
            } else {
                try await BlockService.blockUser(blockedId: userId)
                isBlocked = true
                onDismiss()
            }
        } catch {
            blockToast = "Could not update block status."
        }
    }

    private func toggleFollow() async {
        guard !isTogglingFollow else { return }
        isTogglingFollow = true
        followError = nil
        let prev = isFollowing
        isFollowing.toggle()
        viewModel.followersCount += isFollowing ? 1 : -1
        onFollowChanged?()
        do {
            if prev {
                try await SocialService.unfollowUser(targetID: userId)
            } else {
                try await SocialService.followUser(targetID: userId)
                AnalyticsService.follow(userId: userId, added: true)
            }
        } catch {
            isFollowing = prev
            viewModel.followersCount += prev ? 1 : -1
            followError = "Could not update follow."
            onFollowChanged?()
        }
        isTogglingFollow = false
    }
}

// MARK: - UserProfileViewContent (for navigation push, no NavigationStack wrapper)

struct UserProfileViewContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    var onFollowChanged: (() -> Void)?

    @State private var viewModel: ProfileViewModel
    @State private var currentUserId: UUID?
    @State private var isFollowing = false
    @State private var isTogglingFollow = false
    @State private var followError: String?
    @State private var commentActivityID: UUID?
    @State private var showCommentSheet = false
    @State private var showFollowersFollowing = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: UserProfileDrillDownTarget?
    @State private var showUserCellar = false
    @State private var showWantToTry = false
    @State private var tasteSimilarity: TasteSimilarity?
    @State private var tasteTwins: [TasteTwin] = []

    init(userId: UUID, onFollowChanged: (() -> Void)? = nil) {
        self.userId = userId
        self.onFollowChanged = onFollowChanged
        _viewModel = State(initialValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(PariTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.profile != nil {
                ProfileContentView(
                    viewModel: viewModel,
                    isOwn: viewModel.isOwn,
                    isFollowing: isFollowing,
                    isTogglingFollow: isTogglingFollow,
                    followError: followError,
                    tasteSimilarity: tasteSimilarity,
                    tasteTwins: tasteTwins,
                    onFollowToggle: { Task { await toggleFollow() } },
                    onActivityTap: { item in
                        commentActivityID = item.id
                        showCommentSheet = true
                    },
                    onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowing = true },
                    onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowing = true },
                    onRegionTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .region($0)) },
                    onGrapeTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .grape($0)) },
                    onRatedTap: { showUserCellar = true },
                    onWantToTryTap: { showWantToTry = true },
                    onWantToTryToggle: { item in await viewModel.toggleWishlistFromProfile(item) },
                    onRemoveWishlistItem: nil,
                    onMarkAsTasted: nil
                )
            } else {
                VStack(spacing: 12) {
                    Text("User not found")
                        .font(PariTheme.uiFont(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("This account may have been deleted.")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.profile?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $drillDownTarget) { target in
            TasteProfileDrillDownView(
                title: target.title,
                filterType: target.filterType,
                tastings: viewModel.allTastings,
                currentUserId: currentUserId
            )
        }
        .navigationDestination(isPresented: $showFollowersFollowing) {
            FollowersFollowingViewContent(
                userId: userId,
                currentUserId: currentUserId,
                initialTab: followersFollowingInitialTab
            ) {
                Task { await viewModel.load() }
            }
        }
        .navigationDestination(isPresented: $showUserCellar) {
            UserCellarView(
                userId: userId,
                userName: viewModel.profile?.displayName ?? "User"
            )
        }
        .sheet(isPresented: $showWantToTry) {
            WantToTryView(
                userId: userId,
                username: viewModel.profile?.username ?? "",
                onDismiss: { showWantToTry = false }
            )
        }
        .task(id: userId) {
            currentUserId = await AuthService.currentUserId()
            await load()
        }
        .sheet(isPresented: $showCommentSheet) {
            if let aid = commentActivityID, let current = currentUserId {
                CommentSheetView(
                    activityID: aid,
                    postOwnerId: viewModel.userId,
                    currentUserId: current,
                    isPresented: $showCommentSheet,
                    onPosted: { Task { await viewModel.load() } },
                    onCommentsChanged: { Task { await viewModel.load() } }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func load() async {
        await viewModel.load()
        guard let current = currentUserId, current != userId else { return }
        async let following = SocialService.isFollowing(targetID: userId)
        async let sim = TasteSimilarityService.fetchSimilarity(targetUserId: userId)
        async let twins = TasteSimilarityService.fetchTasteTwins(userId: current, limit: 10)
        isFollowing = await following
        tasteSimilarity = await sim
        tasteTwins = await twins
    }

    private func toggleFollow() async {
        guard let current = currentUserId, current != userId else { return }
        let prev = isFollowing
        isFollowing.toggle()
        viewModel.followersCount += isFollowing ? 1 : -1
        isTogglingFollow = true
        followError = nil
        do {
            if isFollowing {
                try await SocialService.followUser(targetID: userId)
            } else {
                try await SocialService.unfollowUser(targetID: userId)
            }
            onFollowChanged?()
        } catch {
            isFollowing = prev
            viewModel.followersCount += prev ? 1 : -1
            followError = "Could not update follow."
            onFollowChanged?()
        }
        isTogglingFollow = false
    }
}
