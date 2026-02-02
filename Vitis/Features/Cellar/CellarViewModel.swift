//
//  CellarViewModel.swift
//  Vitis
//
//  My Cellar: tasting history (wine logs with rating + notes).
//

import Foundation

@MainActor
@Observable
final class CellarViewModel {
    enum SortOption: String, CaseIterable { case newest = "Newest"; case highestRated = "Highest Rated" }
    enum RatingFilter: String, CaseIterable { case all = "All"; case eightPlus = "8.0+"; case ninePlus = "9.0+" }

    var tastings: [Tasting] = []
    var groupedTastings: [(category: String, tastings: [Tasting])] = []
    var sortOption: SortOption = .newest
    var ratingFilter: RatingFilter = .all
    var isLoading = false
    var errorMessage: String?
    var needsAuth = false
    private(set) var currentUserId: UUID?

    func load() async {
        let uid = await AuthService.currentUserId()
        if uid == nil && AppConstants.authRequired {
            needsAuth = true
            tastings = []
            groupedTastings = []
            return
        }
        needsAuth = false
        guard let uid else {
            tastings = []
            groupedTastings = []
            return
        }
        currentUserId = uid
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await TastingService.fetchTastings(userId: uid)
            tastings = fetched
            groupTastingsByCategory()
        } catch {
            errorMessage = ErrorMessage.userFacing(for: error)
            // Keep last-known-good state; do not clear tastings
        }
        isLoading = false
    }
    
    func groupTastingsByCategory() {
        var filtered = tastings
        switch ratingFilter {
        case .all: break
        case .eightPlus: filtered = filtered.filter { $0.rating >= 8.0 }
        case .ninePlus: filtered = filtered.filter { $0.rating >= 9.0 }
        }
        
        let sorter: (Tasting, Tasting) -> Bool = sortOption == .newest
            ? { $0.createdAt > $1.createdAt }
            : { $0.rating > $1.rating }
        
        // Create "All" category with all filtered tastings
        var result: [(category: String, tastings: [Tasting])] = []
        if !filtered.isEmpty {
            result.append((category: "All", tastings: filtered.sorted(by: sorter)))
        }
        
        // Group by category
        var categoryDict: [String: [Tasting]] = [:]
        for tasting in filtered {
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

    func removeTasting(_ tasting: Tasting) async {
        do {
            try await TastingService.deleteTasting(id: tasting.id)
            tastings.removeAll { $0.id == tasting.id }
            groupTastingsByCategory()
        } catch {
            errorMessage = ErrorMessage.userFacing(for: error)
        }
    }
}
