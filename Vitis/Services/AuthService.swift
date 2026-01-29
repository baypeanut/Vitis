//
//  AuthService.swift
//  Vitis
//
//  Supabase Auth (email/password) + profile creation. Connection check, errors.
//

import Foundation
import Supabase

enum AuthService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }

    /// Call when no session (e.g. not logged in). Connection OK if we reach Supabase.
    static func checkConnection() async -> ConnectionResult {
        do {
            _ = try await supabase.auth.session
            return .ok
        } catch {
            if isSessionNotFound(error) { return .ok }
            return .failure(error)
        }
    }

    private static func isSessionNotFound(_ error: Error) -> Bool {
        (error as NSError).domain == "GoTrue" && (error as NSError).code == 0
            || String(describing: error).lowercased().contains("session")
    }

    static func currentUserId() async -> UUID? {
        let sessionId = (try? await supabase.auth.session)?.user.id
        #if DEBUG
        if !AppConstants.authRequired {
            if let sid = sessionId { return sid }
            return DevSignupService.currentDevUserId() ?? AppConstants.debugMockUserId
        }
        #endif
        return sessionId
    }

    /// When auth is bypassed: ensure a dev user id exists. Never override a real Supabase session.
    /// If a real session exists, post ready and return. Else ensure vitis_dev_user_id (or mock), then post.
    /// We never create a persisted "Guest" profile; Guest is UI-only placeholder for missing display name.
    static func ensureGuestSessionIfNeeded() async {
        #if DEBUG
        if !AppConstants.authRequired {
            if (try? await supabase.auth.session) != nil {
                NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
                return
            }
            DevSignupService.ensureFallbackDevUserId()
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            return
        }
        #endif
        if await currentUserId() != nil {
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            return
        }
        let deadline = Date().addingTimeInterval(8)
        for attempt in 1...5 {
            if Date() > deadline { break }
            do {
                _ = try await supabase.auth.signInAnonymously()
                NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
                return
            } catch {
                if attempt == 5 { print("[Vitis] ensureGuestSessionIfNeeded failed: \(error)") }
                try? await Task.sleep(for: .milliseconds(400 * attempt))
            }
        }
    }

    /// Sign up, create profile, then enter app. Requires "Confirm email" off in Supabase Auth.
    /// Retries once with backoff on rate-limit errors.
    static func signUp(email: String, password: String, username: String) async -> AuthResult {
        func attempt() async throws -> AuthResult {
            let resp = try await supabase.auth.signUp(email: email, password: password)
            guard resp.session != nil else {
                return .failure("E-posta doğrulaması açık olabilir. Supabase → Auth → Providers → Email içinde \"Confirm email\"i kapatın; veya gelen kutunuzu kontrol edin.")
            }
            do {
                try await createProfile(userId: resp.user.id, username: username)
                return .success
            } catch {
                #if DEBUG
                print("[AuthService] createProfile failed: \(error)")
                #endif
                return .failure("Profil oluşturulamadı. Kullanıcı adı veya e-posta kullanımda olabilir; farklı değerler deneyin.")
            }
        }
        do {
            return try await attempt()
        } catch {
            guard isRateLimitLikeError(error) else {
                return .failure(friendlyMessage(for: error))
            }
            try? await Task.sleep(for: .seconds(2))
            do {
                return try await attempt()
            } catch {
                return .failure(friendlyMessage(for: error))
            }
        }
    }

    private static func isRateLimitLikeError(_ error: Error) -> Bool {
        let s = error.localizedDescription.lowercased()
        return s.contains("rate") || s.contains("limit") || s.contains("too many")
    }

    static func signIn(email: String, password: String) async -> AuthResult {
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            return .success
        } catch {
            return .failure(friendlyMessage(for: error))
        }
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Forgot / reset password

    /// Deep link for password reset. Must match Supabase Dashboard → Auth → URL Configuration → Redirect URLs.
    static let resetPasswordRedirectURL = URL(string: "vitis://auth/reset")!

    /// Sends a password reset email. Redirect URL must be allowlisted in Supabase Dashboard.
    static func resetPasswordForEmail(_ email: String) async -> AuthResult {
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !em.isEmpty, em.contains("@") else {
            return .failure("Geçerli bir e-posta adresi girin.")
        }
        do {
            try await supabase.auth.resetPasswordForEmail(em, redirectTo: resetPasswordRedirectURL)
            return .success
        } catch {
            return .failure(friendlyMessage(for: error))
        }
    }

    /// Updates the current user's password. Call only when session is a recovery session (after handling reset link).
    /// Never store password in Postgres; optionally update profile.password_updated_at via updateProfile.
    static func updatePassword(_ newPassword: String) async -> AuthResult {
        do {
            _ = try await supabase.auth.update(user: UserAttributes(password: newPassword))
            if let uid = (try? await supabase.auth.session)?.user.id {
                try? await updateProfile(userId: uid, passwordUpdatedAt: Date())
            }
            return .success
        } catch {
            return .failure(friendlyMessage(for: error))
        }
    }

    private static func createProfile(userId: UUID, username: String) async throws {
        struct ProfileRow: Encodable {
            let id: UUID
            let username: String
        }
        let row = ProfileRow(id: userId, username: username)
        #if DEBUG
        print("[AuthService] createProfile insert payload id=\(row.id) username=\(row.username)")
        #endif
        do {
            try await supabase.from("profiles")
                .upsert(row, onConflict: "id")
                .execute()
            #if DEBUG
            print("[AuthService] createProfile upsert success")
            #endif
        } catch {
            #if DEBUG
            print("[AuthService] createProfile upsert failed: \(error)")
            #endif
            throw error
        }
    }

    static func getProfile(userId: UUID) async throws -> Profile? {
        struct Row: Decodable {
            let id: UUID
            let username: String
            let full_name: String?
            let avatar_url: String?
            let bio: String?
            let instagram_url: String?
            let taste_snapshot_loves: String?
            let taste_snapshot_avoids: String?
            let taste_snapshot_mood: String?
            let weekly_goal: String?
            let created_at: Date?
        }
        let rows: [Row] = try await supabase.from("profiles")
            .select("id, username, full_name, avatar_url, bio, instagram_url, taste_snapshot_loves, taste_snapshot_avoids, taste_snapshot_mood, weekly_goal, created_at")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let r = rows.first else { return nil }
        return Profile(
            id: r.id,
            username: r.username,
            fullName: r.full_name,
            avatarURL: r.avatar_url,
            bio: r.bio,
            instagramHandle: r.instagram_url,
            tasteSnapshotLoves: r.taste_snapshot_loves,
            tasteSnapshotAvoids: r.taste_snapshot_avoids,
            tasteSnapshotMood: r.taste_snapshot_mood,
            weeklyGoal: r.weekly_goal,
            createdAt: r.created_at
        )
    }

    /// Update only provided fields. Omit nils to leave unchanged. Never store password.
    static func updateProfile(
        userId: UUID,
        fullName: String? = nil,
        avatarURL: String? = nil,
        bio: String? = nil,
        passwordUpdatedAt: Date? = nil,
        instagramHandle: String? = nil,
        tasteSnapshotLoves: String? = nil,
        tasteSnapshotAvoids: String? = nil,
        tasteSnapshotMood: String? = nil,
        weeklyGoal: String? = nil
    ) async throws {
        let u = ProfileUpdatePayload(
            full_name: fullName,
            avatar_url: avatarURL,
            bio: bio,
            password_updated_at: passwordUpdatedAt,
            instagram_url: instagramHandle,
            taste_snapshot_loves: tasteSnapshotLoves,
            taste_snapshot_avoids: tasteSnapshotAvoids,
            taste_snapshot_mood: tasteSnapshotMood,
            weekly_goal: weeklyGoal
        )
        guard u.hasAny else { return }
        try await supabase.from("profiles").update(u).eq("id", value: userId).execute()
    }

    /// User-facing message for auth/connection errors. Never "Account not found" for Auth API failures.
    static func friendlyMessage(for error: Error) -> String {
        let s = error.localizedDescription.lowercased()
        if s.contains("invalid login") || s.contains("invalid_credentials") || s.contains("invalid grant") {
            return "E-posta veya şifre hatalı."
        }
        if s.contains("email not confirmed") || s.contains("email_not_confirmed") || (s.contains("confirm") && s.contains("email")) {
            return "Please confirm your email (or disable email confirmation in dev)."
        }
        if s.contains("already registered") || s.contains("already exists") || s.contains("user already") || s.contains("duplicate") {
            return "Bu e-posta adresi zaten kayıtlı. Giriş yapın veya farklı bir e-posta deneyin."
        }
        if s.contains("password") && (s.contains("short") || s.contains("least") || s.contains("6") || s.contains("weak")) {
            return "Şifre en az 6 karakter olmalı."
        }
        if s.contains("email") && (s.contains("invalid") || s.contains("valid") || s.contains("format")) {
            return "Geçerli bir e-posta adresi girin."
        }
        if s.contains("network") || s.contains("connection") || s.contains("internet") || s.contains("offline") || s.contains("timed out") {
            return "Bağlantı hatası. İnterneti ve Supabase ayarlarını kontrol edin."
        }
        if s.contains("could not connect") || s.contains("host") || s.contains("url") {
            return "Supabase'e ulaşılamıyor. SupabaseConfig'teki URL ve anon key'i kontrol edin."
        }
        if s.contains("rate") || s.contains("limit") || s.contains("too many") {
            return "Çok fazla deneme. Biraz bekleyip tekrar deneyin."
        }
        if s.contains("session") || s.contains("verification") {
            return "E-posta doğrulaması gerekebilir. Supabase → Auth → Email'de \"Confirm email\"i kapatın veya gelen kutunuzu kontrol edin."
        }
        #if DEBUG
        print("[AuthService] friendlyMessage fallback – raw: \(error.localizedDescription)")
        let ne = error as NSError
        print("[AuthService] domain=\(ne.domain) code=\(ne.code) userInfo=\(ne.userInfo)")
        #endif
        return "Bir hata oluştu. Lütfen tekrar deneyin."
    }
}

