//
//  NameStepView.swift
//  Pari
//

import SwiftUI

struct NameStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "What's your name?")
            Text("This is how your friends will see you!")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
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
