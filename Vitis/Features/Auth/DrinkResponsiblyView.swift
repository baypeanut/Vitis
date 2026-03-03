//
//  DrinkResponsiblyView.swift
//  Vitis
//
//  One-time "drink responsibly" modal shown after age gate.
//  Apple App Store guideline for alcohol apps.
//

import SwiftUI

struct DrinkResponsiblyView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            VitisTheme.background(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                VStack(spacing: 12) {
                    Text("Drink Responsibly")
                        .font(VitisTheme.titleFont())
                        .foregroundStyle(VitisTheme.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                    Text("Vitis is designed for wine enthusiasts who enjoy drinking in moderation. Please drink responsibly and never drink and drive. If you or someone you know is struggling with alcohol, help is available.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 8)
                Button {
                    onContinue()
                } label: {
                    Text("I understand")
                        .font(VitisTheme.uiFont(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VitisTheme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}
