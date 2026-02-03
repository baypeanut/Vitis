//
//  PhoneEntryView.swift
//  Vitis
//
//  Minimal phone entry UI for OTP auth.
//

import SwiftUI

private struct CountryOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let dialPrefix: String

    static let defaults: [CountryOption] = [
        CountryOption(name: "United States", dialPrefix: "+1"),
        CountryOption(name: "United Kingdom", dialPrefix: "+44"),
        CountryOption(name: "Turkey", dialPrefix: "+90"),
        CountryOption(name: "Germany", dialPrefix: "+49"),
        CountryOption(name: "France", dialPrefix: "+33"),
        CountryOption(name: "Netherlands", dialPrefix: "+31")
    ]
}

struct PhoneEntryView: View {
    @State private var selectedCountry = CountryOption.defaults.first ?? CountryOption(name: "United States", dialPrefix: "+1")
    @State private var phoneDigits: String = ""
    @State private var showCountryPicker = false
    @State private var showEmailSheet = false

    @State private var localError: String?

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 6) {
                Text("Welcome to Vitis")
                    .font(VitisTheme.titleFont())
                    .foregroundStyle(.primary)
                Text("Log wines. Discover friends. Build your palate.")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 20) {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text("\(selectedCountry.name) (\(selectedCountry.dialPrefix))")
                            .font(VitisTheme.uiFont(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showCountryPicker) {
                    NavigationStack {
                        List {
                            ForEach(CountryOption.defaults) { option in
                                Button {
                                    selectedCountry = option
                                    showCountryPicker = false
                                } label: {
                                    HStack {
                                        Text(option.name)
                                        Spacer()
                                        Text(option.dialPrefix)
                                            .foregroundStyle(VitisTheme.secondaryText)
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select Country")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showCountryPicker = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Phone number")
                        .font(VitisTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(VitisTheme.secondaryText)
                    HStack {
                        Text(selectedCountry.dialPrefix)
                            .font(VitisTheme.uiFont(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        Divider()
                            .frame(height: 24)
                        TextField("555 123 4567", text: $phoneDigits)
                            .font(VitisTheme.uiFont(size: 16))
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let err = localError ?? AuthStore.shared.lastError {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await sendCode() }
                    } label: {
                        Text("Send code")
                            .font(VitisTheme.uiFont(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? VitisTheme.accent : Color(white: 0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSubmit || AuthStore.shared.isProcessing)
                    .buttonStyle(.plain)

                    Button {
                        showEmailSheet = true
                    } label: {
                        Text("Log in with email instead")
                            .font(VitisTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(VitisTheme.secondaryText)
                    }
                    .buttonStyle(.plain)

                    Text("No password. We will email you a sign in link.")
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(VitisTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
        .background(VitisTheme.background.ignoresSafeArea())
        .onAppear {
            AuthStore.shared.lastError = nil
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailLoginSheet(isPresented: $showEmailSheet)
        }
    }

    private var canSubmit: Bool {
        !digitsOnly(phoneDigits).isEmpty
    }

    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }

    private func sendCode() async {
        localError = nil
        AuthStore.shared.lastError = nil
        let digits = digitsOnly(phoneDigits)
        guard !digits.isEmpty else {
            localError = "Enter a valid phone number."
            return
        }
        let phone = selectedCountry.dialPrefix + digits
        await AuthStore.shared.sendOTP(phoneE164: phone)
    }
}
