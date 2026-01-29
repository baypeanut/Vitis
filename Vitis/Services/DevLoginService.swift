//
//  DevLoginService.swift
//  Vitis
//
//  Dev-only login: find dev_accounts by username or email (case-insensitive). No Supabase Auth.
//

import Foundation
import Supabase

enum DevLoginService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Find dev account by username or email (case-insensitive). Returns nil if not found.
    static func findDevAccount(identifier: String) async -> DevAccount? {
        let q = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        let lower = q.lowercased()

        struct Row: Decodable {
            let id: UUID
            let email: String?
            let phone_e164: String?
            let full_name: String?
            let username: String?
            let created_at: Date?
        }
        let rows: [Row] = (try? await supabase.from("dev_accounts")
            .select("id, email, phone_e164, full_name, username, created_at")
            .limit(500)
            .execute()
            .value) ?? []
        let match = rows.first { r in
            (r.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower)
                || (r.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower)
        }
        guard let r = match else { return nil }
        return DevAccount(
            id: r.id,
            email: r.email,
            phoneE164: r.phone_e164,
            fullName: r.full_name,
            username: r.username,
            createdAt: r.created_at
        )
    }
}
