//
//  PhoneEntryView.swift
//  Pari
//
//  Minimal phone entry UI for OTP auth.
//

import SwiftUI

struct PhoneEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phoneInput = PhoneNumberInputModel()
    @State private var showEmailSheet = false

    @State private var localError: String?
    @State private var noAccountFound = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 6) {
                Text("Welcome to Pari")
                    .font(PariTheme.titleFont())
                    .foregroundStyle(.primary)
                Text("Log wines. Discover friends. Build your palate.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 20) {
                PhoneNumberField(
                    selectedCountry: $phoneInput.selectedCountry,
                    nationalNumber: $phoneInput.nationalNumber,
                    label: "Phone number",
                    helperText: "We will send a verification code via SMS."
                )

                if noAccountFound {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No account found. Create an account with your phone number.")
                            .font(PariTheme.uiFont(size: 14))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    }
                } else if let err = localError ?? AuthStore.shared.lastError {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if noAccountFound {
                    Button {
                        Task { await createAccount() }
                    } label: {
                        Text("Create account")
                            .font(PariTheme.uiFont(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(PariTheme.accent(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(AuthStore.shared.isProcessing)
                    .buttonStyle(.plain)
                } else {
                if isCountryUnsupported {
                    Text("SMS verification may not be available in this region. Try a supported country.")
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 12) {
                    Button {
                        Task { await sendCode(intent: .loginExisting) }
                    } label: {
                        Text("Send code")
                            .font(PariTheme.uiFont(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? PariTheme.accent(for: colorScheme) : PariTheme.textDisabled(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSubmit || AuthStore.shared.isProcessing)
                    .buttonStyle(.plain)

                    Button {
                        showEmailSheet = true
                    } label: {
                        Text("Log in with email instead")
                            .font(PariTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    }
                    .buttonStyle(.plain)

                    Text("No password. We will email you a sign in link.")
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
        .background(PariTheme.background(for: colorScheme).ignoresSafeArea())
        .onAppear {
            AuthStore.shared.lastError = nil
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailLoginSheet(isPresented: $showEmailSheet)
        }
    }

    private var canSubmit: Bool {
        let hasNumber = !(phoneInput.nationalNumber.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty)
        let supported = CountriesStore.isSmsSupported(isoCode: phoneInput.selectedCountry.isoCode)
        return hasNumber && supported
    }

    private var isCountryUnsupported: Bool {
        !CountriesStore.isSmsSupported(isoCode: phoneInput.selectedCountry.isoCode)
    }

    private func sendCode(intent: AuthService.AuthIntent) async {
        localError = nil
        AuthStore.shared.lastError = nil
        noAccountFound = false
        guard let phone = phoneInput.e164 else {
            localError = "Enter a valid phone number."
            return
        }
        await AuthStore.shared.sendOTP(phoneE164: phone, intent: intent)
        if let err = AuthStore.shared.lastError,
           err == (AuthError.phoneNotFound.errorDescription ?? "") {
            noAccountFound = true
        }
    }

    private func createAccount() async {
        localError = nil
        AuthStore.shared.lastError = nil
        noAccountFound = false
        guard let phone = phoneInput.e164 else { return }
        await AuthStore.shared.sendOTP(phoneE164: phone, intent: .createAccount)
    }
}
