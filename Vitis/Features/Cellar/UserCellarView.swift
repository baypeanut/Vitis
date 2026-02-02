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
    @State private var currentUserId: UUID?
    
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
            currentUserId = await AuthService.currentUserId()
            await load()
        }
        .refreshable { await load() }
    }
    
    private var listContent: some View {
        CellarListView(
            groupedTastings: groupedTastings,
            currentUserId: currentUserId,
            allowSwipeToDelete: false
        )
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
        let sorter: (Tasting, Tasting) -> Bool = { $0.createdAt > $1.createdAt }
        
        // Create "All" category with all tastings
        var result: [(category: String, tastings: [Tasting])] = []
        if !tastings.isEmpty {
            result.append((category: "All", tastings: tastings.sorted(by: sorter)))
        }
        
        // Group by category using WineCategoryResolver
        var categoryDict: [String: [Tasting]] = [:]
        for tasting in tastings {
            let category = WineCategoryResolver.resolve(wine: tasting.wine)
            categoryDict[category, default: []].append(tasting)
        }
        
        // Sort categories (Red, White, Sparkling, Rose, Other)
        let sortedCategories = categoryDict.keys.sorted { a, b in
            if a == "Other" { return false }
            if b == "Other" { return true }
            return a < b
        }
        
        // Add category groups
        for category in sortedCategories {
            result.append((category: category, tastings: categoryDict[category]!.sorted(by: sorter)))
        }
        
        groupedTastings = result
    }
}
