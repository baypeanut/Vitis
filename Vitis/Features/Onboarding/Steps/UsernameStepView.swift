//
//  UsernameStepView.swift
//  Pari
//

import SwiftUI

struct UsernameStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "Your username")
            Text("You can always change this later.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText)

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
                        .tint(PariTheme.secondaryText)
                        .padding(.leading, 8)
                } else if vm.usernameAvailable == true {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.green)
                        .padding(.leading, 8)
                }
            }

            if let err = vm.usernameError {
                Text(err)
                    .font(PariTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }
        }
        .onAppear { vm.scheduleUsernameCheck() }
    }
}
