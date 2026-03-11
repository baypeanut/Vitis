//
//  NotificationsView.swift
//  Pari
//
//  In-app notifications for like, comment, and follow.
//

import SwiftUI
import os

struct NotificationsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [NotificationItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unreadCount = 0
    @State private var selectedPostId: UUID?
    @State private var showCommentSheet = false
    @State private var selectedActorId: UUID?
    @State private var showProfileSheet = false
    @State private var currentUserId: UUID?

    @AppStorage("notify_likes") private var notifyLikes = true
    @AppStorage("notify_comments") private var notifyComments = true
    @AppStorage("notify_follows") private var notifyFollows = true

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background(for: colorScheme).ignoresSafeArea()
                if isLoading && items.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(PariTheme.accent(for: colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage, items.isEmpty {
                    Text(err)
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { errorMessage = nil }
                } else if items.isEmpty {
                    Text("No notifications yet.")
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { n in
                                notificationRow(n)
                                Rectangle().fill(PariTheme.divider(for: colorScheme)).frame(height: 1).padding(.leading, 24)
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
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(colorScheme == .dark ? PariTheme.textSecondary(for: colorScheme) : PariTheme.accent(for: colorScheme))
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
            .fullScreenCover(isPresented: $showProfileSheet) {
                if let actorId = selectedActorId {
                    UserProfileView(userId: actorId, onDismiss: {
                        showProfileSheet = false
                        selectedActorId = nil
                    }) { Task { await load() } }
                }
            }
            .task { currentUserId = await AuthService.currentUserId() }
            .onChange(of: showCommentSheet) { _, v in if !v { selectedPostId = nil } }
            .onChange(of: showProfileSheet) { _, v in if !v { selectedActorId = nil } }
        }
    }

    private func notificationRow(_ n: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(n.isRead ? Color.clear : PariTheme.accent(for: colorScheme))
                .frame(width: 8, height: 8)
                .opacity(n.isRead ? 0 : 1)
            avatar(url: n.actorAvatarUrl, name: n.actorUsername ?? "?")
            VStack(alignment: .leading, spacing: 4) {
                notificationText(n)
                Text(PariTheme.compactTimestamp(n.createdAt))
                    .font(PariTheme.uiFont(size: 12))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                if !n.isRead { try? await NotificationService.markAsRead(notificationId: n.id) }
            }
            if n.type == "follow" {
                selectedActorId = n.actorId
                showProfileSheet = true
            } else if let postId = n.postId {
                selectedPostId = postId
                showCommentSheet = true
            }
        }
    }

    @ViewBuilder
    private func notificationText(_ n: NotificationItem) -> some View {
        let name = n.actorUsername ?? "Someone"
        if n.type == "follow" {
            (Text(name).fontWeight(.medium).foregroundStyle(PariTheme.textPrimary(for: colorScheme)) + Text(" started following you.").foregroundStyle(PariTheme.textPrimary(for: colorScheme)))
                .font(PariTheme.uiFont(size: 15))
        } else if n.type == "like" {
            let tastingText = n.tastingTitle?.isEmpty == false ? " liked your tasting of \(n.tastingTitle!)." : " liked your tasting."
            (Text(name).fontWeight(.medium).foregroundStyle(PariTheme.textPrimary(for: colorScheme)) + Text(tastingText).foregroundStyle(PariTheme.textPrimary(for: colorScheme)))
                .font(PariTheme.uiFont(size: 15))
        } else {
            VStack(alignment: .leading, spacing: 2) {
                let commentLead = n.tastingTitle?.isEmpty == false ? " commented on your tasting of \(n.tastingTitle!): " : " commented: "
                (Text(name).fontWeight(.medium).foregroundStyle(PariTheme.textPrimary(for: colorScheme)) + Text(commentLead).foregroundStyle(PariTheme.textPrimary(for: colorScheme)))
                    .font(PariTheme.uiFont(size: 15))
                if let prev = n.commentPreview {
                    Text(prev)
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
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
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func placeholder(_ name: String) -> some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(PariTheme.uiFont(size: 16, weight: .medium))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await NotificationService.fetchNotifications()
            items = all.filter { n in
                switch n.type {
                case "like": return notifyLikes
                case "comment": return notifyComments
                case "follow": return notifyFollows
                default: return true
                }
            }
            unreadCount = await NotificationService.fetchUnreadCount()
        } catch {
            Logger(subsystem: "com.ahmet.vitis", category: "Notifications").error("fetchNotifications failed: \(error.localizedDescription)")
            errorMessage = ErrorMessage.userFacing(for: error)
        }
        isLoading = false
    }

    private func markAllRead() async {
        try? await NotificationService.markAllAsRead()
        unreadCount = 0
        await load()
    }
}
