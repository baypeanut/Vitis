//
//  NameStepView.swift
//  Vitis
//

import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "What's your name?")
            Text("This is how your friends will see you!")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
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
    }
}
