//
//  PasswordStepView.swift
//  Pari
//

import SwiftUI

struct PasswordStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "Create a password")
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
            Text("8 to 20 characters. Letters, numbers, special characters.")
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
