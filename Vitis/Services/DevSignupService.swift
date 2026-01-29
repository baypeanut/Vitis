//
//  DevSignupService.swift
//  Vitis
//
//  Dev-only signup: store onboarding data in dev_accounts, no Supabase Auth.
//  Single source of truth: vitis_dev_user_id in UserDefaults.
//

import Foundation
import Supabase

enum DevSignupService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    private static let userDefaultsKey = "vitis_dev_user_id"

    /// Create dev account: new UUID, insert into dev_accounts, save to UserDefaults (overwrite), return id.
    /// Does not call Supabase Auth.
    static func createDevAccount(
        email: String,
        phoneE164: String,
        fullName: String,
        username: String
    ) async throws -> UUID {
        let id = UUID()

        struct Row: Encodable {
            let id: UUID
            let email: String?
            let phone_e164: String?
            let full_name: String?
            let username: String?
        }
        let row = Row(
            id: id,
            email: email.isEmpty ? nil : email,
            phone_e164: phoneE164.isEmpty ? nil : phoneE164,
            full_name: fullName.isEmpty ? nil : fullName,
            username: username.isEmpty ? nil : username
        )
        try await supabase.from("dev_accounts")
            .insert(row)
            .execute()

        UserDefaults.standard.set(id.uuidString, forKey: userDefaultsKey)
        return id
    }

    /// Saved dev user id from UserDefaults. Nil if never completed dev signup.
    static func currentDevUserId() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: userDefaultsKey),
              let u = UUID(uuidString: s) else { return nil }
        return u
    }

    /// Clear saved dev user id (e.g. on sign out in dev mode).
    static func clearDevUserId() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Set dev user id (e.g. after dev login). Overwrites any existing value.
    static func setDevUserId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: userDefaultsKey)
    }

    /// If no dev user id exists, do nothing. Each developer should create their own dev account.
    /// This ensures no hardcoded user IDs are shared across the team.
    static func ensureFallbackDevUserId() {
        // No-op: Each developer creates their own dev account via signup flow
    }

    /// Load profile from dev_accounts for the given user id. Returns nil if not found.
    static func fetchDevAccount(userId: UUID) async -> Profile? {
        struct Row: Decodable {
            let id: UUID
            let email: String?
            let full_name: String?
            let username: String?
            let created_at: Date?
        }
        let rows: [Row] = (try? await supabase.from("dev_accounts")
            .select("id, email, full_name, username, created_at")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value) ?? []
        guard let r = rows.first else { return nil }
        let name = r.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let un = (r.username?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        return Profile(
            id: r.id,
            username: un ?? "Dev",
            fullName: (name?.isEmpty == false) ? name : nil,
            avatarURL: nil,
            bio: nil,
            createdAt: r.created_at
        )
    }
}
