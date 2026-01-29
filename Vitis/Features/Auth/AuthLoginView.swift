//
//  AuthLoginView.swift
//  Vitis
//
//  Real Supabase Auth login: email + password, signInWithPassword. Show real errors.
//

import SwiftUI

struct AuthLoginView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showForgotPassword = false

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    SerifTitleText(title: "Log in")
                    Text("Sign in with your email and password.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)

                    UnderlineTextField(
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never
                    )
                    .onChange(of: email) { _, _ in errorMessage = nil }

                    UnderlineTextField(
                        placeholder: "Password",
                        text: $password,
                        textContentType: .password,
                        autocapitalization: .never,
                        isSecure: true
                    )
                    .onChange(of: password) { _, _ in errorMessage = nil }

                    if let err = errorMessage {
                        Text(err)
                            .font(VitisTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }

                    PrimaryButton("Log in", enabled: canSubmit && !isLoading) {
                        Task { await submit() }
                    }

                    Button("Forgot password?") {
                        showForgotPassword = true
                    }
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .padding(.top, 4)

                    #if DEBUG
                    if !AppConstants.authRequired {
                        Button("Sign in as test user") {
                            Task { await signInAsTestUser() }
                        }
                        .font(VitisTheme.uiFont(size: 14))
                        .foregroundStyle(VitisTheme.accent)
                        .padding(.top, 8)
                    }
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
                }
            }
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(isPresented: $showForgotPassword)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vitisDeepLinkResetPassword)) { _ in
                showForgotPassword = false
            }
        }
    }

    private var canSubmit: Bool {
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password
        return emailPredicate.evaluate(with: em) && !pw.isEmpty
    }

    private func submit() async {
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password
        guard emailPredicate.evaluate(with: em) else {
            errorMessage = "Geçerli bir e-posta adresi girin."
            return
        }
        guard !pw.isEmpty else {
            errorMessage = "Şifre girin."
            return
        }

        isLoading = true
        errorMessage = nil

        let result = await AuthService.signIn(email: em, password: pw)

        isLoading = false

        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            isPresented = false
        case .failure(let msg):
            errorMessage = msg
        }
    }

    #if DEBUG
    private func signInAsTestUser() async {
        let em = AppConstants.devTestEmail
        let pw = AppConstants.devTestPassword
        isLoading = true
        errorMessage = nil
        let result = await AuthService.signIn(email: em, password: pw)
        isLoading = false
        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            isPresented = false
        case .failure(let msg):
            errorMessage = msg
        }
    }
    #endif
}
