//
//  FeedView.swift
//  Vitis
//
//  Global / Following tabs, LazyVStack feed, minimalist header.
//

import SwiftUI

/// Identifiable item for profile sheet. Unique id per tap so sheet/VM never reuse.
private struct ProfileSheetItem: Identifiable {
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
    @State private var commentActivityID: UUID?
    @State private var showCommentSheet = false
    @State private var profileSheetItem: ProfileSheetItem?

    var body: some View {
        mainContent
            .task {
                viewModel.loadFromCache()
                viewModel.subscribeRealtime()
                Task { await viewModel.refresh() }
            }
            .onDisappear { viewModel.unsubscribeRealtime() }
            .onReceive(NotificationCenter.default.publisher(for: .vitisProfileUpdated)) { _ in
                viewModel.patchCurrentUserOverrides()
            }
            .sheet(isPresented: $showCommentSheet) { commentSheetContent }
            .sheet(item: $profileSheetItem) { item in
                profileSheetContent(for: item)
                    .id(item.userId)
            }
            .onChange(of: commentActivityID) { _, id in showCommentSheet = id != nil }
            .onChange(of: showCommentSheet) { _, v in if !v { commentActivityID = nil } }
    }

    private var mainContent: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                feedContent
            }
        }
    }

    @ViewBuilder
    private var commentSheetContent: some View {
        if let aid = commentActivityID {
            CommentSheetView(activityID: aid, currentUserId: viewModel.currentUserId, isPresented: $showCommentSheet) {
                Task { await viewModel.refresh() }
            }
            .presentationDetents([.medium, .large])
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

    private var header: some View {
        Text("Curated by")
            .font(VitisTheme.titleFont())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.global, label: "Global")
            tabButton(.following, label: "Following")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
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
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitisTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            feedList
        }
    }

    private var feedList: some View {
        List {
            ForEach(viewModel.items) { item in
                VStack(spacing: 0) {
                    FeedItemView(
                        item: item,
                        parts: viewModel.statementParts(for: item),
                        onCheers: { Task { await viewModel.cheer(item) } },
                        onComment: { commentActivityID = item.id },
                        onUsernameTap: {
                            #if DEBUG
                            print("[FeedView] tap profile tappedUserId=\(item.userId) tappedUsername=\(item.username)")
                            #endif
                            profileSheetItem = ProfileSheetItem(userId: item.userId, username: item.username)
                        },
                        onDelete: { Task { await viewModel.deleteFeedItem(item) } },
                        canDelete: viewModel.currentUserId == item.userId
                    )
                    Rectangle()
                        .fill(VitisTheme.border)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
}

#Preview {
    FeedView()
}
