//
//  ConfirmationSheetView.swift
//  Vitis
//
//  One-shot auth confirmation: email linked, phone changed, or error.
//

import SwiftUI

struct ConfirmationSheetView: View {
    let event: AuthResultEvent
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    switch event {
                    case .emailLinked:
                        Text("Email verified")
                            .font(VitisTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("Your email is now linked to your account.")
                            .font(VitisTheme.uiFont(size: 15))
                            .foregroundStyle(VitisTheme.secondaryText)
                    case .phoneChanged:
                        Text("Phone number updated")
                            .font(VitisTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text("You can now sign in with your new number.")
                            .font(VitisTheme.uiFont(size: 15))
                            .foregroundStyle(VitisTheme.secondaryText)
                    case .error(let title, let message):
                        Text(title)
                            .font(VitisTheme.titleFont())
                            .foregroundStyle(.primary)
                        Text(message)
                            .font(VitisTheme.uiFont(size: 15))
                            .foregroundStyle(VitisTheme.secondaryText)
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
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.accent)
                }
            }
        }
    }
}
