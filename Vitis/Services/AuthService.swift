//
//  AuthService.swift
//  Vitis
//
//  Supabase Auth (email/password) + profile creation. Connection check, errors.
//

import Foundation
import Supabase

import os

private extension Logger {
    static let auth = Logger(subsystem: "com.ahmet.vitis", category: "AuthService")
}

enum AuthService {
    static var supabase: SupabaseClient { SupabaseManager.shared.supabase }
    private static let emailRedirectURL = URL(string: "vitis://auth-callback")!

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
            // In auth-bypass builds we still need a real session for RLS-protected writes (wishlist, tastings, etc).
            if let sid = sessionId { return sid }
            if let anon = try? await supabase.auth.signInAnonymously() {
                return anon.user.id
            }
            return DevSignupService.currentDevUserId()
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
            // Create an anonymous session so RLS allows writes in dev "auth bypass" mode.
            _ = try? await supabase.auth.signInAnonymously()
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

    // MARK: - Phone OTP

    enum AuthIntent {
        case createAccount
        case loginExisting
    }

    static func sendOTP(phoneE164: String, intent: AuthIntent = .createAccount) async throws {
        let shouldCreate = intent == .createAccount
        do {
            try await supabase.auth.signInWithOTP(
                phone: phoneE164,
                shouldCreateUser: shouldCreate
            )
        } catch {
            throw mapOTPError(error, forPhoneLogin: !shouldCreate)
        }
    }

    static func startPhoneNumberChange(newPhoneE164: String) async throws {
        _ = try await supabase.auth.session
        try await supabase.auth.update(user: UserAttributes(phone: newPhoneE164))
    }

    static func verifyPhoneNumberChange(newPhoneE164: String, code: String) async throws {
        _ = try await supabase.auth.verifyOTP(
            phone: newPhoneE164,
            token: code,
            type: .phoneChange
        )
    }

    static func resendPhoneNumberChange(newPhoneE164: String) async throws {
        try await supabase.auth.resend(
            phone: newPhoneE164,
            type: .phoneChange
        )
    }

