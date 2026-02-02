//
//  WineCardView.swift
//  Vitis
//
//  Full page wine card: shows wine details, user's tasting, activity comments, and other users' tastings.
//

import SwiftUI

struct WineCardView: View {
    let wine: Wine
    let activityId: UUID?
    let currentUserId: UUID?
    var sourceUserId: UUID? = nil
    var sourceContext: String? = nil

    @State private var userTasting: Tasting?
    @State private var otherTastings: [TastingWithProfile] = []
    @State private var friendsTastings: [TastingWithProfile] = []
    @State private var activityComments: [CommentWithProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var myWishlistWineIds: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    
    private var friendsAverageRating: Double? {
        guard !friendsTastings.isEmpty else { return nil }
        let sum = friendsTastings.reduce(0.0) { $0 + $1.rating }
        return sum / Double(friendsTastings.count)
    }
    
    private var globalAverageRating: Double? {
        var allRatings: [Double] = []
        
        // Include user's own rating if they have one
        if let userRating = userTasting?.rating {
            allRatings.append(userRating)
        }
        
        // Add friends' ratings
        allRatings.append(contentsOf: friendsTastings.map { $0.rating })
        
        // Add other users' ratings
        allRatings.append(contentsOf: otherTastings.map { $0.rating })
        
        guard !allRatings.isEmpty else { return nil }
        let sum = allRatings.reduce(0.0, +)
        return sum / Double(allRatings.count)
    }
    
    private var globalTastingsCount: Int {
        var count = 0
        if userTasting != nil { count += 1 }
        count += friendsTastings.count
        count += otherTastings.count
        return count
    }
    
    private var wineColor: Color {
        WineColorResolver.resolveWineDisplayColor(wine: wine)
    }
    
    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(VitisTheme.accent)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        wineHeader
                        
                        // Combined ratings section
                        ratingsSection
                        
                        // User's tasting notes and comment
                        if let tasting = userTasting, (tasting.noteTags?.isEmpty == false || tasting.comment?.isEmpty == false) {
                            userNotesSection(tasting)
                        }
                        
                        if activityId != nil && !activityComments.isEmpty {
                            activityCommentsSection
                        }
                        
                        if !otherTastings.isEmpty {
                            otherTastingsSection
                        }
                        
                        if let err = errorMessage {
                            Text(err)
                                .font(VitisTheme.uiFont(size: 13))
                                .foregroundStyle(.red)
                                .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitisWishlistUpdated)) { _ in
            Task {
                if let uid = currentUserId {
                    myWishlistWineIds = (try? await CellarService.fetchWishlistWineIds(userId: uid)) ?? myWishlistWineIds
                }
            }
        }
    }
    
    // MARK: - Wine Header
    
    private var wineHeader: some View {
        VStack(spacing: 16) {
            // Wine label image or icon
            if let urlString = wine.labelImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        wineIconPlaceholder
                    }
                }
            } else {
                wineIconPlaceholder
            }
            
            // Wine info
            VStack(spacing: 8) {
                Text(wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                    .multilineTextAlignment(.center)
                
                Text(wine.name)
                    .font(VitisTheme.wineNameFont())
                    .foregroundStyle(wineColor)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    if let vintage = wine.vintage {
                        Text(String(vintage))
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    if let region = wine.region {
                        Text(region)
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    if let variety = wine.variety {
                        Text(variety)
                            .font(VitisTheme.detailFont())
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                }
                if currentUserId != nil {
                    wishlistToggle
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
    }

    private var wishlistToggle: some View {
        Button {
            Task { await toggleWishlist() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: myWishlistWineIds.contains(wine.id) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14))
                Text(myWishlistWineIds.contains(wine.id) ? "Saved" : "Want to try")
                    .font(VitisTheme.uiFont(size: 14))
            }
            .foregroundStyle(myWishlistWineIds.contains(wine.id) ? VitisTheme.accent : VitisTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private func toggleWishlist() async {
        guard let uid = currentUserId else { return }
        let wineId = wine.id
        let wasIn = myWishlistWineIds.contains(wineId)
        myWishlistWineIds = wasIn ? myWishlistWineIds.filter { $0 != wineId } : myWishlistWineIds.union([wineId])
        do {
            if wasIn {
                try await CellarService.removeFromWishlist(userId: uid, wineId: wineId)
            } else {
                try await CellarService.addToWishlist(userId: uid, wineId: wineId, sourceUserId: sourceUserId, sourceContext: sourceContext ?? "profile")
            }
            NotificationCenter.default.post(name: .vitisWishlistUpdated, object: nil)
        } catch {
            myWishlistWineIds = wasIn ? myWishlistWineIds.union([wineId]) : myWishlistWineIds.filter { $0 != wineId }
        }
    }
    
    private var wineIconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.97))
                .frame(width: 120, height: 120)
            Image(systemName: "wineglass.fill")
                .font(.system(size: 48))
                .foregroundStyle(wineColor.opacity(0.5))
        }
    }
    
    // MARK: - Ratings Section
    
    private var ratingsSection: some View {
        VStack(alignment: .center, spacing: 8) {
            sectionDivider
            
            VStack(spacing: 16) {
                Text("Ratings")
                    .font(VitisTheme.uiFont(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack(spacing: 0) {
                    // You
                    if let tasting = userTasting {
                        ratingColumn(label: "You", rating: tasting.rating)
                    } else {
                        ratingColumn(label: "You", rating: nil)
                    }
                    
                    // Friends
                    if let avgRating = friendsAverageRating {
                        ratingColumn(label: "Friends", rating: avgRating)
                    } else {
                        ratingColumn(label: "Friends", rating: nil)
                    }
                    
                    // Global
                    if let avgRating = globalAverageRating {
                        ratingColumn(label: "Global", rating: avgRating)
                    } else {
                        ratingColumn(label: "Global", rating: nil)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    private func ratingColumn(label: String, rating: Double?) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(VitisTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            
            if let rating = rating {
                Text(String(format: "%.1f", rating))
                    .font(VitisTheme.uiFont(size: 28, weight: .semibold))
                    .foregroundStyle(VitisTheme.accent)
            } else {
                Text("—")
                    .font(VitisTheme.uiFont(size: 28, weight: .semibold))
                    .foregroundStyle(VitisTheme.border)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - User Notes Section
    
    private func userNotesSection(_ tasting: Tasting) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionDivider
            
            VStack(alignment: .leading, spacing: 12) {
                // Tasting notes
                if let notes = tasting.noteTags, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.secondaryText)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(notes, id: \.self) { note in
                                noteChip(note)
                            }
                        }
                    }
                }
                
                // Comment
                if let comment = tasting.comment, !comment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your thoughts")
                            .font(VitisTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.secondaryText)
                        
                        Text(comment)
                            .font(VitisTheme.uiFont(size: 15).italic())
                            .foregroundStyle(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    private func noteChip(_ note: String) -> some View {
        Text(note)
            .font(VitisTheme.uiFont(size: 14))
            .foregroundStyle(wineColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(wineColor.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(wineColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Activity Comments Section
    
    private var activityCommentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionDivider
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Comments on this post")
                    .font(VitisTheme.uiFont(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 0) {
                    ForEach(Array(activityComments.enumerated()), id: \.element.id) { idx, comment in
                        commentRow(comment)
                        if idx < activityComments.count - 1 {
                            Rectangle()
                                .fill(VitisTheme.border)
                                .frame(height: 1)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private func commentRow(_ comment: CommentWithProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            commentAvatar(comment.avatarURL, displayName: comment.username)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(comment.username)
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                    Spacer(minLength: 0)
                    Text(VitisTheme.compactTimestamp(comment.createdAt))
                        .font(VitisTheme.uiFont(size: 12))
                        .foregroundStyle(VitisTheme.tertiaryText)
                }
                
                Text(comment.body)
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private func commentAvatar(_ urlString: String?, displayName: String) -> some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        avatarPlaceholder(displayName)
                    }
                }
            } else {
                avatarPlaceholder(displayName)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
    
    private func avatarPlaceholder(_ name: String) -> some View {
        Circle()
            .fill(Color(white: 0.94))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(VitisTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
            )
    }
    
    // MARK: - Other Tastings Section
    
    private var otherTastingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionDivider
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What others are saying")
                    .font(VitisTheme.uiFont(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 0) {
                    ForEach(Array(otherTastings.enumerated()), id: \.element.id) { idx, tasting in
                        tastingRow(tasting)
                        if idx < otherTastings.count - 1 {
                            Rectangle()
                                .fill(VitisTheme.border)
                                .frame(height: 1)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private func tastingRow(_ tasting: TastingWithProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            commentAvatar(tasting.avatarURL, displayName: tasting.displayName)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(tasting.displayName)
                        .font(VitisTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                    Spacer(minLength: 0)
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 18, weight: .semibold))
                        .foregroundStyle(VitisTheme.accent)
                }
                
                if let notes = tasting.notesDisplay {
                    Text(notes)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .lineLimit(2)
                }
                
                if let comment = tasting.comment, !comment.isEmpty {
                    Text(comment)
                        .font(VitisTheme.uiFont(size: 13).italic())
                        .foregroundStyle(VitisTheme.secondaryText)
                        .lineLimit(3)
                }
                
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
                    .font(VitisTheme.uiFont(size: 12))
                    .foregroundStyle(VitisTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helpers
    
    private var sectionDivider: some View {
        Rectangle()
            .fill(VitisTheme.border)
            .frame(height: 1)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // Fetch user's tasting
        let userTastingResult: Tasting?
        if let userId = currentUserId {
            userTastingResult = try? await TastingService.fetchUserTastingForWine(userId: userId, wineId: wine.id)
        } else {
            userTastingResult = nil
        }
        
        // Fetch following user IDs
        let followingIds: Set<UUID>
        if let userId = currentUserId {
            let following = (try? await SocialService.fetchFollowing(userId: userId, limit: 1000)) ?? []
            followingIds = Set(following.map { $0.id })
        } else {
            followingIds = []
        }
        
        // Fetch all tastings for this wine (excluding current user for the "others" section)
        let allTastings: [TastingWithProfile]
        do {
            allTastings = try await WineService.fetchTastingsForWine(wineId: wine.id, excludeUserId: nil, limit: 100)
        } catch {
            allTastings = []
        }
        
        // Separate into friends and others (excluding current user)
        let friendsTastingsResult = allTastings.filter { 
            followingIds.contains($0.userId) && $0.userId != currentUserId 
        }
        let otherTastingsResult = allTastings.filter { 
            !followingIds.contains($0.userId) && $0.userId != currentUserId 
        }
        
        // Fetch activity comments
        let activityCommentsResult: [CommentWithProfile]
        if let actId = activityId {
            activityCommentsResult = (try? await SocialService.fetchComments(activityID: actId)) ?? []
        } else {
            activityCommentsResult = []
        }
        
        userTasting = userTastingResult
        friendsTastings = friendsTastingsResult
        otherTastings = otherTastingsResult
        activityComments = activityCommentsResult

        if let uid = currentUserId {
            myWishlistWineIds = (try? await CellarService.fetchWishlistWineIds(userId: uid)) ?? []
        }

        isLoading = false
    }
}

// MARK: - FlowLayout for Notes

/// Simple flow layout for wrapping note chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
