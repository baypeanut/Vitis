//
//  AddEmailSheet.swift
//  Pari
//
//  Attach email to an existing account.
//

import SwiftUI

struct AddEmailSheet: View {
    @Binding var isPresented: Bool
    @State private var authStore = AuthStore.shared

    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didSendLink = false
    private let subduedAccent = PariTheme.accent.opacity(0.7)

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add email")
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("We will send you a link to confirm this email.")
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.secondaryText)
                    }

                    if didSendLink {
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
        .onChange(of: authStore.authResultEvent) { _, newValue in
            if case .emailLinked = newValue {
                dismissSheet()
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email address")
                    .font(PariTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText)
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
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let err = errorMessage {
                Text(err)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }

            PrimaryButton("Send confirmation link", enabled: canSubmit && !isLoading) {
                Task { await sendLink() }
            }
        }
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Check your email")
                    .font(PariTheme.uiFont(size: 17, weight: .semibold))
                    .foregroundStyle(subduedAccent)
                Text("Open the link to confirm and finish linking this email.")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.secondaryText)
            }

            Button("Done") {
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

    private func sendLink() async {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard emailPredicate.evaluate(with: value) else {
            errorMessage = "Enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.requestAddEmail(email: value)
            AuthStore.shared.setPendingEmailLink(value)
            didSendLink = true
        } catch {
            errorMessage = AuthService.friendlyMessage(for: error)
        }
        isLoading = false
    }

    private func dismissSheet() {
        isPresented = false
    }
}
