//
//  NewPasswordView.swift
//  Vitis
//
//  Set new password after recovery link. Min 8 chars, letters + numbers + special. Quiet Luxury.
//

import SwiftUI

struct NewPasswordView: View {
    var onComplete: () -> Void
    enum Mode { case form, success }
    @State private var mode: Mode = .form
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            VitisTheme.background.ignoresSafeArea()
            Group {
                switch mode {
                case .form:
                    formContent
                case .success:
                    successContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            if isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.2)
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "New password")
            Text("Choose a strong password: at least 8 characters, with letters, numbers, and a special character.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)

            UnderlineTextField(
                placeholder: "New password",
                text: $password,
                textContentType: .newPassword,
                autocapitalization: .never,
                isSecure: true
            )
            .onChange(of: password) { _, _ in errorMessage = nil }

            UnderlineTextField(
                placeholder: "Confirm password",
                text: $confirm,
                textContentType: .newPassword,
                autocapitalization: .never,
                isSecure: true
            )
            .onChange(of: confirm) { _, _ in errorMessage = nil }

            if let err = errorMessage {
                Text(err)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(Color.red.opacity(0.9))
            }

            PrimaryButton("Update password", enabled: canSubmit && !isLoading) {
                Task { await updatePassword() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(VitisTheme.accent)
            Text("Password updated")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(.primary)
            Text("You can now log in with your new password.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            PrimaryButton("Go to Log in", enabled: true) {
                goToLogIn()
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var canSubmit: Bool {
        let p = password
        let c = confirm
        return p.count >= 8 && c == p && isValidPassword(p)
    }

    /// Min 8 chars, at least one letter, one number, one special character.
    private func isValidPassword(_ p: String) -> Bool {
        let hasLetter = p.contains { $0.isLetter }
        let hasNumber = p.contains { $0.isNumber }
        let special = CharacterSet.punctuationCharacters.union(.symbols)
        let hasSpecial = p.unicodeScalars.contains { special.contains($0) }
        return hasLetter && hasNumber && hasSpecial
    }

    private func validationError() -> String? {
        let p = password
        let c = confirm
        if p.count < 8 { return "Password must be at least 8 characters." }
        if !p.contains(where: { $0.isLetter }) { return "Include at least one letter." }
        if !p.contains(where: { $0.isNumber }) { return "Include at least one number." }
        let special = CharacterSet.punctuationCharacters.union(.symbols)
        if !p.unicodeScalars.contains(where: { special.contains($0) }) {
            return "Include at least one special character (e.g. !@#$%)."
        }
        if c != p { return "Passwords do not match." }
        return nil
    }

    private func updatePassword() async {
        if let err = validationError() {
            errorMessage = err
            return
        }

        isLoading = true
        errorMessage = nil

        let result = await AuthService.updatePassword(password)

        isLoading = false

        switch result {
        case .success:
            NotificationCenter.default.post(name: .vitisSessionReady, object: nil)
            NotificationCenter.default.post(name: .vitisProfileUpdated, object: nil)
            mode = .success
        case .failure(let msg):
            errorMessage = msg
        }
    }

    private func goToLogIn() {
        NotificationCenter.default.post(name: .vitisShowLogIn, object: nil)
        onComplete()
    }
}
