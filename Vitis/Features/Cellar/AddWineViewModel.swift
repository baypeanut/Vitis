//
//  AddWineViewModel.swift
//  Vitis
//
//  Debounced OFF search. Cache + substring match: "leb" → "leblebi" etc.
//  Instant results from cache; API enriches. Retry on timeout.
//

import Foundation

private let minQueryLengthForAPI = 2
private let debounceMs: UInt64 = 100
private let searchCacheCap = 300

@MainActor
@Observable
final class AddWineViewModel {
    var query = ""
    var results: [OFFProduct] = []
    var dbWines: [Wine] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var isUpserting = false
    var hasMorePages = false
    private var currentSearchPage = 1
    private var lastSearchTerm = ""

    private var searchTask: Task<Void, Never>?
    /// Tüm başarılı API sonuçlarından birikmiş cache. "leb" yazınca "leblebi" vs. substring ile anında gösterilir.
    private var searchCache: [OFFProduct] = []

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
        guard !q.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        // Her tuşta yerel + cache substring eşleşmesi; anında sonuç (~1 sn hedefi).
        applyCacheFilter(term: q)
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
        let hadCacheHits = !results.isEmpty
        let isFirstPage = page == 1

        if term.count < minQueryLengthForAPI {
            if !hadCacheHits { results = [] }
            hasMorePages = false
            return
        }

        if isFirstPage { isLoading = true } else { isLoadingMore = true }
        do {
            let raw = try await WineSearchService.search(query: term, page: page)
            let api = filterAndRank(products: raw, query: term)
            hasMorePages = api.count >= 20
            if !api.isEmpty { mergeIntoCache(api) }
            if isFirstPage {
                let combined = allMatching(term)
                if !combined.isEmpty {
                    results = filterAndRank(products: combined, query: term)
                } else if !api.isEmpty {
                    results = api
                } else if !hadCacheHits {
                    results = []
                }
                lastSearchTerm = term
                currentSearchPage = 1
            } else {
                var seen = Set(results.map(\.code))
                for p in api where seen.insert(p.code).inserted {
                    results.append(p)
                }
                results = filterAndRank(products: results, query: term)
                currentSearchPage = page
            }
        } catch {
            errorMessage = ErrorMessage.userFacing(for: error)
            if results.isEmpty && isFirstPage {
                applyCacheFilter(term: term)
                if !results.isEmpty { errorMessage = ErrorMessage.unknown }
            }
        }
        isLoading = false
        isLoadingMore = false
    }

    func loadMoreSearchResults() {
        guard hasMorePages, !isLoadingMore, !lastSearchTerm.isEmpty else { return }
        let nextPage = currentSearchPage + 1
        Task {
            await performSearch(term: lastSearchTerm, page: nextPage)
        }
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
