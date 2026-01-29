//
//  EmailStepView.swift
//  Vitis
//

import SwiftUI

struct EmailStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "What's your email?")
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
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }
}