    static func sendMagicLink(email: String) async throws {
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: emailRedirectURL,
                shouldCreateUser: false
            )
        } catch {
            throw mapOTPError(error)
        }
    }

    static func requestAddEmail(email: String) async throws {
        try await requestEmailChange(newEmail: email)
    }

    static func requestEmailChange(newEmail: String) async throws {
        do {
            _ = try await supabase.auth.session
        } catch {
            throw AuthError.notAuthenticated
        }
        do {
            try await supabase.auth.update(
                user: UserAttributes(email: newEmail),
                redirectTo: emailRedirectURL
            )
        } catch {
            throw mapOTPError(error)
        }
    }

    static func resendEmailChange(newEmail: String) async throws {
        try await supabase.auth.resend(
            email: newEmail,
            type: .emailChange,
            emailRedirectTo: emailRedirectURL
        )
    }

    static func currentUserEmail() async -> String? {
        (try? await supabase.auth.session)?.user.email
    }

    /// Returns latest user snapshot (userId, phone, email) for display. Call after session or identity changes.
    static func currentUserSnapshot() async -> (userId: UUID, phone: String?, email: String?)? {
        guard let session = try? await supabase.auth.session else { return nil }
        let user = session.user
        let phone = user.phone
        let email = user.email
        return (user.id, phone, email)
    }

    static func verifyOTP(phoneE164: String, code: String) async throws -> UUID {
        do {
            let response = try await supabase.auth.verifyOTP(
                phone: phoneE164,
                token: code,
                type: .sms
            )
            return response.user.id
        } catch {
            throw mapOTPError(error)
        }
    }

    @discardableResult
    static func establishSession(from url: URL) async throws -> Session {
        try await supabase.auth.session(from: url)
    }

    @discardableResult
    static func handleOpenURL(_ url: URL) async throws -> Session {
        try await supabase.auth.session(from: url)
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    /// Deletes the current user's account. This will cascade delete all user data (profile, tastings, follows, etc.)
    /// due to ON DELETE CASCADE constraints in the database.
    /// This calls a Postgres function that deletes the user from auth.users, which triggers cascade deletes.
    static func deleteAccount() async -> AuthResult {
        do {
            guard await currentUserId() != nil else {
                return .failure("Not signed in.")
            }
            
            // Call the delete_user RPC function which will delete the user from auth.users
            // The CASCADE constraints will automatically clean up all related data
            try await supabase.rpc("delete_current_user").execute()
            
            // Sign out after deletion
            try? await supabase.auth.signOut()
            return .success
        } catch {
            #if DEBUG
            print("[AuthService] deleteAccount failed: \(error)")
            #endif
            return .failure(friendlyMessage(for: error))
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
        let rows: [Row] = try await supabase
            .from("profiles")
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
        username: String? = nil,
        fullName: String? = nil,
        avatarURL: String? = nil,
        bio: String? = nil,
        passwordUpdatedAt: Date? = nil,
        instagramHandle: String? = nil,
        tasteSnapshotLoves: String? = nil,
        tasteSnapshotAvoids: String? = nil,
        tasteSnapshotMood: String? = nil,
        weeklyGoal: String? = nil,
        email: String? = nil
    ) async throws {
        let u = ProfileUpdatePayload(
            username: username,
            full_name: fullName,
            avatar_url: avatarURL,
            bio: bio,
            password_updated_at: passwordUpdatedAt,
            instagram_url: instagramHandle,
            taste_snapshot_loves: tasteSnapshotLoves,
            taste_snapshot_avoids: tasteSnapshotAvoids,
            taste_snapshot_mood: tasteSnapshotMood,
            weekly_goal: weeklyGoal,
            email: email
        )
        guard u.hasAny else { return }
        try await supabase
            .from("profiles")
            .update(u)
            .eq("id", value: userId)
            .execute()
    }

    static func upsertProfile(
        userId: UUID,
        username: String,
        fullName: String,
        email: String?
    ) async throws {
        struct Row: Encodable {
            let id: UUID
            let username: String
            let full_name: String
            let email: String?
            let is_age_verified: Bool
        }
        let row = Row(id: userId, username: username, full_name: fullName, email: email, is_age_verified: true)
        try await supabase
            .from("profiles")
            .upsert(row, onConflict: "id")
            .execute()
    }

    /// User-facing message for auth/connection errors. Never "Account not found" for Auth API failures.
    static func friendlyMessage(for error: Error) -> String {
        if let authError = error as? AuthError, let message = authError.errorDescription {
            return message
        }
        let s = error.localizedDescription.lowercased()
        if s.contains("invalid login") || s.contains("invalid_credentials") || s.contains("invalid grant") {
            return "Invalid email or password."
        }
        if s.contains("email not confirmed") || s.contains("email_not_confirmed") || (s.contains("confirm") && s.contains("email")) {
            return "Please confirm your email."
        }
        if s.contains("already registered") || s.contains("already exists") || s.contains("user already") || s.contains("duplicate") {
            return "This email is already registered. Sign in or try a different email."
        }
        if s.contains("password") && (s.contains("short") || s.contains("least") || s.contains("6") || s.contains("weak")) {
            return "Password must be at least 6 characters."
        }
        if s.contains("email") && (s.contains("invalid") || s.contains("valid") || s.contains("format")) {
            return "Enter a valid email address."
        }
        if s.contains("network") || s.contains("connection") || s.contains("internet") || s.contains("offline") || s.contains("timed out") {
            return ErrorMessage.noConnection
        }
        if s.contains("could not connect") || s.contains("host") || s.contains("url") {
            return "Could not reach server. Check your connection."
        }
        if s.contains("rate") || s.contains("limit") || s.contains("too many") {
            return "Too many attempts. Please try again later."
        }
        if s.contains("session") || s.contains("verification") {
            return "Session expired. Please sign in again."
        }
        #if DEBUG
        Logger.auth.error("friendlyMessage fallback – raw: \(error.localizedDescription)")
        let ne = error as NSError
        Logger.auth.error("domain=\(ne.domain) code=\(ne.code) userInfo=\(ne.userInfo)")
        #endif
        return ErrorMessage.unknown
    }

    private static func mapOTPError(_ error: Error, forPhoneLogin: Bool = false) -> Error {
        let s = error.localizedDescription.lowercased()
        if s.contains("email") && (s.contains("already") || s.contains("exists") || s.contains("duplicate")) {
            return AuthError.emailAlreadyInUse
        }
        if s.contains("invalid") && s.contains("phone") {
            return AuthError.invalidPhone
        }
        if s.contains("invalid") && s.contains("email") {
            return AuthError.invalidEmail
        }
        if s.contains("user") && s.contains("not found") {
            return forPhoneLogin ? AuthError.phoneNotFound : AuthError.emailNotFound
        }
        if s.contains("signups") && s.contains("not allowed") {
            return forPhoneLogin ? AuthError.phoneNotFound : AuthError.emailNotFound
        }
        if s.contains("signup") && s.contains("disabled") {
            return forPhoneLogin ? AuthError.phoneNotFound : AuthError.emailNotFound
        }
        if s.contains("otp") && s.contains("expired") {
            return AuthError.codeExpired
        }
        if s.contains("otp") && s.contains("invalid") {
            return AuthError.invalidCode
        }
        if s.contains("rate") || s.contains("limit") || s.contains("too many") {
            return AuthError.rateLimited
        }
        return error
    }
}

enum AuthError: LocalizedError, Equatable {
    case invalidPhone
    case invalidEmail
    case invalidCode
    case codeExpired
    case rateLimited
    case emailNotFound
    case emailAlreadyInUse
    case phoneNotFound
    case notAuthenticated
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "Enter a valid phone number."
        case .invalidEmail:
            return "Enter a valid email address."
        case .invalidCode:
            return "Invalid code. Try again."
        case .codeExpired:
            return "Code expired. Request a new one."
        case .rateLimited:
            return "Too many attempts. Try again later."
        case .emailNotFound:
            return "No account found for this email."
        case .emailAlreadyInUse:
            return "This email is already linked to another account."
        case .phoneNotFound:
            return "No account found. Create an account with your phone number."
        case .notAuthenticated:
            return ErrorMessage.unauthorized
        case .unknown:
            return ErrorMessage.unknown
        }
    }
}

