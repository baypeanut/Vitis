//
//  ForgotPasswordView.swift
//  Vitis
//
//  Reset password sheet: email → send reset link. Minimal, Quiet Luxury.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didSucceed = false

    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#)

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    SerifTitleText(title: "Reset password")
                    Text("Enter your email and we'll send you a reset link.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText)

                    if didSucceed {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VitisTheme.accent)
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
                                .foregroundStyle(Color.red.opacity(0.9))
                        }

                        PrimaryButton("Send reset link", enabled: canSubmit && !isLoading) {
                            Task { await sendResetLink() }
                        }
                    }

                    Button("Back to log in") {
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent)
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
                    .foregroundStyle(VitisTheme.accent)
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
            errorMessage = "Geçerli bir e-posta adresi girin."
            return
        }

        isLoading = true
        errorMessage = nil

        let result = await AuthService.resetPasswordForEmail(em)

        isLoading = false

        switch result {
        case .success:
            didSucceed = true
        case .failure(let msg):
            errorMessage = msg
        }
    }
}
