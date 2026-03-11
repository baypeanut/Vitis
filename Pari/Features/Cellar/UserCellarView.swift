//
//  UserCellarView.swift
//  Pari
//
//  View to display any user's cellar/tasting history
//

import SwiftUI

struct UserCellarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let userId: UUID
    let userName: String
    var cellarLocked: Bool = false
    @State private var tastings: [Tasting] = []
    @State private var groupedTastings: [(category: String, tastings: [Tasting])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?
    
    var body: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            
            if cellarLocked {
                Text("Cellar is visible to friends.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading && tastings.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(PariTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                Text(err)
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedTastings.isEmpty {
                Text("No wines rated yet")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .navigationTitle("\(userName)'s Wines")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !cellarLocked else { return }
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
