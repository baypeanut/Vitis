//
//  AccountStepView.swift
//  Pari
//
//  Combined email + password step (was 2 separate screens).
//

import SwiftUI

struct AccountStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SerifTitleText(title: "Set up your account")

            // Email
            VStack(alignment: .leading, spacing: 8) {
                UnderlineTextField(
                    placeholder: "email@example.com",
                    text: $vm.email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalization: .never
                )
                .onChange(of: vm.email) { _, _ in vm.emailError = nil }
                if let err = vm.emailError {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }

            // Password
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    UnderlineTextField(
                        placeholder: "Password",
                        text: $vm.password,
                        textContentType: .newPassword,
                        autocapitalization: .never,
                        isSecure: !vm.showPassword
                    )
                    Button {
                        vm.showPassword.toggle()
                    } label: {
                        Image(systemName: vm.showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                .onChange(of: vm.password) { _, _ in vm.passwordError = nil }
                Text("8–20 characters. Letters, numbers, special characters.")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                if let err = vm.passwordError {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
