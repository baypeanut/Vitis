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
    var isLoading = false
    var errorMessage: String?
    var needsAuth = false
    private(set) var currentUserId: UUID?

    func load() async {
        let uid = await AuthService.currentUserId()
        if uid == nil && AppConstants.authRequired {
            needsAuth = true
            tastings = []
            return
        }
        needsAuth = false
        guard let uid else {
            tastings = []
            return
        }
        currentUserId = uid
        isLoading = true
        errorMessage = nil
        do {
            tastings = try await TastingService.fetchTastings(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
            tastings = []
        }
        isLoading = false
    }

    func removeTasting(_ tasting: Tasting) async {
        do {
            try await TastingService.deleteTasting(id: tasting.id)
            tastings.removeAll { $0.id == tasting.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
