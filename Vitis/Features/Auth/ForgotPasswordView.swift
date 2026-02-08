//
//  ForgotPasswordView.swift
//  Vitis
//
//  Reset password sheet: email → send reset link. Minimal, Quiet Luxury.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didSucceed = false

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    SerifTitleText(title: "Reset password")
                    Text("Enter your email and we'll send you a reset link.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.textSecondary(for: colorScheme))

                    if didSucceed {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
                            Text("Check your email")
                                .font(VitisTheme.uiFont(size: 15))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        UnderlineTextField(
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never
                        )
                        .onChange(of: email) { _, _ in
                            errorMessage = nil
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(VitisTheme.uiFont(size: 13))
                                .foregroundStyle(VitisTheme.dangerMuted(for: colorScheme))
                        }

                        PrimaryButton("Send reset link", enabled: canSubmit && !isLoading) {
                            Task { await sendResetLink() }
                        }
                    }

                    Button("Back to log in") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if isLoading {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accentWine(for: colorScheme))
                }
            }
        }
    }

    private var canSubmit: Bool {
        emailPredicate.evaluate(with: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func sendResetLink() async {
        let em = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard emailPredicate.evaluate(with: em) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }
        errorMessage = "Password reset by email is no longer supported. Use phone sign-in instead."
    }
}
