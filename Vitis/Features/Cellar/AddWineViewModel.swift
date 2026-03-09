//
//  AddWineViewModel.swift
//  Vitis
//
//  Search: Supabase wines catalog (X-Wines import). Debounced. Optional OFF cache kept for future.
//

import Foundation

private let minQueryLengthForSearch = 2
private let debounceMs: UInt64 = 400
private let searchCacheCap = 300

@MainActor
@Observable
final class AddWineViewModel {
    var query = ""
    /// OFF-style results (used only if OFF search is re-enabled).
    var results: [OFFProduct] = []
    /// Search results from Supabase (X-Wines / catalog). Primary source for Add Wine search.
    var dbSearchResults: [Wine] = []
    var dbWines: [Wine] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var isUpserting = false
    var hasMorePages = false
    private var currentSearchPage = 1
    private var lastSearchTerm = ""

    /// True when we have finished searching for the current query (so empty results = genuinely no wines).
    var searchCompletedForCurrentQuery: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !q.isEmpty && q == lastSearchTerm && !isLoading
    }

    /// True when user has typed something but we're still debouncing or loading (don't show "No wines found").
    var isSearchingOrPending: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !q.isEmpty && (isLoading || q != lastSearchTerm)
    }

    private var searchTask: Task<Void, Never>?
    private var searchCache: [OFFProduct] = []
    /// Maps "vitis-catalog-{uuid}" → Wine for catalog wines (skip upsert when selected).
    private var catalogWineById: [String: Wine] = [:]

    func loadDatabaseWines() async {
        do {
            dbWines = try await WineService.fetchAllWines(limit: 100)
        } catch {
            #if DEBUG
            print("[AddWineViewModel] Failed to load database wines: \(error)")
            #endif
        }
    }

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            dbSearchResults = []
            results = []
            lastSearchTerm = ""
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounceMs * 1_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(term: q)
        }
    }

    /// Yerel katalog + cache’ten term geçenleri (contains) birleştir, sırala, göster. Anında.
    private func applyCacheFilter(term: String) {
        let combined = allMatching(term)
        results = filterAndRank(products: combined, query: term)
    }

    /// Yerel katalog (anında) + önbellek eşleşmeleri. Ağ yok.
    private func allMatching(_ term: String) -> [OFFProduct] {
        let local = LocalWineCatalog.matching(term)
        let cached = productsMatching(term)
        return local + cached
    }

    /// Geçerli ürünler (brands zorunlu). Sıra: önce "ile başlayan", sonra "içeren" (leb → leblebi).
    private func filterAndRank(products: [OFFProduct], query: String) -> [OFFProduct] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let valid: (OFFProduct) -> Bool = { p in
            p.brands?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        let filtered = products.filter(valid)
        guard !q.isEmpty else { return filtered }
        return filtered.sorted { a, b in
            let aName = (a.productName ?? "").lowercased()
            let aBrand = (a.brands ?? "").lowercased()
            let bName = (b.productName ?? "").lowercased()
            let bBrand = (b.brands ?? "").lowercased()
            let aStarts = aName.hasPrefix(q) || aBrand.hasPrefix(q)
            let bStarts = bName.hasPrefix(q) || bBrand.hasPrefix(q)
            if aStarts != bStarts { return aStarts }
            let aContains = aName.contains(q) || aBrand.contains(q)
            let bContains = bName.contains(q) || bBrand.contains(q)
            if aContains != bContains { return aContains }
            if aStarts {
                if aName.hasPrefix(q) != bName.hasPrefix(q) { return aName.hasPrefix(q) }
                if aBrand.hasPrefix(q) != bBrand.hasPrefix(q) { return aBrand.hasPrefix(q) }
            }
            return aName < bName
        }
    }

    private func performSearch(term: String, page: Int = 1) async {
        errorMessage = nil
        if term.count < minQueryLengthForSearch {
            dbSearchResults = []
            hasMorePages = false
            return
        }

        isLoading = true
        do {
            let wines = try await WineService.searchCatalog(query: term, limit: 50)
            dbSearchResults = wines
            lastSearchTerm = term
            currentSearchPage = 1
            hasMorePages = false
        } catch {
            dbSearchResults = []
            errorMessage = ErrorMessage.userFacing(for: error)
        }
        isLoading = false
        isLoadingMore = false
    }

    func loadMoreSearchResults() {
        guard hasMorePages, !isLoadingMore, !lastSearchTerm.isEmpty else { return }
        let nextPage = currentSearchPage + 1
        Task { await performSearch(term: lastSearchTerm, page: nextPage) }
    }

    /// If this product is from the catalog (X-Wines), returns the Wine so caller can skip upsert.
    func wineForProduct(_ p: OFFProduct) -> Wine? {
        catalogWineById[p.code]
    }

    private func productsMatching(_ term: String) -> [OFFProduct] {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return [] }
        return searchCache.filter {
            ($0.productName?.lowercased().contains(t) == true) || ($0.brands?.lowercased().contains(t) == true)
        }
    }

    private func mergeIntoCache(_ newProducts: [OFFProduct]) {
        var seen = Set<String>()
        var merged: [OFFProduct] = []
        for p in newProducts {
            if seen.insert(p.code).inserted { merged.append(p) }
        }
        for p in searchCache {
            if seen.insert(p.code).inserted { merged.append(p) }
        }
        searchCache = merged.count > searchCacheCap ? Array(merged.prefix(searchCacheCap)) : merged
    }

    /// Add Wine açılınca arka planda çalışır. 8 popüler terim paralel OFF’tan çekilir; cache zenginleşir.
    func prefetchPopular() {
        Task {
            async let w = fetchPrefetch(term: "wine")
            async let s = fetchPrefetch(term: "shiraz")
            async let c = fetchPrefetch(term: "chardonnay")
            async let b = fetchPrefetch(term: "cabernet")
            async let m = fetchPrefetch(term: "merlot")
            async let p = fetchPrefetch(term: "pinot")
            async let v = fetchPrefetch(term: "sauvignon")
            async let r = fetchPrefetch(term: "red")
            let all = await [w, s, c, b, m, p, v, r].flatMap { $0 }
            if !all.isEmpty { mergeIntoCache(all) }
        }
    }

    private func fetchPrefetch(term: String) async -> [OFFProduct] {
        do {
            let api = try await WineSearchService.search(query: term)
            return filterAndRank(products: api, query: term)
        } catch { return [] }
    }

    func upsert(product: OFFProduct) async throws -> Wine {
        isUpserting = true
        errorMessage = nil
        defer { isUpserting = false }
        return try await WineService.upsertFromOFF(product: product)
    }
}
