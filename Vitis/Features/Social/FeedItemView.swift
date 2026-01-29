//
//  FeedItemView.swift
//  Vitis
//
//  Statement-style feed item: avatar, vertical line, thumbnails, Cheers + Comment.
//

import SwiftUI

struct FeedItemView: View {
    let item: FeedItem
    let parts: (before: String, name: String, after: String)
    let onCheers: () -> Void
    let onComment: () -> Void
    var onUsernameTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            avatarColumn
            contentColumn
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    private var avatarColumn: some View {
        VStack(spacing: 0) {
            avatar
            line
        }
        .frame(width: 44)
    }

    private var avatar: some View {
        Group {
            if let urlString = item.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty: avatarPlaceholder
                    @unknown default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .contentShape(Circle())
        .onTapGesture {
            onUsernameTap?()
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }

    private var line: some View {
        Rectangle()
            .fill(VitisTheme.border)
            .frame(width: 1, height: 24)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            statementText
            thumbnailsRow
            actionsRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statementText: some View {
        (Text(parts.before)
            .font(VitisTheme.uiFont(size: 15))
            .foregroundStyle(.primary)
        + Text(parts.name)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(VitisTheme.accent)
        + Text(parts.after)
            .font(VitisTheme.uiFont(size: 15))
            .foregroundStyle(.primary))
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            onUsernameTap?()
        }
    }

    private var thumbnailsRow: some View {
        HStack(spacing: 8) {
            wineThumbnail(
                name: item.wineName,
                producer: item.wineProducer,
                vintage: item.wineVintage,
                labelURL: item.wineLabelURL
            )
            if let tn = item.targetWineName {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
                wineThumbnail(
                    name: tn,
                    producer: item.targetWineProducer ?? "",
                    vintage: item.targetWineVintage,
                    labelURL: item.targetWineLabelURL
                )
            }
        }
    }

    private func wineThumbnail(name: String, producer: String, vintage: Int?, labelURL: String?) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.97))
                    .frame(width: 44, height: 44)
                if let urlString = labelURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 6))
                        default:
                            Image(systemName: "wineglass.fill")
                                .font(.system(size: 16)).foregroundStyle(VitisTheme.secondaryText.opacity(0.6))
                        }
                    }
                    .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(VitisTheme.secondaryText.opacity(0.6))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                Text(name)
                    .font(VitisTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let v = vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 20) {
            Button {
                onCheers()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.hasCheered ? "wineglass.fill" : "wineglass")
                        .font(.system(size: 14))
                        .foregroundStyle(item.hasCheered ? VitisTheme.accent : VitisTheme.secondaryText)
                    Text("Cheers")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(item.hasCheered ? VitisTheme.accent : VitisTheme.secondaryText)
                    if item.cheersCount > 0 {
                        Text("\(item.cheersCount)")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                onComment()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14))
                    Text("Comment")
                        .font(VitisTheme.uiFont(size: 13))
                    if item.commentCount > 0 {
                        Text("\(item.commentCount)")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                .foregroundStyle(VitisTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
