//
//  WantToTryChip.swift
//  Pari
//
//  Compact stat chip for Want to Try count. Tappable, opens full list.
//

import SwiftUI

struct WantToTryChip: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bookmark")
                    .font(.system(size: 12))
                    .foregroundStyle(PariTheme.accent)
                Text("Reserve List")
                    .font(PariTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text("\(count)")
                    .font(PariTheme.uiFont(size: 13, weight: .semibold))
                    .foregroundStyle(PariTheme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(PariTheme.accent.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reserve List")
        .accessibilityValue("\(count) wines")
        .accessibilityHint("Opens the full Reserve List")
    }
}
