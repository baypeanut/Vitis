//
//  CellarViewModel.swift
//  Vitis
//
//  Had | Wishlist cellar. Fetch by tab, add from +, empty states.
//

import Foundation

@MainActor
@Observable
final class CellarViewModel {
    enum Tab: String, CaseIterable, Hashable {
        case had
        case wishlist
    }

    var tab: Tab = .had
    var hadItems: [CellarItem] = []
    var wishlistItems: [CellarItem] = []
    var isLoading = false
    var errorMessage: String?
    var needsAuth = false
    private(set) var currentUserId: UUID?

    var items: [CellarItem] {
        switch tab {
        case .had: return hadItems
        case .wishlist: return wishlistItems
        }
    }

    func switchTab(to newTab: Tab) {
        guard newTab != tab else { return }
        tab = newTab
    }

    func load() async {
        let uid = await AuthService.currentUserId()
        if uid == nil && AppConstants.authRequired {
            needsAuth = true
            hadItems = []
            wishlistItems = []
            return
        }
        needsAuth = false
        guard let uid else {
            hadItems = []
            wishlistItems = []
            return
        }
        currentUserId = uid
        isLoading = true
        errorMessage = nil
        do {
            async let had = CellarService.fetchCellar(userId: uid, status: .had)
            async let wish = CellarService.fetchCellar(userId: uid, status: .wishlist)
            hadItems = try await had
            wishlistItems = try await wish
        } catch {
            errorMessage = error.localizedDescription
            hadItems = []
            wishlistItems = []
        }
        isLoading = false
    }

    func removeItem(_ item: CellarItem) async {
        do {
            try await CellarService.removeItem(id: item.id)
            if tab == .had {
                hadItems.removeAll { $0.id == item.id }
            } else {
                wishlistItems.removeAll { $0.id == item.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
