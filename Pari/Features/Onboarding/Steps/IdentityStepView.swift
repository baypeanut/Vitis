//
//  IdentityStepView.swift
//  Pari
//
//  Combined name + username step (was 2 separate screens).
//

import SwiftUI

struct IdentityStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SerifTitleText(title: "Tell us about you")

            // Name fields
            VStack(alignment: .leading, spacing: 12) {
                UnderlineTextField(
                    placeholder: "First name",
                    text: $vm.firstName,
                    textContentType: .givenName,
                    autocapitalization: .words
                )
                UnderlineTextField(
                    placeholder: "Last name",
                    text: $vm.lastName,
                    textContentType: .familyName,
                    autocapitalization: .words
                )
            }

            // Username
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("@")
                        .font(PariTheme.uiFont(size: 16))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                    UnderlineTextField(
                        placeholder: "username",
                        text: $vm.username,
                        textContentType: .username,
                        autocapitalization: .never
                    )
                    .onChange(of: vm.username) { _, _ in vm.scheduleUsernameCheck() }
                    if vm.usernameChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(PariTheme.secondaryText(for: colorScheme))
                            .padding(.leading, 8)
                    } else if vm.usernameAvailable == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.green)
                            .padding(.leading, 8)
                    }
                }
                Text("You can always change this later.")
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                if let err = vm.usernameError {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
