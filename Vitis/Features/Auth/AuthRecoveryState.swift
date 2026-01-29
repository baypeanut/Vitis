//
//  AuthRecoveryState.swift
//  Vitis
//
//  Tracks password-recovery flow from deep link. Handle vitis://auth/reset → show NewPasswordView.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class AuthRecoveryState: ObservableObject {
    static let shared = AuthRecoveryState()

    @Published var showNewPasswordView = false

    /// Call when app receives a URL (e.g. vitis://auth/reset#...). Pass to Supabase to process recovery tokens.
    /// Redirect URL must match Supabase Dashboard → Auth → URL Configuration → Redirect URLs.
    /// Posts vitisDeepLinkResetPassword so any login/forgot sheets dismiss before we present NewPasswordView.
    func handleIncomingURL(_ url: URL) {
        guard isRecoveryURL(url) else { return }
        Task {
            do {
                try await AuthService.supabase.auth.session(from: url)
            } catch {
                #if DEBUG
                print("[AuthRecoveryState] session(from:) failed: \(error)")
                #endif
                return
            }
            NotificationCenter.default.post(name: .vitisDeepLinkResetPassword, object: nil)
            showNewPasswordView = true
        }
    }

    private func isRecoveryURL(_ url: URL) -> Bool {
        guard url.scheme == "vitis" else { return false }
        let host = url.host ?? ""
        let path = url.path
        return (host == "auth" && (path == "/reset" || path.hasSuffix("reset")))
            || url.absoluteString.contains("auth/reset")
    }

    func dismissRecovery() {
        showNewPasswordView = false
    }
}
