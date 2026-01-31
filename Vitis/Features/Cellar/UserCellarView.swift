//
//  UserCellarView.swift
//  Vitis
//
//  View to display any user's cellar/tasting history
//

import SwiftUI

struct UserCellarView: View {
    let userId: UUID
    let userName: String
    @State private var tastings: [Tasting] = []
    @State private var groupedTastings: [(category: String, tastings: [Tasting])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCategory: String = ""
    
    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            
            if isLoading && tastings.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(VitisTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                Text(err)
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedTastings.isEmpty {
                Text("No wines rated yet")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .navigationTitle("\(userName)'s Wines")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable { await load() }
        .onChange(of: groupedTastings.count) { _, _ in
            updateSelectedCategory()
        }
    }
    
    private var listContent: some View {
        VStack(spacing: 0) {
            categoryTabs
            Rectangle().fill(VitisTheme.border).frame(height: 1)
            categoryContent
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
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tasting.wine.producer)
                    .font(VitisTheme.producerSerifFont())
                    .foregroundStyle(VitisTheme.secondaryText)
                Text(tasting.wine.name)
                    .font(VitisTheme.wineNameFont())
                    .foregroundStyle(WineColorResolver.resolveWineDisplayColor(wine: tasting.wine))
                if let v = tasting.wine.vintage {
                    Text(String(v))
                        .font(VitisTheme.detailFont())
                        .foregroundStyle(VitisTheme.secondaryText)
                }
                HStack(spacing: 8) {
                    if let r = tasting.wine.region, !r.isEmpty {
                        Text(r)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                        Text("·")
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
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
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
    
    private func updateSelectedCategory() {
        if selectedCategory.isEmpty || !groupedTastings.contains(where: { $0.category == selectedCategory }) {
            selectedCategory = groupedTastings.first?.category ?? ""
        }
    }
    
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            tastings = try await TastingService.fetchTastings(userId: userId)
            groupTastingsByCategory()
        } catch {
            errorMessage = "Could not load wines"
        }
        isLoading = false
    }
    
    private func groupTastingsByCategory() {
        var categoryMap: [String: [Tasting]] = [:]
        
        for tasting in tastings {
            let category = tasting.wine.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? tasting.wine.category!
                : "Other"
            categoryMap[category, default: []].append(tasting)
        }
        
        // Sort tastings within each category by rating (highest first)
        for (category, _) in categoryMap {
            categoryMap[category] = categoryMap[category]?.sorted { $0.rating > $1.rating }
        }
        
        // Sort categories alphabetically, but keep "Other" at the end
        let sortedCategories = categoryMap.keys.sorted { cat1, cat2 in
            if cat1 == "Other" { return false }
            if cat2 == "Other" { return true }
            return cat1 < cat2
        }
        
        groupedTastings = sortedCategories.compactMap { category in
            guard let tastings = categoryMap[category] else { return nil }
            return (category: category, tastings: tastings)
        }
    }
}