// MARK: - Profile update payload (encode only non-nil keys)

private struct ProfileUpdatePayload: Encodable {
    let username: String?
    let full_name: String?
    let avatar_url: String?
    let bio: String?
    let password_updated_at: Date?
    let instagram_url: String?
    let taste_snapshot_loves: String?
    let taste_snapshot_avoids: String?
    let taste_snapshot_mood: String?
    let weekly_goal: String?
    let email: String?

    var hasAny: Bool {
        username != nil || full_name != nil || avatar_url != nil || bio != nil || password_updated_at != nil
            || instagram_url != nil || taste_snapshot_loves != nil
            || taste_snapshot_avoids != nil || taste_snapshot_mood != nil || weekly_goal != nil
            || email != nil
    }

    enum CodingKeys: String, CodingKey {
        case username, full_name, avatar_url, bio, password_updated_at
        case instagram_url, taste_snapshot_loves, taste_snapshot_avoids, taste_snapshot_mood, weekly_goal
        case email
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let v = username { try c.encode(v, forKey: .username) }
        if let v = full_name { try c.encode(v, forKey: .full_name) }
        if let v = avatar_url { try c.encode(v, forKey: .avatar_url) }
        if let v = bio { try c.encode(v, forKey: .bio) }
        if let v = password_updated_at { try c.encode(v, forKey: .password_updated_at) }
        if let v = instagram_url { try c.encode(v, forKey: .instagram_url) }
        if let v = taste_snapshot_loves { try c.encode(v, forKey: .taste_snapshot_loves) }
        if let v = taste_snapshot_avoids { try c.encode(v, forKey: .taste_snapshot_avoids) }
        if let v = taste_snapshot_mood { try c.encode(v, forKey: .taste_snapshot_mood) }
        if let v = weekly_goal { try c.encode(v, forKey: .weekly_goal) }
        if let v = email { try c.encode(v, forKey: .email) }
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
