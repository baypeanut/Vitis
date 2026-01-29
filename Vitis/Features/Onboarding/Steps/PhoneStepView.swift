//
//  PhoneStepView.swift
//  Vitis
//

import SwiftUI

struct PhoneStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "First, what's your phone number?")
            Text("Used for account recovery and trust.")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)

            HStack(alignment: .bottom, spacing: 12) {
                Menu {
                    Button("+1") { vm.countryCode = "+1" }
                    Button("+44") { vm.countryCode = "+44" }
                    Button("+90") { vm.countryCode = "+90" }
                    Button("+49") { vm.countryCode = "+49" }
                    Button("+33") { vm.countryCode = "+33" }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.countryCode)
                            .font(VitisTheme.uiFont(size: 16))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(VitisTheme.border).frame(height: 1)
                    }
                }
                UnderlineTextField(
                    placeholder: "Phone number",
                    text: $vm.phoneRaw,
                    keyboardType: .numberPad,
                    textContentType: .telephoneNumber
                )
            }
            .onChange(of: vm.phoneRaw) { _, _ in vm.phoneError = nil }

            if let err = vm.phoneError {
                Text(err)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }
}
