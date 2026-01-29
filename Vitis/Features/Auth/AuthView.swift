//
//  AuthView.swift
//  Vitis
//
//  Login / Sign up. Validated, connection check, loading. Quiet Luxury.
//

import SwiftUI

struct AuthView: View {
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var connectionStatus: ConnectionStatus = .checking

    var onAuthenticated: () -> Void

    enum Mode { case signIn, signUp }
    enum ConnectionStatus { case checking, ok, failed(String) }

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    connectionBanner
                    form
                    toggleMode
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .task { await checkConnection() }
        .onChange(of: mode) { _, _ in errorMessage = nil }
        .onChange(of: email) { _, _ in errorMessage = nil }
        .onChange(of: password) { _, _ in errorMessage = nil }
        .onChange(of: username) { _, _ in errorMessage = nil }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Vitis")
                .font(VitisTheme.titleFont())
                .foregroundStyle(.primary)
            Text(mode == .signIn ? "Sign in to continue" : "Create an account")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch connectionStatus {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8).tint(VitisTheme.secondaryText)
                Text("Checking connection…")
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        case .ok:
            EmptyView()
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
                Button("Retry connection") {
                    Task { await checkConnection() }
                }
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .signUp {
                labeledField("Username", text: $username, placeholder: "e.g. wine_lover")
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            labeledField("Email", text: $email, placeholder: "you@example.com")
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            passwordField

            if let err = errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }

            Button {
                Task { await submit() }
            } label: {
                Text(mode == .signIn ? "Sign in" : "Sign up")
                    .font(.system(.body, design: .serif, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? VitisTheme.accent : Color(white: 0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isLoading || !canSubmit)
            .buttonStyle(.plain)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            SecureField("", text: $password)
                .font(VitisTheme.uiFont(size: 16))
                .textContentType(mode == .signIn ? .password : .newPassword)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if mode == .signUp {
                Text("At least 6 characters")
                    .font(VitisTheme.uiFont(size: 11))
                    .foregroundStyle(VitisTheme.secondaryText)
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            TextField(placeholder, text: text)
                .font(VitisTheme.uiFont(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var canSubmit: Bool {
        let emailOk = email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
        let passwordOk = password.count >= 6
        if mode == .signUp {
            let userOk = username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            return emailOk && passwordOk && userOk
        }
        return emailOk && passwordOk
    }

    private var toggleMode: some View {
        Button {
            mode = mode == .signIn ? .signUp : .signIn
            errorMessage = nil
        } label: {
            Text(mode == .signIn ? "Need an account? Sign up" : "Have an account? Sign in")
                .font(VitisTheme.uiFont(size: 14))
                .foregroundStyle(VitisTheme.accent)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func checkConnection() async {
        connectionStatus = .checking
        if !SupabaseConfig.isValid {
            connectionStatus = .failed("Invalid Supabase URL or anon key. Check SupabaseConfig.")
            return
        }
        let result = await AuthService.checkConnection()
        switch result {
        case .ok:
            connectionStatus = .ok
        case .failure(let e):
            connectionStatus = .failed(AuthService.friendlyMessage(for: e))
        }
    }

    private func submit() async {
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pw = password
        let un = username.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode == .signUp {
            if un.count < 2 {
                errorMessage = "Username must be at least 2 characters."
                return
            }
            if !emailPredicate.evaluate(with: em) {
                errorMessage = "Please enter a valid email address."
                return
            }
            if pw.count < 6 {
                errorMessage = "Password must be at least 6 characters."
                return
            }
        } else {
            if !em.contains("@") {
                errorMessage = "Please enter a valid email address."
                return
            }
            if pw.isEmpty {
                errorMessage = "Please enter your password."
                return
            }
        }

        isLoading = true
        errorMessage = nil

        let result: AuthResult
        if mode == .signUp {
            result = await AuthService.signUp(email: em, password: pw, username: un)
        } else {
            result = await AuthService.signIn(email: em, password: pw)
        }

        isLoading = false

        switch result {
        case .success:
            onAuthenticated()
        case .failure(let msg):
            errorMessage = msg
        }
    }
}
