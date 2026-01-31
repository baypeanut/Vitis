//
//  UserProfileView.swift
//  Vitis
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
    let userId: UUID
    var onDismiss: () -> Void
    var onFollowChanged: (() -> Void)?

    @State private var viewModel: ProfileViewModel
    @State private var isFollowing = false
    @State private var isTogglingFollow = false
    @State private var followError: String?
    @State private var commentActivityID: UUID?
    @State private var showCommentSheet = false
    @State private var showFollowersFollowingSheet = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: UserProfileDrillDownTarget?
    @State private var currentUserId: UUID?

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
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VitisTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.profile != nil {
                    ProfileContentView(
                        viewModel: viewModel,
                        isOwn: viewModel.isOwn,
                        isFollowing: isFollowing,
                        isTogglingFollow: isTogglingFollow,
                        followError: followError,
                        onFollowToggle: { Task { await toggleFollow() } },
                        onActivityTap: { item in
                            commentActivityID = item.id
                            showCommentSheet = true
                        },
                        onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowingSheet = true },
                        onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowingSheet = true },
                        onRegionTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .region($0)) },
                        onStyleTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .style($0)) }
                    )
                } else {
                    VStack(spacing: 12) {
                        Text("User not found")
                            .font(VitisTheme.uiFont(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("This account may have been deleted.")
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(VitisTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if DEBUG
                    .onAppear { print("[UserProfileView] profile nil userId=\(userId) (never followable)") }
                    #endif
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.accent)
                }
            }
            .navigationDestination(item: $drillDownTarget) { target in
                TasteProfileDrillDownView(
                    title: target.title,
                    filterType: target.filterType,
                    tastings: viewModel.allTastings
                )
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
        .sheet(isPresented: $showFollowersFollowingSheet) {
            FollowersFollowingView(
                userId: userId,
                currentUserId: currentUserId,
                initialTab: followersFollowingInitialTab,
                onDismiss: { showFollowersFollowingSheet = false }
            ) {
                Task { await load() }
            }
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
            isFollowing = await SocialService.isFollowing(targetID: userId)
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
    let userId: UUID
    var onFollowChanged: (() -> Void)?

    @State private var viewModel: ProfileViewModel
    @State private var currentUserId: UUID?
    @State private var isFollowing = false
    @State private var isTogglingFollow = false
    @State private var followError: String?
    @State private var commentActivityID: UUID?
    @State private var showCommentSheet = false
    @State private var showFollowersFollowingSheet = false
    @State private var followersFollowingInitialTab: FollowersFollowingView.Tab = .followers
    @State private var drillDownTarget: UserProfileDrillDownTarget?

    init(userId: UUID, onFollowChanged: (() -> Void)? = nil) {
        self.userId = userId
        self.onFollowChanged = onFollowChanged
        _viewModel = State(initialValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(VitisTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.profile != nil {
                ProfileContentView(
                    viewModel: viewModel,
                    isOwn: viewModel.isOwn,
                    isFollowing: isFollowing,
                    isTogglingFollow: isTogglingFollow,
                    followError: followError,
                    onFollowToggle: { Task { await toggleFollow() } },
                    onActivityTap: { item in
                        commentActivityID = item.id
                        showCommentSheet = true
                    },
                    onFollowersTap: { followersFollowingInitialTab = .followers; showFollowersFollowingSheet = true },
                    onFollowingTap: { followersFollowingInitialTab = .following; showFollowersFollowingSheet = true },
                    onRegionTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .region($0)) },
                    onStyleTap: { drillDownTarget = UserProfileDrillDownTarget(title: $0, filterType: .style($0)) }
                )
            } else {
                VStack(spacing: 12) {
                    Text("User not found")
                        .font(VitisTheme.uiFont(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("This account may have been deleted.")
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $drillDownTarget) { target in
            TasteProfileDrillDownView(
                title: target.title,
                filterType: target.filterType,
                tastings: viewModel.allTastings
            )
        }
        .task(id: userId) {
            currentUserId = await AuthService.currentUserId()
            await load()
        }
        .sheet(isPresented: $showFollowersFollowingSheet) {
            FollowersFollowingView(
                userId: userId,
                currentUserId: currentUserId ?? UUID(),
                initialTab: followersFollowingInitialTab,
                onDismiss: { showFollowersFollowingSheet = false }
            ) {
                Task { await viewModel.load() }
            }
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
        isFollowing = await SocialService.isFollowing(targetID: userId)
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
