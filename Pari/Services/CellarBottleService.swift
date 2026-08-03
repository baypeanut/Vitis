//
//  CellarBottleService.swift
//  Pari
//
//  Bottles you own, and which one to open tonight.
//
//  This is the only question in the app with a recurring answer. Logging happens when
//  you drink; deciding what to drink happens every time you look at the rack.
//

import Foundation
import Supabase

struct CellarBottle: Identifiable, Sendable {
    /// How close a bottle is to the end of its window. Drives ordering and the label.
    enum Urgency: String, Sendable {
        case past          // window has closed
        case drinkNow      // closing within a year
        case ready
        case stillYoung
        case unknown

        init(rawValue: String) {
            switch rawValue {
            case "past": self = .past
            case "drink now": self = .drinkNow
            case "ready": self = .ready
            case "still young": self = .stillYoung
            default: self = .unknown
            }
        }

        var label: String {
            switch self {
            case .past: return "Past its window"
            case .drinkNow: return "Drink now"
            case .ready: return "Ready"
            case .stillYoung: return "Still young"
            case .unknown: return "No window yet"
            }
        }
    }

    let id: UUID
    let wine: Wine
    let vintage: Int?
    let quantity: Int
    let drinkFromYear: Int?
    let drinkUntilYear: Int?
    let yearsLeft: Int?
    let affinity: Double?
    let urgency: Urgency
}

enum CellarBottleService {
    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// What to open, urgency first. A bottle closing this year outranks a slightly
    /// better match with five years left, because the better match will still be there.
    static func openTonight(limit: Int = 10) async -> [CellarBottle] {
        guard let userId = await AuthService.currentUserId() else { return [] }

        struct Params: Encodable, Sendable {
            let p_user_id: String
            let p_limit: Int
            private enum CodingKeys: String, CodingKey { case p_user_id, p_limit }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_user_id, forKey: .p_user_id)
                try c.encode(p_limit, forKey: .p_limit)
            }
        }
        struct Row: Decodable {
            let bottle_id: UUID
            let wine_id: UUID
            let name: String
            let producer: String
            let vintage: Int?
            let region: String?
            let category: String?
            let label_image_url: String?
            let quantity: Int
            let drink_from_year: Int?
            let drink_until_year: Int?
            let years_left: Int?
            let affinity: Double?
            let urgency: String
        }

        do {
            let rows: [Row] = try await supabase
                .rpc("open_tonight", params: Params(p_user_id: userId.uuidString, p_limit: limit))
                .execute().value

            return rows.map { row in
                CellarBottle(
                    id: row.bottle_id,
                    wine: Wine(id: row.wine_id, name: row.name, producer: row.producer,
                               vintage: row.vintage, variety: nil, region: row.region,
                               labelImageURL: row.label_image_url, category: row.category),
                    vintage: row.vintage,
                    quantity: row.quantity,
                    drinkFromYear: row.drink_from_year,
                    drinkUntilYear: row.drink_until_year,
                    yearsLeft: row.years_left,
                    affinity: row.affinity,
                    urgency: CellarBottle.Urgency(rawValue: row.urgency)
                )
            }
        } catch {
            #if DEBUG
            print("[CellarBottleService] openTonight failed: \(error)")
            #endif
            return []
        }
    }

    /// Add bottles. Same wine and vintage stacks rather than duplicating a row.
    static func addBottles(wineId: UUID, vintage: Int?, quantity: Int, location: String? = nil) async throws {
        guard let userId = await AuthService.currentUserId() else {
            throw NSError(domain: "CellarBottleService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: ErrorMessage.unauthorized])
        }
        struct Upsert: Encodable {
            let user_id: UUID
            let wine_id: UUID
            let vintage: Int?
            let quantity: Int
            let location: String?
        }
        try await supabase
            .from("cellar_bottles")
            .upsert(Upsert(user_id: userId, wine_id: wineId, vintage: vintage,
                           quantity: max(0, quantity), location: location),
                    onConflict: "user_id,wine_id,vintage")
            .execute()
    }

    /// Drink one. Reaching zero leaves the row so the history of having owned it stays.
    static func drinkOne(bottleId: UUID) async throws {
        struct Row: Decodable { let quantity: Int }
        let rows: [Row] = try await supabase
            .from("cellar_bottles").select("quantity").eq("id", value: bottleId)
            .limit(1).execute().value
        guard let current = rows.first, current.quantity > 0 else { return }

        try await supabase
            .from("cellar_bottles")
            .update(["quantity": current.quantity - 1])
            .eq("id", value: bottleId)
            .execute()
    }
}
