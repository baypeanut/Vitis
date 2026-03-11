//
//  EmailLoginSheet.swift
//  Pari
//
//  Passwordless magic link login.
//

import SwiftUI

struct EmailLoginSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didSendLink = false
    @State private var noAccountFound = false
    @State private var canResend = false
    @State private var timerRemaining = 30
    @State private var resendTask: Task<Void, Never>?
    @State private var authStore = AuthStore.shared
    private var subduedAccent: Color { PariTheme.accentWine(for: colorScheme).opacity(0.7) }

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log in with email")
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("We will send you a link to sign in.")
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }

                    if noAccountFound {
                        noAccountContent
                    } else if didSendLink {
                        successContent
                    } else {
                        formContent
                    }

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                if isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissSheet()
                    }
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(subduedAccent)
                }
            }
        }
        .tint(subduedAccent)
        .onChange(of: authStore.state) { _, newState in
            if case .authenticated = newState {
                dismissSheet()
            }
        }
        .onDisappear {
            resendTask?.cancel()
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email address")
                    .font(PariTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                TextField("you@example.com", text: $email)
                    .font(PariTheme.uiFont(size: 16))
                    .foregroundStyle(.primary)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .tint(subduedAccent)
                    .accentColor(subduedAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(PariTheme.placeholderBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let err = errorMessage {
                Text(err)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }

            PrimaryButton("Send sign in link", enabled: canSubmit && !isLoading) {
                Task { await sendLink(trackAnalytics: true) }
            }
        }
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Check your email")
                    .font(PariTheme.uiFont(size: 17, weight: .semibold))
                    .foregroundStyle(subduedAccent)
                Text("Open the link in the email to finish signing in.")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }

            if let err = errorMessage {
                Text(err)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }

            Button {
                Task { await resendLink() }
            } label: {
                if canResend {
                    Text("Resend link")
                } else {
                    Text("Resend link in \(timerRemaining)s")
                }
            }
            .font(PariTheme.uiFont(size: 15, weight: .medium))
            .foregroundStyle(canResend ? subduedAccent : PariTheme.secondaryText(for: colorScheme))
            .disabled(!canResend || isLoading)
            .buttonStyle(.plain)

            Button("Change email") {
                resetForm()
            }
            .font(PariTheme.uiFont(size: 14))
            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            .buttonStyle(.plain)
        }
    }

    private var noAccountContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("No account found")
                    .font(PariTheme.uiFont(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Sign in with your phone first, then add your email in Settings.")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }
            Button("Back to phone login") {
                dismissSheet()
            }
            .font(PariTheme.uiFont(size: 15, weight: .medium))
            .foregroundStyle(subduedAccent)
            .buttonStyle(.plain)
        }
    }

    private var canSubmit: Bool {
        emailPredicate.evaluate(with: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func sendLink(trackAnalytics: Bool) async {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard emailPredicate.evaluate(with: value) else {
            errorMessage = "Enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        noAccountFound = false
        do {
            if trackAnalytics {
                AnalyticsService.signupStarted()
            }
            try await AuthService.sendMagicLink(email: value)
            didSendLink = true
            startResendCountdown()
        } catch {
            if let authError = error as? AuthError, authError == .emailNotFound {
                noAccountFound = true
            } else {
                errorMessage = AuthService.friendlyMessage(for: error)
            }
        }
        isLoading = false
    }

    private func resendLink() async {
        guard canResend else { return }
        await sendLink(trackAnalytics: false)
    }

    private func resetForm() {
        resendTask?.cancel()
        didSendLink = false
        noAccountFound = false
        canResend = false
        timerRemaining = 30
        errorMessage = nil
    }

    private func startResendCountdown() {
        canResend = false
        timerRemaining = 30
        resendTask?.cancel()
        resendTask = Task {
            var seconds = 30
            while seconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                seconds -= 1
                await MainActor.run {
                    timerRemaining = seconds
                }
            }
            await MainActor.run {
                canResend = true
            }
        }
    }

    private func dismissSheet() {
        resendTask?.cancel()
        isPresented = false
    }
}
