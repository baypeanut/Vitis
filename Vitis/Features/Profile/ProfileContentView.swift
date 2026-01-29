//
//  ProfileContentView.swift
//  Vitis
//
//  Beli-style profile layout: header, Taste Snapshot + Streak/Goal cards, Recent Activity | Taste Profile tabs.
//

import SwiftUI

struct ProfileContentView: View {
    var viewModel: ProfileViewModel
    var isOwn: Bool
    var isFollowing: Bool
    var isTogglingFollow: Bool = false
    var followError: String?
    var onEdit: (() -> Void)?
    var onFollowToggle: (() -> Void)?
    var onSignOut: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onActivityTap: ((FeedItem) -> Void)?
    var onFollowChanged: (() -> Void)?

    enum MainTab: String, CaseIterable { case recentActivity = "Recent Activity"; case tasteProfile = "Taste Profile" }
    enum TasteSubTab: String, CaseIterable { case grapes = "Grapes"; case regions = "Regions"; case styles = "Styles" }

    @State private var mainTab: MainTab = .recentActivity
    @State private var tasteSubTab: TasteSubTab = .grapes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let p = viewModel.profile {
                    header(p)
                    tasteSnapshotCard(p)
                    streakGoalCard(p)
                    tabs
                    tabContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func header(_ p: Profile) -> some View {
        VStack(spacing: 12) {
            avatar(p)
            Text(p.displayName)
                .font(VitisTheme.wineNameFont())
                .foregroundStyle(.primary)
            Text("@\(p.username)")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.secondaryText)
            if let b = p.bioTrimmed, !b.isEmpty {
                Text(b)
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            statsRow
            primaryButton(p)
            if isOwn {
                Button("Sign out") { onSignOut?() }
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.accent)
                    .padding(.top, 8)
            }
            if hasSocialLinks(p) { socialIconsRow(p) }
        }
        .frame(maxWidth: .infinity)
    }

