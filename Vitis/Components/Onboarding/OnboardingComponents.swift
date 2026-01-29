//
//  OnboardingComponents.swift
//  Vitis
//
//  Shared onboarding UI: SerifTitleText, UnderlineTextField, PrimaryButton. Quiet Luxury.
//

import SwiftUI

// MARK: - SerifTitleText

struct SerifTitleText: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(.title, design: .serif, weight: .semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - UnderlineTextField

struct UnderlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(VitisTheme.uiFont(size: 16))
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled()
        .padding(.horizontal, 0)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitisTheme.border)
                .frame(height: 1)
        }
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    init(_ title: String, enabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VitisTheme.uiFont(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? VitisTheme.accent : Color(white: 0.88))
                .clipShape(Capsule())
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}
