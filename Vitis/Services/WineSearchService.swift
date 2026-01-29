//
//  WineSearchService.swift
//  Vitis
//
//  Open Food Facts API: search Wines, map to Wine. Debounce in caller (e.g. ViewModel).
//

import Foundation

enum WineSearchService {
    private static let base = "https://world.openfoodfacts.org/cgi/search.pl"
    private static let pageSize = 10
    private static let userAgent = "VitisApp - iOS - Version 1.0 - CSProject"
    private static let timeout: TimeInterval = 4
    private static let retryDelay: UInt64 = 500_000_000  // 0.5s

    /// Search OFF by query; tag-based category filter for "wines". Retries once on timeout.
    static func search(query: String) async throws -> [OFFProduct] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: q),
            URLQueryItem(name: "tagtype_0", value: "categories"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: "wines"),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        #if DEBUG
        print("DEBUG: API URL: \(request.url?.absoluteString ?? "N/A")")
        #endif

        func fetch() async throws -> Data {
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        }

        let data: Data
        do {
            data = try await fetch()
        } catch {
            let isTimeout = (error as? URLError)?.code == .timedOut
            if isTimeout {
                try? await Task.sleep(nanoseconds: retryDelay)
                do {
                    data = try await fetch()
                } catch let retryErr {
                    #if DEBUG
                    print("DEBUG: Retry failed – \(retryErr)")
                    #endif
                    throw NSError(domain: "WineSearchService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Arama zaman aşımına uğradı. Lütfen tekrar deneyin."])
                }
            } else {
                #if DEBUG
                print("DEBUG: Network error – \(error)")
                #endif
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        throw NSError(domain: "WineSearchService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Arama zaman aşımına uğradı. Lütfen tekrar deneyin."])
                    case .notConnectedToInternet, .networkConnectionLost:
                        throw NSError(domain: "WineSearchService", code: -1009, userInfo: [NSLocalizedDescriptionKey: "İnternet bağlantısı yok."])
                    default:
                        throw NSError(domain: "WineSearchService", code: -1000, userInfo: [NSLocalizedDescriptionKey: "Ağ hatası: \(urlError.localizedDescription)"])
                    }
                }
                throw error
            }
        }

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            let preview = jsonString.count > 1200 ? String(jsonString.prefix(1200)) + "…" : jsonString
            print("DEBUG: API Response: \(preview)")
        }
        #endif

        let resp: OFFSearchResponse
        do {
            resp = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        } catch {
            #if DEBUG
            print("DEBUG: Decode error – \(error)")
            #endif
            throw error
        }

        guard let products = resp.products else {
            #if DEBUG
            print("DEBUG: 'products' key is missing or null in API response.")
            #endif
            return []
        }
        if products.isEmpty {
            #if DEBUG
            print("DEBUG: API returned empty 'products' array.")
            #endif
            return []
        }

        let filtered = products.filter { p in
            (p.productName?.isEmpty == false || p.brands?.isEmpty == false)
        }
        return filtered
    }
}
