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
    var tastings: [Tasting] = []
    var groupedTastings: [(category: String, tastings: [Tasting])] = []
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
            tastings = try await TastingService.fetchTastings(userId: uid)
            groupTastingsByCategory()
        } catch {
            errorMessage = error.localizedDescription
            tastings = []
            groupedTastings = []
        }
        isLoading = false
    }
    
    private func groupTastingsByCategory() {
        var categoryDict: [String: [Tasting]] = [:]
        
        for tasting in tastings {
            let category = tasting.wine.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? tasting.wine.category!
                : "Other"
            categoryDict[category, default: []].append(tasting)
        }
        
        // Sort categories alphabetically, but keep "Other" at the end
        let sortedCategories = categoryDict.keys.sorted { a, b in
            if a == "Other" { return false }
            if b == "Other" { return true }
            return a < b
        }
        
        groupedTastings = sortedCategories.map { category in
            // Sort tastings within each category by rating (highest first)
            let sortedTastings = categoryDict[category]!.sorted { $0.rating > $1.rating }
            return (category: category, tastings: sortedTastings)
        }
    }

    func removeTasting(_ tasting: Tasting) async {
        do {
            try await TastingService.deleteTasting(id: tasting.id)
            tastings.removeAll { $0.id == tasting.id }
            groupTastingsByCategory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
