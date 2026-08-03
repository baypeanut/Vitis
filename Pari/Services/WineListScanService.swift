//
//  WineListScanService.swift
//  Pari
//
//  Photograph a restaurant wine list, match it against the catalog, and rank it for
//  the person holding the menu.
//
//  Three steps, and only the first two need a connection:
//    1. the wine-list-scan edge function reads the page
//    2. match_wine_list resolves the lines in one batch, and is allowed to fail
//    3. ranking happens on device against the cached taste vector
//

import UIKit
import Foundation
import Supabase

enum WineListScanError: LocalizedError {
    case notAWineList
    case apiError(status: Int, message: String)
    case networkError(Error)
    case imagePreparationFailed

    var errorDescription: String? {
        switch self {
        case .notAWineList:
            return "That doesn't look like a wine list. Try framing just the list."
        case .apiError(_, let message):
            return message
        case .networkError:
            return ErrorMessage.networkTimeout
        case .imagePreparationFailed:
            return "Could not prepare that photo. Try again."
        }
    }
}

enum WineListScanService {
    /// Higher than the label scanner's: a list is dense small type, and detail lost
    /// here becomes a line the matcher cannot resolve.
    private static let maxImageDimension: CGFloat = 2400
    private static let jpegQuality: CGFloat = 0.75
    /// Below this a match is a guess, and a guessed wine at a table is worse than a
    /// blank. Mirrors the default in match_wine_list.
    private static let minMatchConfidence: Double = 0.35

    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Whole flow

    /// Read, match and rank a photographed list.
    static func scanAndRank(image: UIImage) async throws -> [MatchedWineListItem] {
        let extracted = try await extract(image: image)
        guard extracted.isWineList, !extracted.items.isEmpty else {
            throw WineListScanError.notAWineList
        }
        let matched = await match(items: extracted.items)
        return await rank(matched)
    }

    // MARK: - 1. Read the page

    static func extract(image: UIImage) async throws -> WineListScanResult {
        guard let base64 = prepare(image) else {
            throw WineListScanError.imagePreparationFailed
        }

        struct Payload: Encodable { let image_base64: String }
        struct ItemPayload: Decodable {
            let name: String?
            let producer: String?
            let vintage: Int?
            let region: String?
            let price: String?
            let by_glass: Bool?
        }
        struct ResponsePayload: Decodable {
            let is_wine_list: Bool
            let items: [ItemPayload]
        }

        let data: Data
        do {
            data = try await supabase.functions.invoke(
                "wine-list-scan",
                options: FunctionInvokeOptions(body: Payload(image_base64: base64))
            )
        } catch let fnError as FunctionsError {
            if case .httpError(let code, _) = fnError {
                throw WineListScanError.apiError(status: code, message: message(forStatus: code))
            }
            throw WineListScanError.networkError(fnError)
        } catch {
            throw WineListScanError.networkError(error)
        }

        guard let decoded = try? JSONDecoder().decode(ResponsePayload.self, from: data) else {
            throw WineListScanError.notAWineList
        }

        let items = decoded.items.compactMap { raw -> WineListItem? in
            guard let name = raw.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return nil }
            return WineListItem(
                name: name,
                producer: raw.producer?.trimmingCharacters(in: .whitespacesAndNewlines),
                vintage: raw.vintage,
                region: raw.region,
                price: raw.price,
                byGlass: raw.by_glass ?? false
            )
        }
        return WineListScanResult(isWineList: decoded.is_wine_list, items: items)
    }

    // MARK: - 2. Resolve against the catalog, in one call

    static func match(items: [WineListItem]) async -> [MatchedWineListItem] {
        guard !items.isEmpty else { return [] }

        struct Params: Encodable, Sendable {
            let p_names: [String]
            let p_producers: [String]
            let p_min_confidence: Double

            private enum CodingKeys: String, CodingKey { case p_names, p_producers, p_min_confidence }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_names, forKey: .p_names)
                try c.encode(p_producers, forKey: .p_producers)
                try c.encode(p_min_confidence, forKey: .p_min_confidence)
            }
        }
        struct Row: Decodable {
            let idx: Int
            let wine_id: UUID?
            let name: String?
            let producer: String?
            let vintage: Int?
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
            let confidence: Double?
            let embedding: [Double]?
        }

        let rows: [Row]
        do {
            rows = try await supabase
                .rpc("match_wine_list", params: Params(
                    p_names: items.map(\.name),
                    // Parallel array: the SQL indexes into it, so a gap has to be an
                    // empty string rather than a missing element.
                    p_producers: items.map { $0.producer ?? "" },
                    p_min_confidence: minMatchConfidence
                ))
                .execute()
                .value
        } catch {
            #if DEBUG
            print("[WineListScanService] match failed: \(error)")
            #endif
            // Matching failed wholesale. Still show the list, all lines unmatched,
            // because the person can read it even if we cannot.
            return items.map {
                MatchedWineListItem(listItem: $0, wine: nil, matchConfidence: nil,
                                    embedding: nil, affinity: nil)
            }
        }

        let byIndex = Dictionary(rows.map { ($0.idx, $0) }, uniquingKeysWith: { first, _ in first })

        return items.enumerated().map { offset, item in
            // unnest WITH ORDINALITY is 1-based.
            let row = byIndex[offset + 1]
            let wine: Wine? = row?.wine_id.map { id in
                Wine(
                    id: id,
                    name: row?.name ?? item.name,
                    producer: row?.producer ?? (item.producer ?? ""),
                    vintage: row?.vintage,
                    variety: row?.variety,
                    region: row?.region,
                    labelImageURL: row?.label_image_url,
                    category: row?.category
                )
            }
            return MatchedWineListItem(
                listItem: item,
                wine: wine,
                matchConfidence: wine == nil ? nil : row?.confidence,
                embedding: wine == nil ? nil : row?.embedding,
                affinity: nil
            )
        }
    }

    // MARK: - 3. Rank on device

    /// Score against the cached taste vector. Runs without the network, so a list
    /// already scanned can be re-ranked when the signal has gone.
    static func rank(_ items: [MatchedWineListItem]) async -> [MatchedWineListItem] {
        guard let profile = await TasteVectorCache.shared.vector() else {
            // No profile yet. Leave the order the list printed rather than inventing
            // a ranking we cannot justify.
            return items
        }

        var scored = items
        for i in scored.indices {
            if let embedding = scored[i].embedding {
                scored[i].affinity = TasteVectorMath.affinity(profile, embedding)
            }
        }

        return scored.sorted { lhs, rhs in
            switch (lhs.affinity, rhs.affinity) {
            case let (l?, r?): return l > r
            case (.some, .none): return true      // scored wines above unscored
            case (.none, .some): return false
            case (.none, .none): return false     // unmatched lines keep list order
            }
        }
    }

    // MARK: - Image

    private static func prepare(_ image: UIImage) -> String? {
        let resized = resizeIfNeeded(image)
        return resized.jpegData(compressionQuality: jpegQuality)?.base64EncodedString()
    }

    private static func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxImageDimension else { return image }
        let scale = maxImageDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func message(forStatus code: Int) -> String {
        switch code {
        case 401: return "Sign in to scan wine lists."
        case 413: return "That photo is too large. Try one page at a time."
        case 429: return "You've hit the scan limit for now. Try again in a little while."
        case 503: return "List scanning is temporarily unavailable."
        default:  return "Could not read that list (HTTP \(code))."
        }
    }
}