// MARK: - Profile update payload (encode only non-nil keys)

private struct ProfileUpdatePayload: Encodable {
    let full_name: String?
    let avatar_url: String?
    let bio: String?
    let password_updated_at: Date?
    let instagram_url: String?
    let taste_snapshot_loves: String?
    let taste_snapshot_avoids: String?
    let taste_snapshot_mood: String?
    let weekly_goal: String?

    var hasAny: Bool {
        full_name != nil || avatar_url != nil || bio != nil || password_updated_at != nil
            || instagram_url != nil || taste_snapshot_loves != nil
            || taste_snapshot_avoids != nil || taste_snapshot_mood != nil || weekly_goal != nil
    }

    enum CodingKeys: String, CodingKey {
        case full_name, avatar_url, bio, password_updated_at
        case instagram_url, taste_snapshot_loves, taste_snapshot_avoids, taste_snapshot_mood, weekly_goal
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let v = full_name { try c.encode(v, forKey: .full_name) }
        if let v = avatar_url { try c.encode(v, forKey: .avatar_url) }
        if let v = bio { try c.encode(v, forKey: .bio) }
        if let v = password_updated_at { try c.encode(v, forKey: .password_updated_at) }
        if let v = instagram_url { try c.encode(v, forKey: .instagram_url) }
        if let v = taste_snapshot_loves { try c.encode(v, forKey: .taste_snapshot_loves) }
        if let v = taste_snapshot_avoids { try c.encode(v, forKey: .taste_snapshot_avoids) }
        if let v = taste_snapshot_mood { try c.encode(v, forKey: .taste_snapshot_mood) }
        if let v = weekly_goal { try c.encode(v, forKey: .weekly_goal) }
    }
}

enum ConnectionResult {
    case ok
    case failure(Error)
}

enum AuthResult {
    case success
    case failure(String)
}
