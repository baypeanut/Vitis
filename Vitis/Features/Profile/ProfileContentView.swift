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
    var onFollowersTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?
    var onRegionTap: ((String) -> Void)?
    var onStyleTap: ((String) -> Void)?
    var onRatedTap: (() -> Void)?

    enum MainTab: String, CaseIterable { case recentActivity = "Recent Activity"; case tasteProfile = "Taste Profile" }
    enum TasteSubTab: String, CaseIterable { case regions = "Regions"; case styles = "Styles" }

    @State private var mainTab: MainTab = .recentActivity
    @State private var tasteSubTab: TasteSubTab = .regions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                }
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
            HStack(spacing: 8) {
                Text("@\(p.username)")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
                if let h = p.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
                    InstagramIconButton(handle: h)
                }
            }
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
        HStack(spacing: 16) {
            Button {
                onRatedTap?()
            } label: {
                statItem(value: "\(viewModel.rankingsCount)", label: "Rated")
            }
            .buttonStyle(.plain)
            Button {
                onFollowersTap?()
            } label: {
                statItem(value: "\(viewModel.followersCount)", label: "Followers")
            }
            .buttonStyle(.plain)
            Button {
                onFollowingTap?()
            } label: {
                statItem(value: "\(viewModel.followingCount)", label: "Following")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(VitisTheme.uiFont(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
        }
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


    private func tasteSnapshotCard(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 8) {
                tasteSnapshotBox(
                    icon: "heart.fill",
                    value: TasteSnapshotOptions.labelForLoves(id: p.tasteSnapshotLoves)
                )
                tasteSnapshotBox(
                    icon: "hand.thumbsdown.fill",
                    value: TasteSnapshotOptions.labelForAvoids(id: p.tasteSnapshotAvoids)
                )
                tasteSnapshotBox(
                    icon: "face.smiling.fill",
                    value: TasteSnapshotOptions.labelForMood(id: p.tasteSnapshotMood)
                )
            }
        }
    }
    
    @ViewBuilder
    private func tasteSnapshotBox(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitisTheme.accent)
            Text(value)
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(white: 0.98))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VitisTheme.border, lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 8) {
                streakGoalBox(
                    icon: "target",
                    value: TasteSnapshotOptions.labelForWeeklyGoal(id: p.weeklyGoal)
                )
                streakGoalBox(
                    icon: "flame.fill",
                    value: streakLabel
                )
            }
        }
    }
    
    @ViewBuilder
    private func streakGoalBox(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitisTheme.accent)
            Text(value)
                .font(VitisTheme.uiFont(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(white: 0.98))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VitisTheme.border, lineWidth: 1))
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
            if viewModel.recentTastingsTop5.isEmpty {
                Text("No tastings yet.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.recentTastingsTop5) { tasting in
                    tastingActivityRow(tasting)
                    Rectangle().fill(VitisTheme.border).frame(height: 1).padding(.leading, 0)
                }
            }
        }
    }

    private func tastingActivityRow(_ tasting: Tasting) -> some View {
        let username = viewModel.profile?.username ?? "User"
        let wine = tasting.wine.vintage.map { "\($0) \(tasting.wine.name)" } ?? tasting.wine.name
        return HStack(alignment: .top, spacing: 12) {
            cellarAvatarCircle()
            VStack(alignment: .leading, spacing: 4) {
                (Text("\(username) had ")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(.primary)
                + Text(wine)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(VitisTheme.accent)
                + Text(".")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(.primary))
                .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                    if let notes = tasting.notesDisplay {
                        Text("·")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                        Text(notes)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
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
            case .regions: return viewModel.tasteRegions
            case .styles: return viewModel.tasteStyles
            }
        }()
        if items.isEmpty {
            Text("No data yet. Rate wines to build your taste profile.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { it in
                    Button {
                        if tasteSubTab == .regions {
                            onRegionTap?(it.name)
                        } else {
                            onStyleTap?(it.name)
                        }
                    } label: {
                        tasteProfileRow(it)
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(VitisTheme.border).frame(height: 1)
                }
            }
        }
    }

    private func tasteProfileRow(_ it: TasteProfileItem) -> some View {
        let nameColor: Color = .primary
        let ratingColor: Color = tasteSubTab == .styles
            ? WineColorResolver.resolveWineDisplayColor(category: it.name, wineName: nil)
            : VitisTheme.accent
        return HStack {
            Text(it.name)
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(nameColor)
            Spacer()
            HStack(spacing: 8) {
                if let avgRating = it.averageRating {
                    Text(String(format: "%.1f", avgRating))
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(ratingColor)
                    Text("·")
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                Text("\(it.count) \(it.count == 1 ? "tasting" : "tastings")")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Instagram icon button (app or Safari)

private struct InstagramIconButton: View {
    let handle: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openInstagram(handle: handle)
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundStyle(VitisTheme.secondaryText)
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
