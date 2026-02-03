//
//  AuthStore.swift
//  Vitis
//
//  Central auth state: phone OTP + session restore.
//

import Foundation
import Supabase
import os

@MainActor
@Observable
final class AuthStore {
    static let shared = AuthStore()

    enum State: Equatable {
        case checking
        case unauthenticated
        case awaitingCode(phone: String)
        case authenticated(userId: UUID)
    }

    private let logger = Logger(subsystem: "com.ahmet.vitis", category: "AuthStore")

    var state: State = .checking
    var currentUserId: UUID?
    var sessionRestored = false
    var needsProfileSetup = false
    var isProcessing = false
    var lastError: String?
    private var pendingPhoneE164: String?
    private var pendingEmailLink: String?

    func restoreSession() async {
        state = .checking
        lastError = nil
        do {
            if let uid = await AuthService.currentUserId() {
                currentUserId = uid
                state = .authenticated(userId: uid)
                _ = try await evaluateProfileSetup(for: uid)
                NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            } else {
                state = .unauthenticated
            }
        } catch {
            logger.error("restoreSession failed: \(error.localizedDescription)")
            state = .unauthenticated
        }
        sessionRestored = true
    }

    func sendOTP(phoneE164: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        lastError = nil
        do {
            try await AuthService.sendOTP(phoneE164: phoneE164)
            pendingPhoneE164 = phoneE164
            state = .awaitingCode(phone: phoneE164)
            AnalyticsService.signupStarted()
        } catch {
            lastError = AuthService.friendlyMessage(for: error)
        }
        isProcessing = false
    }

    func verifyOTP(code: String) async {
        guard !isProcessing, let phone = pendingPhoneE164 else { return }
        isProcessing = true
        lastError = nil
        do {
            let userId = try await AuthService.verifyOTP(phoneE164: phone, code: code)
            currentUserId = userId
            state = .authenticated(userId: userId)
            let needsSetup = try await evaluateProfileSetup(for: userId)
            if needsSetup {
                AnalyticsService.signupCompleted()
            }
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
        } catch {
            lastError = AuthService.friendlyMessage(for: error)
        }
        isProcessing = false
    }

    func resendOTP() async {
        guard let phone = pendingPhoneE164 else { return }
        await sendOTP(phoneE164: phone)
    }

    func signOut() async {
        do {
            try await AuthService.signOut()
        } catch {
            logger.error("signOut failed: \(error.localizedDescription)")
        }
        currentUserId = nil
        needsProfileSetup = false
        pendingPhoneE164 = nil
        pendingEmailLink = nil
        state = .unauthenticated
    }

    func resetToPhoneEntry() {
        pendingPhoneE164 = nil
        lastError = nil
        state = .unauthenticated
    }

    func markProfileCompleted() {
        needsProfileSetup = false
    }

    func setPendingEmailLink(_ email: String?) {
        pendingEmailLink = email
    }

    func handleIncomingURL(_ url: URL) async -> Bool {
        guard isAuthCallbackURL(url) else { return false }
        logger.log("Handling auth callback \(url.absoluteString, privacy: .private)")
        do {
            let session = try await AuthService.handleOpenURL(url)
            pendingPhoneE164 = nil
            let userId = session.user.id
            currentUserId = userId
            state = .authenticated(userId: userId)
            _ = try await evaluateProfileSetup(for: userId)
            lastError = nil
            let didLinkEmail = pendingEmailLink != nil
            let emailToStore = session.user.email ?? pendingEmailLink
            if let email = emailToStore, didLinkEmail {
                do {
                    try await AuthService.updateProfile(userId: userId, email: email)
                    pendingEmailLink = nil
                } catch {
                    logger.error("email sync failed: \(error.localizedDescription)")
                    lastError = AuthService.friendlyMessage(for: error)
                }
            } else {
                pendingEmailLink = nil
            }
            if !didLinkEmail {
                AnalyticsService.signupCompleted()
            }
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
        } catch {
            lastError = AuthService.friendlyMessage(for: error)
            state = .unauthenticated
            logger.error("auth callback failed: \(error.localizedDescription)")
        }
        return true
    }

    private func isAuthCallbackURL(_ url: URL) -> Bool {
        guard url.scheme == "vitis" else { return false }
        if (url.host ?? "") == "auth-callback" { return true }
        return url.absoluteString.contains("auth-callback")
    }

    private func evaluateProfileSetup(for userId: UUID) async throws -> Bool {
        guard let profile = try await AuthService.getProfile(userId: userId) else {
            needsProfileSetup = true
            return true
        }
        let usernameOk = !profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let displayNameOk = profile.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        needsProfileSetup = !(usernameOk && displayNameOk)
        return needsProfileSetup
    }
}
