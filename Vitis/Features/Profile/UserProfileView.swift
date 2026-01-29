//
//  UserProfileView.swift
//  Vitis
//
//  Other user's profile from feed. Uses ProfileViewModel + ProfileContentView.
//  Never uses current user for profile data; always fetches by passed userId.
//

import SwiftUI

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
                        }
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
                    currentUserId: currentUserId,
                    isPresented: $showCommentSheet
                ) {
                    onFollowChanged?()
                }
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
        do {
            if isFollowing {
                try await SocialService.unfollowUser(targetID: userId)
                isFollowing = false
            } else {
                try await SocialService.followUser(targetID: userId)
                isFollowing = true
            }
            onFollowChanged?()
        } catch {
            followError = "Could not update follow."
        }
        isTogglingFollow = false
    }
}
