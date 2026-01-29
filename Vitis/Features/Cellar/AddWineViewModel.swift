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
    var isLoading = false
    var errorMessage: String?
    var isUpserting = false

    private var searchTask: Task<Void, Never>?
    /// Tüm başarılı API sonuçlarından birikmiş cache. "leb" yazınca "leblebi" vs. substring ile anında gösterilir.
    private var searchCache: [OFFProduct] = []

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

    private func performSearch(term: String) async {
        errorMessage = nil
        let hadCacheHits = !results.isEmpty

        if term.count < minQueryLengthForAPI {
            if !hadCacheHits { results = [] }
            return
        }

        isLoading = true
        do {
            var api = try await WineSearchService.search(query: term)
            api = filterAndRank(products: api, query: term)
            if !api.isEmpty { mergeIntoCache(api) }
            let combined = allMatching(term)
            if !combined.isEmpty {
                results = filterAndRank(products: combined, query: term)
            } else if !api.isEmpty {
                results = api
            } else if !hadCacheHits {
                results = []
            }
        } catch {
            if let nsError = error as NSError?, nsError.domain == "WineSearchService" {
                errorMessage = nsError.localizedDescription
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    errorMessage = "Arama zaman aşımına uğradı. Tekrar deneyin."
                case .notConnectedToInternet, .networkConnectionLost:
                    errorMessage = "İnternet bağlantısı yok."
                default:
                    errorMessage = "Arama yapılamadı. Tekrar deneyin."
                }
            } else {
                errorMessage = "Arama yapılamadı. Tekrar deneyin."
            }
            // API hata verirse yerel + cache eşleşmesi varsa göster; sadece mesajı ekle.
            if results.isEmpty {
                applyCacheFilter(term: term)
                if !results.isEmpty { errorMessage = "Ağ hatası; yerel/önbellekten gösteriliyor." }
            }
        }
        isLoading = false
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
            var api = try await WineSearchService.search(query: term)
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
