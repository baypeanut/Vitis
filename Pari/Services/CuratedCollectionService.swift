//
//  CuratedCollectionService.swift
//  Pari
//
//  Editorial collections, for the people the recommender cannot help yet.
//
//  A user on their first evening has no taste vector and no twins. The honest answer
//  is not a worse algorithm, it is a person with a name saying why they chose this
//  bottle.
//

import Foundation
import Supabase

struct CuratedCollection: Identifiable, Sendable {
    let id: UUID
    let slug: String
    let title: String
    let subtitle: String?
    let curatorName: String
    let curatorCredential: String?
    let curatorAvatarURL: String?
    let wineCount: Int

    /// "Selected by Deniz Aksoy, Master Sommelier" - the accountability is the point.
    var attribution: String {
        guard let credential = curatorCredential, !credential.isEmpty else {
            return "Selected by \(curatorName)"
        }
        return "Selected by \(curatorName), \(credential)"
    }
}

struct CuratedWine: Identifiable, Sendable {
    let wine: Wine
    /// Why this bottle is here. Without it this is a list, not a point of view.
    let note: String?
    var id: UUID { wine.id }
}

enum CuratedCollectionService {
    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    static func collections(limit: Int = 10) async -> [CuratedCollection] {
        struct Row: Decodable {
            let id: UUID
            let slug: String
            let title: String
            let subtitle: String?
            let curator_name: String
            let curator_credential: String?
            let curator_avatar_url: String?
            let wine_count: Int
        }
        do {
            let rows: [Row] = try await supabase
                .rpc("get_curated_collections", params: ["p_limit": limit])
                .execute().value
            return rows.map {
                CuratedCollection(
                    id: $0.id, slug: $0.slug, title: $0.title, subtitle: $0.subtitle,
                    curatorName: $0.curator_name, curatorCredential: $0.curator_credential,
                    curatorAvatarURL: $0.curator_avatar_url, wineCount: $0.wine_count
                )
            }
        } catch {
            #if DEBUG
            print("[CuratedCollectionService] collections failed: \(error)")
            #endif
            return []
        }
    }

    static func wines(in collectionId: UUID) async -> [CuratedWine] {
        struct Row: Decodable {
            let wine_id: UUID
            let name: String
            let producer: String
            let vintage: Int?
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
            let note: String?
        }
        do {
            let rows: [Row] = try await supabase
                .rpc("get_collection_wines", params: ["p_collection_id": collectionId.uuidString])
                .execute().value
            return rows.map {
                CuratedWine(
                    wine: Wine(id: $0.wine_id, name: $0.name, producer: $0.producer,
                               vintage: $0.vintage, variety: $0.variety, region: $0.region,
                               labelImageURL: $0.label_image_url, category: $0.category),
                    note: $0.note
                )
            }
        } catch {
            #if DEBUG
            print("[CuratedCollectionService] wines failed: \(error)")
            #endif
            return []
        }
    }
}
