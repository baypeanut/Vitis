//
//  ConfirmationSheetView.swift
//  Pari
//
//  One-shot auth confirmation: email linked, phone changed, or error.
//

import SwiftUI

struct ConfirmationSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let event: AuthResultEvent
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PariTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    switch event {
                    case .emailLinked:
                        Text("Email verified")
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("Your email is now linked to your account.")
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    case .phoneChanged:
                        Text("Phone number updated")
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("You can now sign in with your new number.")
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    case .error(let title, let message):
                        Text(title)
                            .font(PariTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text(message)
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.accent)
                }
            }
        }
    }
}