    private func avatar(_ p: Profile) -> some View {
        Group {
            if let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(p)
                    }
                }
            } else {
                avatarPlaceholder(p)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ p: Profile) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(p.displayName.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 32, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(viewModel.rankingsCount)", label: "Rankings")
            Rectangle().fill(VitisTheme.border).frame(width: 1).padding(.vertical, 8)
            statBlock(value: "\(viewModel.followersCount)", label: "Followers")
            Rectangle().fill(VitisTheme.border).frame(width: 1).padding(.vertical, 8)
            statBlock(value: "\(viewModel.followingCount)", label: "Following")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color(white: 0.98))
        .overlay(RoundedRectangle(cornerRadius: 1).stroke(VitisTheme.border, lineWidth: 1))
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(VitisTheme.uiFont(size: 12))
                .foregroundStyle(VitisTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func primaryButton(_ p: Profile) -> some View {
        Group {
            if isOwn {
                Button("Edit Profile") { onEdit?() }
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(VitisTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if isGuestProfile(p) {
                Text("User not found")
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            } else {
                VStack(spacing: 4) {
                    Button {
                        onFollowToggle?()
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(isFollowing ? VitisTheme.secondaryText : .white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(isFollowing ? Color(white: 0.94) : VitisTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isTogglingFollow)
                    if let e = followError {
                        Text(e)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func isGuestProfile(_ p: Profile) -> Bool {
        p.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "guest"
    }

    private func hasSocialLinks(_ p: Profile) -> Bool {
        let h = (p.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        return h != nil
    }

    private func socialIconsRow(_ p: Profile) -> some View {
        HStack(spacing: 12) {
            if let h = p.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
                InstagramHandleButton(handle: h)
            }
        }
    }

    private func tasteSnapshotCard(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Taste Snapshot")
                .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(VitisTheme.secondaryText)
            VStack(alignment: .leading, spacing: 8) {
                line("Loves:", TasteSnapshotOptions.labelForLoves(id: p.tasteSnapshotLoves))
                line("Avoids:", TasteSnapshotOptions.labelForAvoids(id: p.tasteSnapshotAvoids))
                line("Current mood:", TasteSnapshotOptions.labelForMood(id: p.tasteSnapshotMood))
            }
            .font(VitisTheme.uiFont(size: 15))
            .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.98))
        .overlay(RoundedRectangle(cornerRadius: 1).stroke(VitisTheme.border, lineWidth: 1))
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(VitisTheme.secondaryText)
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func streakGoalCard(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak / Goal")
                .font(VitisTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(VitisTheme.secondaryText)
            VStack(alignment: .leading, spacing: 8) {
                line("Weekly goal:", TasteSnapshotOptions.labelForWeeklyGoal(id: p.weeklyGoal))
                line("Streak:", streakLabel)
            }
            .font(VitisTheme.uiFont(size: 15))
            .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.98))
        .overlay(RoundedRectangle(cornerRadius: 1).stroke(VitisTheme.border, lineWidth: 1))
    }

    private var streakLabel: String {
        guard let d = viewModel.lastActivityDate else { return "-" }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }

    private var tabs: some View {
        Picker("", selection: $mainTab) {
            ForEach(MainTab.allCases, id: \.self) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch mainTab {
        case .recentActivity:
            recentActivityList
        case .tasteProfile:
            tasteProfileContent
        }
    }

    private var recentActivityList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.recentCellarItems.isEmpty {
                Text("No cellar activity yet.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.recentCellarItems) { item in
                    cellarActivityRow(item)
                    Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 0)
                }
            }
        }
    }

    private func cellarActivityRow(_ item: CellarItem) -> some View {
        let username = viewModel.profile?.username ?? "User"
        let parts = item.statementParts(username: username)
        return HStack(alignment: .top, spacing: 12) {
            cellarAvatarCircle()
            VStack(alignment: .leading, spacing: 4) {
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
                
                Text(formatDate(item.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func recentActivityRow(_ item: FeedItem) -> some View {
        let parts = item.statementParts()
        return HStack(alignment: .top, spacing: 12) {
            avatarCircle(item)
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
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onActivityTap?(item) }
    }

    private func cellarAvatarCircle() -> some View {
        Group {
            if let p = viewModel.profile, let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: cellarAvatarPlaceholder()
                    }
                }
            } else {
                cellarAvatarPlaceholder()
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func cellarAvatarPlaceholder() -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(viewModel.profile?.displayName.prefix(1) ?? "U").uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func avatarCircle(_ item: FeedItem) -> some View {
        Group {
            if let u = item.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: circlePlaceholder(item)
                    }
                }
            } else {
                circlePlaceholder(item)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func circlePlaceholder(_ item: FeedItem) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }

    private var tasteProfileContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $tasteSubTab) {
                ForEach(TasteSubTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            tasteProfileList
        }
    }

    @ViewBuilder
    private var tasteProfileList: some View {
        let items: [TasteProfileItem] = {
            switch tasteSubTab {
            case .grapes: return viewModel.tasteGrapes
            case .regions: return viewModel.tasteRegions
            case .styles: return viewModel.tasteStyles
            }
        }()
        if items.isEmpty {
            Text("No data yet. Rank wines to build your taste profile.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { it in
                    HStack {
                        Text(it.name)
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(it.count) rankings")
                            .font(VitisTheme.uiFont(size: 14))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    .padding(.vertical, 12)
                    Rectangle().fill(VitisTheme.border).frame(height: 1)
                }
            }
        }
    }
}

// MARK: - Instagram handle button (app or Safari)

private struct InstagramHandleButton: View {
    let handle: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openInstagram(handle: handle)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(VitisTheme.secondaryText)
                Text("@\(handle)")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.accent)
            }
        }
        .buttonStyle(.plain)
    }

    private func openInstagram(handle: String) {
        let escaped = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        let appURL = URL(string: "instagram://user?username=\(escaped)")
        let webURL = URL(string: "https://www.instagram.com/\(escaped)/")
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let webURL {
            openURL(webURL)
        }
    }
}
