//
//  NotificationsView.swift
//  Vitis
//
//  In-app notifications for like and comment.
//

import SwiftUI

struct NotificationsView: View {
    @State private var items: [NotificationItem] = []
    @State private var isLoading = true
    @State private var unreadCount = 0
    @State private var selectedPostId: UUID?
    @State private var showCommentSheet = false
    @State private var currentUserId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                if isLoading && items.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VitisTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("No notifications yet.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { n in
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
                ToolbarItem(placement: .primaryAction) {
                    if unreadCount > 0 {
                        Button("Mark all as read") {
                            Task { await markAllRead() }
                        }
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.accent)
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showCommentSheet) {
                if let postId = selectedPostId {
                    CommentSheetView(
                        activityID: postId,
                        postOwnerId: nil,
                        currentUserId: currentUserId,
                        isPresented: $showCommentSheet,
                        onPosted: { Task { await load() } },
                        onCommentsChanged: { Task { await load() } }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .task { currentUserId = await AuthService.currentUserId() }
            .onChange(of: showCommentSheet) { _, v in if !v { selectedPostId = nil } }
        }
    }

    private func notificationRow(_ n: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(n.isRead ? Color.clear : VitisTheme.accent)
                .frame(width: 8, height: 8)
                .opacity(n.isRead ? 0 : 1)
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
            Task {
                if !n.isRead { try? await NotificationService.markAsRead(notificationId: n.id) }
                selectedPostId = n.postId
                showCommentSheet = true
            }
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
                    default: placeholder(name)
                    }
                }
            } else {
                placeholder(name)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func placeholder(_ name: String) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }

    private func load() async {
        isLoading = true
        do {
            items = try await NotificationService.fetchNotifications()
            unreadCount = await NotificationService.fetchUnreadCount()
        } catch {}
        isLoading = false
    }

    private func markAllRead() async {
        try? await NotificationService.markAllAsRead()
        unreadCount = 0
        await load()
    }
}
