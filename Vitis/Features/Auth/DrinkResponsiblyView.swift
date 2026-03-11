//
//  DrinkResponsiblyView.swift
//  Pari
//
//  One-time "drink responsibly" modal shown after age gate.
//  Apple App Store guideline for alcohol apps.
//

import SwiftUI

struct DrinkResponsiblyView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    private static let helpURL = URL(string: "https://www.responsibility.org/")!

    var body: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                VStack(spacing: 12) {
                    Text("Drink Responsibly")
                        .font(PariTheme.titleFont())
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                    Text("Pari is designed for wine enthusiasts who enjoy drinking in moderation. Please drink responsibly and never drink and drive. If you or someone you know is struggling with alcohol, help is available.")
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    Link("Get help — responsibility.org", destination: Self.helpURL)
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                }
                .padding(.horizontal, 8)
                Button {
                    onContinue()
                } label: {
                    Text("I understand")
                        .font(PariTheme.uiFont(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PariTheme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}
