//
//  AgeGateView.swift
//  Pari
//
//  Apple App Store requirement: alcohol apps must verify user age before entry.
//  Shown once on first launch. Stores gate result in UserDefaults.
//  Legal drinking ages: 21 (US), 18 (EU/AU/most countries).
//

import SwiftUI

struct AgeGateView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onConfirm: () -> Void

    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var showUnderageMessage = false

    /// Minimum legal drinking age. Using 18 as international baseline; adjust per region if needed.
    private let minimumAge = 18

    var body: some View {
        ZStack {
            PariTheme.background(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                headerSection
                dateSection
                if showUnderageMessage {
                    Text("You must be at least \(minimumAge) years old to use Pari.")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
                confirmButton
                legalFooter
                Spacer()
            }
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.2), value: showUnderageMessage)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundStyle(PariTheme.accent(for: colorScheme))
            Text("Welcome to Pari")
                .font(PariTheme.titleFont())
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
            Text("Pari is an alcohol-related app. Please confirm you are of legal drinking age to continue.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date of Birth")
                .font(PariTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            DatePicker(
                "",
                selection: $birthDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: birthDate) { _, _ in
                showUnderageMessage = false
            }
        }
    }

    private var confirmButton: some View {
        Button {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
            if age >= minimumAge {
                UserDefaults.standard.set(true, forKey: "vitis_age_verified")
                onConfirm()
            } else {
                showUnderageMessage = true
            }
        } label: {
            Text("Enter")
                .font(PariTheme.uiFont(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PariTheme.accent(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var legalFooter: some View {
        Text("By entering, you confirm you are of legal drinking age in your country and agree to drink responsibly.")
            .font(PariTheme.uiFont(size: 12))
            .foregroundStyle(PariTheme.tertiaryText(for: colorScheme))
            .multilineTextAlignment(.center)
    }
}
