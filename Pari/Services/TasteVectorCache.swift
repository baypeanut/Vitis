//
//  TasteVectorCache.swift
//  Pari
//
//  The user's 64-dimension taste vector, held on the device.
//
//  Restaurants have bad light and worse connectivity, and this is the one place the
//  product has to work in a hurry. Caching the vector means a scanned list can be
//  scored and re-scored without going back to the network.
//
//  Honest about the limit: the first scan still needs a connection, because reading
//  the photograph and matching the lines both happen server-side. What this removes
//  is every round trip after that.
//

import Foundation
import Supabase

actor TasteVectorCache {
    static let shared = TasteVectorCache()

    private static let storageKey = "pari_taste_vector_v1"
    private static let dimensions = 64
    /// The vector moves only as fast as someone logs wines, so a day is generous
    /// without being stale in any way that would change a ranking.
    private static let maxAge: TimeInterval = 60 * 60 * 24

    private struct Stored: Codable {
        let vector: [Double]
        let fetchedAt: Date
        let userId: UUID
    }

    private var memory: Stored?

    // MARK: - Access

    /// The current user's taste vector, from memory, disk, or the network in that
    /// order. Nil when they have no tastings yet, which is a normal state and not
    /// an error worth surfacing.
    func vector(forceRefresh: Bool = false) async -> [Double]? {
        guard let userId = await AuthService.currentUserId() else { return nil }

        if !forceRefresh, let cached = valid(for: userId) {
            return cached.vector
        }

        if let fetched = await fetch(), fetched.count == Self.dimensions {
            let stored = Stored(vector: fetched, fetchedAt: Date(), userId: userId)
            memory = stored
            persist(stored)
            return fetched
        }

        // Network failed. A stale vector ranks better than no ranking at all, which
        // is the entire reason this cache exists.
        return valid(for: userId, ignoringAge: true)?.vector
    }

    /// Drop the cache after a tasting, since the vector has moved.
    func invalidate() {
        memory = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Storage

    private func valid(for userId: UUID, ignoringAge: Bool = false) -> Stored? {
        let candidate = memory ?? load()
        guard let candidate, candidate.userId == userId else { return nil }
        if !ignoringAge, Date().timeIntervalSince(candidate.fetchedAt) > Self.maxAge {
            return nil
        }
        memory = candidate
        return candidate
    }

    private func load() -> Stored? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func persist(_ stored: Stored) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func fetch() async -> [Double]? {
        do {
            let raw: [Double]? = try await SupabaseManager.shared.supabase
                .rpc("get_my_taste_profile")
                .execute()
                .value
            return raw
        } catch {
            #if DEBUG
            print("[TasteVectorCache] fetch failed: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Scoring

enum TasteVectorMath {
    /// Cosine similarity, clamped to 0...1.
    ///
    /// Both sides are unit vectors by construction, so the dot product is already the
    /// cosine. Negative values mean opposed style and are floored at zero rather than
    /// allowed to drag a score below "no information".
    static func affinity(_ a: [Double], _ b: [Double]) -> Double? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        var dot = 0.0
        for i in a.indices { dot += a[i] * b[i] }
        return min(1.0, max(0.0, dot))
    }
}
