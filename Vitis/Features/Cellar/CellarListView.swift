//
//  CellarListView.swift
//  Pari
//
//  Reusable cellar list component with category tabs and tasting rows
//

import SwiftUI

struct CellarListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let groupedTastings: [(category: String, tastings: [Tasting])]
    let currentUserId: UUID?
    let allowSwipeToDelete: Bool
    var onDelete: ((Tasting) async -> Void)?
    
    @State private var selectedCategory: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if groupedTastings.count > 1 {
                categoryTabs
                Rectangle().fill(PariTheme.divider(for: colorScheme)).frame(height: 1)
            }
            categoryContent
        }
        .onAppear {
            updateSelectedCategory()
        }
        .onChange(of: groupedTastings.count) { _, _ in
            updateSelectedCategory()
        }
    }
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(groupedTastings, id: \.category) { group in
                    Button {
                        selectedCategory = group.category
                    } label: {
                        Text(group.category)
                            .font(PariTheme.uiFont(size: 15, weight: selectedCategory == group.category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == group.category ? PariTheme.accentWine(for: colorScheme) : (colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.textSecondary(for: colorScheme)))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private var categoryContent: some View {
        if let currentGroup = groupedTastings.first(where: { $0.category == selectedCategory }) {
            List {
                ForEach(currentGroup.tastings) { tasting in
                    tastingRow(tasting)
                        .listRowInsets(EdgeInsets(top: PariTheme.cardSpacingVertical / 2, leading: 16, bottom: PariTheme.cardSpacingVertical / 2, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowSpacing(0)
                        .if(allowSwipeToDelete && onDelete != nil) { view in
                            view.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await onDelete?(tasting) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PariTheme.backgroundPrimary(for: colorScheme))
        } else {
            Text("No wines in this category.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func tastingRow(_ tasting: Tasting) -> some View {
        ZStack {
            NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: currentUserId)) {
                EmptyView()
            }
            .opacity(0)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tasting.wine.producer)
                        .font(colorScheme == .dark ? PariTheme.uiFont(size: 12, weight: .regular) : PariTheme.producerSerifFont())
                        .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.textSecondary(for: colorScheme))
                    HStack(alignment: .center) {
                        Text(tasting.wine.name)
                            .font(PariTheme.wineNameFont(for: colorScheme))
                            .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(Int(tasting.rating.rounded())))
                            .font(colorScheme == .dark ? PariTheme.ratingFont() : PariTheme.uiFont(size: 20, weight: .medium))
                            .foregroundStyle(PariTheme.ratingColor(for: colorScheme))
                    }
                    if let comment = tasting.comment, !comment.isEmpty {
                        Text(comment)
                            .font(PariTheme.uiFont(size: 12).italic())
                            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                            .lineLimit(2)
                    }
                    Text(PariTheme.compactTimestamp(tasting.createdAt))
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                }
            }
            .padding(.vertical, PariTheme.cardPaddingVertical)
            .padding(.horizontal, PariTheme.cardPaddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: PariTheme.cardCornerRadius)
                    .fill(PariTheme.surface(for: colorScheme))
            )
        }
    }

    private func updateSelectedCategory() {
        if selectedCategory.isEmpty || !groupedTastings.contains(where: { $0.category == selectedCategory }) {
            selectedCategory = groupedTastings.first?.category ?? ""
        }
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
