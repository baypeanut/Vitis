//
//  CellarListView.swift
//  Vitis
//
//  Reusable cellar list component with category tabs and tasting rows
//

import SwiftUI

struct CellarListView: View {
    let groupedTastings: [(category: String, tastings: [Tasting])]
    let currentUserId: UUID?
    let allowSwipeToDelete: Bool
    var onDelete: ((Tasting) async -> Void)?
    
    @State private var selectedCategory: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if groupedTastings.count > 1 {
                categoryTabs
                Rectangle().fill(VitisTheme.border).frame(height: 1)
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
                            .font(VitisTheme.uiFont(size: 15, weight: selectedCategory == group.category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == group.category ? VitisTheme.accent : VitisTheme.secondaryText)
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
                        .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(VitisTheme.border)
                        .listRowBackground(Color.clear)
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
        } else {
            Text("No wines in this category.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func tastingRow(_ tasting: Tasting) -> some View {
        NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: currentUserId)) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tasting.wine.producer)
                        .font(VitisTheme.producerSerifFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                    HStack(alignment: .center) {
                        Text(tasting.wine.name)
                            .font(VitisTheme.wineNameFont())
                            .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f", tasting.rating))
                            .font(VitisTheme.uiFont(size: 24, weight: .semibold))
                            .foregroundStyle(VitisTheme.accent)
                    }
                    if let comment = tasting.comment, !comment.isEmpty {
                        Text(comment)
                            .font(VitisTheme.uiFont(size: 13).italic())
                            .foregroundStyle(VitisTheme.secondaryText)
                            .lineLimit(3)
                    }
                    Text(VitisTheme.compactTimestamp(tasting.createdAt))
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
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
