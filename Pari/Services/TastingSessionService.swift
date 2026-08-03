//
//  TastingSessionService.swift
//  Pari
//
//  Group mode: a table of people, one bottle.
//
//  Joining a session is what permits the server to read your palate alongside the
//  others at the table. That is why the code is short and spoken rather than a link
//  you forward: consent should be something you give in the room, to people you can
//  see, and it lapses when the evening does.
//

import Foundation
import Supabase

struct TastingSession: Identifiable, Sendable {
    let id: UUID
    let code: String
    let label: String?
    let memberCount: Int
    let expiresAt: Date

    var isOpen: Bool { expiresAt > Date() }
}

/// A wine the table could share, with the arithmetic behind it kept visible.
struct GroupWineSuggestion: Identifiable, Sendable {
    let wine: Wine
    /// Mean affinity across everyone whose palate we know.
    let groupMean: Double
    /// The least well served person's affinity. This is the number that decides
    /// whether a bottle is safe to order, not the mean.
    let worstMember: Double
    let worstMemberId: UUID?
    let memberCount: Int

    var id: UUID { wine.id }
}

enum TastingSessionError: LocalizedError {
    case notFound
    case notAMember
    case noPalates
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notFound: return "No open table with that code."
        case .notAMember: return "You're not at that table."
        case .noPalates: return "Nobody at this table has rated a wine yet."
        case .underlying: return ErrorMessage.unknown
        }
    }
}

enum TastingSessionService {
    private static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    // MARK: - Create and join

    static func create(label: String? = nil) async throws -> TastingSession {
        struct Params: Encodable, Sendable {
            let p_label: String?
            private enum CodingKeys: String, CodingKey { case p_label }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encodeIfPresent(p_label, forKey: .p_label)
            }
        }
        struct Row: Decodable { let session_id: UUID; let code: String; let expires_at: Date }

        do {
            let rows: [Row] = try await supabase
                .rpc("create_tasting_session", params: Params(p_label: label))
                .execute().value
            guard let row = rows.first else { throw TastingSessionError.notFound }
            return TastingSession(id: row.session_id, code: row.code, label: label,
                                  memberCount: 1, expiresAt: row.expires_at)
        } catch let e as TastingSessionError {
            throw e
        } catch {
            throw TastingSessionError.underlying(error)
        }
    }

    static func join(code: String) async throws -> TastingSession {
        struct Params: Encodable, Sendable {
            let p_code: String
            private enum CodingKeys: String, CodingKey { case p_code }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_code, forKey: .p_code)
            }
        }
        struct Row: Decodable {
            let session_id: UUID
            let label: String?
            let member_count: Int
            let expires_at: Date
        }

        let normalised = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let rows: [Row] = try await supabase
                .rpc("join_tasting_session", params: Params(p_code: normalised))
                .execute().value
            guard let row = rows.first else { throw TastingSessionError.notFound }
            return TastingSession(id: row.session_id, code: normalised, label: row.label,
                                  memberCount: row.member_count, expiresAt: row.expires_at)
        } catch {
            // The RPC raises no_data_found for a bad or expired code. Anything else is
            // a real failure and should not be dressed up as a typo.
            if "\(error)".contains("no_data_found") || "\(error)".contains("No open table") {
                throw TastingSessionError.notFound
            }
            throw TastingSessionError.underlying(error)
        }
    }

    // MARK: - What the table should drink

    /// Ranked by group mean, with anyone below `miseryFloor` excluded outright.
    ///
    /// Runs server-side and always needs a connection. Individual palates are not
    /// sent to the device, so the offline path that solo list ranking has is
    /// deliberately unavailable here.
    static func suggestions(
        sessionId: UUID,
        limit: Int = 20,
        miseryFloor: Double = 0.25
    ) async throws -> [GroupWineSuggestion] {
        struct Params: Encodable, Sendable {
            let p_session_id: String
            let p_limit: Int
            let p_misery_floor: Double
            private enum CodingKeys: String, CodingKey { case p_session_id, p_limit, p_misery_floor }
            nonisolated func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_session_id, forKey: .p_session_id)
                try c.encode(p_limit, forKey: .p_limit)
                try c.encode(p_misery_floor, forKey: .p_misery_floor)
            }
        }
        struct Row: Decodable {
            let id: UUID
            let name: String
            let producer: String
            let variety: String?
            let region: String?
            let label_image_url: String?
            let category: String?
            let group_mean: Double
            let worst_member: Double
            let worst_member_id: UUID?
            let member_count: Int
        }

        do {
            let rows: [Row] = try await supabase
                .rpc("recommend_wines_group", params: Params(
                    p_session_id: sessionId.uuidString,
                    p_limit: limit,
                    p_misery_floor: miseryFloor
                ))
                .execute().value

            return rows.map { row in
                GroupWineSuggestion(
                    wine: Wine(id: row.id, name: row.name, producer: row.producer,
                               vintage: nil, variety: row.variety, region: row.region,
                               labelImageURL: row.label_image_url, category: row.category),
                    groupMean: row.group_mean,
                    worstMember: row.worst_member,
                    worstMemberId: row.worst_member_id,
                    memberCount: row.member_count
                )
            }
        } catch {
            if "\(error)".contains("42501") || "\(error)".contains("Not allowed") {
                throw TastingSessionError.notAMember
            }
            throw TastingSessionError.underlying(error)
        }
    }

    /// Leave a table. Consent you cannot withdraw is not consent.
    static func leave(sessionId: UUID) async {
        guard let userId = await AuthService.currentUserId() else { return }
        _ = try? await supabase
            .from("tasting_session_members")
            .delete()
            .eq("session_id", value: sessionId)
            .eq("user_id", value: userId)
            .execute()
    }
}
