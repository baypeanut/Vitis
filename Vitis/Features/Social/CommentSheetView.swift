//
//  CommentSheetView.swift
//  Vitis
//
//  Minimalist bottom sheet: list of comments (Profile + Text), single-line input, Post. Quiet Luxury.
//

import SwiftUI

struct CommentSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let activityID: UUID
    var postOwnerId: UUID?
    var currentUserId: UUID?
    @Binding var isPresented: Bool
    var onPosted: (() -> Void)?
    var onCommentsChanged: (() -> Void)?

    @State private var comments: [CommentWithProfile] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var reportingComment: CommentWithProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    if let err = errorMessage {
                        Text(err)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(VitisTheme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if comments.isEmpty {
                        Text("No comments yet.")
                            .font(VitisTheme.uiFont(size: 15))
                            .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 48)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(comments.enumerated()), id: \.element.id) { idx, c in
                                    commentRow(c, index: idx)
                                    if idx < comments.count - 1 {
                                        Rectangle()
                                            .fill(VitisTheme.border(for: colorScheme))
                                            .frame(height: 1)
                                            .padding(.leading, 24)
                                    }
                                }
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                        }
                    }

                    Divider()
                        .background(VitisTheme.border(for: colorScheme))

                    VStack(spacing: 4) {
                        HStack(spacing: 12) {
                            TextField("Add a comment…", text: $inputText)
                                .font(VitisTheme.uiFont(size: 15))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(VitisTheme.secondaryElevated(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: inputText) { _, new in
                                    if new.count > maxCommentLength {
                                        inputText = String(new.prefix(maxCommentLength))
                                    }
                                }

                            Button {
                                Task { await post() }
                            } label: {
                                Text("Post")
                                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(canPost ? VitisTheme.accent(for: colorScheme) : Color(white: 0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(!canPost || isPosting)
                        }
                        if inputText.count > 400 {
                            HStack {
                                Spacer()
                                Text("\(inputText.count)/\(maxCommentLength)")
                                    .font(VitisTheme.uiFont(size: 12))
                                    .foregroundStyle(inputText.count >= maxCommentLength ? .red : VitisTheme.secondaryText(for: colorScheme))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                }
            }
        }
        .task { await load() }
        .onChange(of: isPresented) { _, presented in
            if presented { Task { await load() } }
        }
        .sheet(item: $reportingComment) { c in
            ReportSheetView(
                contentType: .comment,
                contentId: c.id,
                reportedUserId: c.userId,
                isPresented: Binding(
                    get: { reportingComment != nil },
                    set: { if !$0 { reportingComment = nil } }
                )
            )
            .presentationDetents([.medium, .large])
        }
    }

    private let maxCommentLength = 500

    private var canPost: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && inputText.count <= maxCommentLength
    }

    private func displayName(for c: CommentWithProfile) -> String {
        if c.userId == currentUserId, let p = ProfileStore.shared.currentProfile { return p.displayName }
        return c.username
    }

    private func avatarURL(for c: CommentWithProfile) -> String? {
        if c.userId == currentUserId, let p = ProfileStore.shared.currentProfile { return p.avatarURL }
        return c.avatarURL
    }

    @ViewBuilder
    private func commentRow(_ c: CommentWithProfile, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            commentAvatar(avatarURL(for: c), displayName: displayName(for: c))
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName(for: c))
                    .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? VitisTheme.textPrimary(for: colorScheme) : VitisTheme.accent(for: colorScheme))
                Text(VitisTheme.shortAbsoluteTimestamp(c.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(colorScheme == .dark ? VitisTheme.tertiaryText(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                Text(c.body)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if c.userId == currentUserId {
                Button(role: .destructive) {
                    Task { await deleteComment(c) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button {
                    reportingComment = c
                } label: {
                    Label("Report", systemImage: "flag")
                }
                .tint(.orange)
            }
        }
    }

    private func commentAvatar(_ urlString: String?, displayName: String) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(displayName)
                    }
                }
            } else {
                avatarPlaceholder(displayName)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ name: String) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
            )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            comments = try await SocialService.fetchComments(activityID: activityID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func post() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if ContentModeration.containsObjectionableContent(text) {
            errorMessage = ContentModeration.blockedMessage
            return
        }
        isPosting = true
        errorMessage = nil
        do {
            let commentId = try await SocialService.addComment(activityID: activityID, body: text)
            if let ownerId = postOwnerId, let actorId = currentUserId {
                Task { await NotificationService.createCommentNotification(recipientId: ownerId, actorId: actorId, postId: activityID, commentId: commentId, commentPreview: text) }
            }
            inputText = ""
            await load()
            onPosted?()
            onCommentsChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
    
    private func deleteComment(_ c: CommentWithProfile) async {
        do {
            try await SocialService.deleteComment(commentId: c.id)
            comments.removeAll { $0.id == c.id }
            onPosted?()
            onCommentsChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
