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
    
    @State private var userTasting: Tasting?
    @State private var otherTastings: [TastingWithProfile] = []
    @State private var activityComments: [CommentWithProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
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
                        
                        if let tasting = userTasting {
                            userTastingSection(tasting)
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
        .navigationTitle(wine.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
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
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
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
    
    // MARK: - User Tasting Section
    
    private func userTastingSection(_ tasting: Tasting) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionDivider
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Tasting")
                    .font(VitisTheme.uiFont(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                
                // Rating
                HStack(alignment: .center, spacing: 12) {
                    Text(String(format: "%.1f", tasting.rating))
                        .font(VitisTheme.uiFont(size: 36, weight: .semibold))
                        .foregroundStyle(VitisTheme.accent)
                    Text("/ 10")
                        .font(VitisTheme.uiFont(size: 18))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                
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
                
                Text(VitisTheme.compactTimestamp(tasting.createdAt))
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.tertiaryText)
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
        
        async let userTastingTask: Tasting? = {
            guard let userId = currentUserId else { return nil }
            return try? await TastingService.fetchUserTastingForWine(userId: userId, wineId: wine.id)
        }()
        
        async let otherTastingsTask: [TastingWithProfile] = {
            return (try? await WineService.fetchTastingsForWine(wineId: wine.id, excludeUserId: currentUserId, limit: 20)) ?? []
        }()
        
        async let activityCommentsTask: [CommentWithProfile] = {
            guard let actId = activityId else { return [] }
            return (try? await SocialService.fetchComments(activityID: actId)) ?? []
        }()
        
        let (userTastingResult, otherTastingsResult, activityCommentsResult) = await (userTastingTask, otherTastingsTask, activityCommentsTask)
        
        userTasting = userTastingResult
        otherTastings = otherTastingsResult
        activityComments = activityCommentsResult
        
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
