//
//  ChangePhoneNumberView.swift
//  Vitis
//
//  Two-step flow: enter new phone, verify via OTP.
//

import SwiftUI

struct ChangePhoneNumberView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @State private var authStore = AuthStore.shared

    @State private var step: Step = .enterPhone
    @State private var phoneInput = PhoneNumberInputModel()
    @State private var code = ""
    @State private var remainingSeconds = 30
    @State private var canResend = false
    @State private var resendTask: Task<Void, Never>?
    @State private var isVerifying = false

    enum Step { case enterPhone, enterCode }

    var body: some View {
        NavigationStack {
            ZStack {
                VitisTheme.backgroundPrimary(for: colorScheme).ignoresSafeArea()
                if step == .enterPhone {
                    enterPhoneContent
                } else {
                    enterCodeContent
                }
                if authStore.isProcessing || isVerifying {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authStore.cancelPhoneNumberChange()
                        isPresented = false
                    }
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.accent(for: colorScheme))
                }
            }
        }
        .onChange(of: authStore.authResultEvent) { _, newValue in
            if case .phoneChanged = newValue {
                isPresented = false
            }
        }
        .onDisappear {
            resendTask?.cancel()
        }
    }

    private var enterPhoneContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Change phone number")
                        .font(VitisTheme.titleFont())
                        .foregroundStyle(.primary)
                    Text("Enter your new phone number. We will send a verification code.")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }

                PhoneNumberField(
                    selectedCountry: $phoneInput.selectedCountry,
                    nationalNumber: $phoneInput.nationalNumber,
                    label: "Phone number",
                    helperText: "We will text a code to this number."
                )

                if let err = authStore.lastError {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }

                PrimaryButton("Send code", enabled: canSendCode && !authStore.isProcessing) {
                    Task { await sendCode() }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 60)
        }
    }

    private var enterCodeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter code")
                        .font(VitisTheme.titleFont())
                        .foregroundStyle(.primary)
                    Text("We sent a 6-digit code to \(authStore.pendingPhoneChangeDisplay ?? "your new number")")
                        .font(VitisTheme.uiFont(size: 15))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("6-digit code")
                        .font(VitisTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(VitisTheme.secondaryText(for: colorScheme))
                    TextField("••••••", text: $code)
                        .font(VitisTheme.uiFont(size: 20, weight: .semibold))
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(VitisTheme.placeholderBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let err = authStore.lastError {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                }

                PrimaryButton("Verify", enabled: digitsOnly(code).count == 6 && !authStore.isProcessing && !isVerifying) {
                    Task { await verify() }
                }

                Button {
                    Task { await resend() }
                } label: {
                    if canResend {
                        Text("Resend code")
                    } else {
                        Text("Resend in \(remainingSeconds)s")
                    }
                }
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(canResend ? VitisTheme.accent(for: colorScheme) : VitisTheme.secondaryText(for: colorScheme))
                .disabled(!canResend || authStore.isProcessing)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 60)
        }
    }

    private var canSendCode: Bool {
        !(phoneInput.nationalNumber.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty)
    }

    private func sendCode() async {
        guard let phone = phoneInput.e164 else { return }
        authStore.lastError = nil
        await authStore.startPhoneNumberChange(newPhoneE164: phone)
        if authStore.isInPhoneChangeFlow {
            step = .enterCode
            startCountdown()
        }
    }

    private func verify() async {
        guard digitsOnly(code).count == 6 else { return }
        authStore.lastError = nil
        isVerifying = true
        await authStore.verifyPhoneNumberChange(code: digitsOnly(code))
        isVerifying = false
        if authStore.authResultEvent != nil {
            isPresented = false
        }
    }

    private func resend() async {
        guard canResend else { return }
        authStore.lastError = nil
        await authStore.resendPhoneNumberChange()
        if authStore.lastError == nil {
            startCountdown()
        }
    }

    private func startCountdown() {
        resendTask?.cancel()
        canResend = false
        remainingSeconds = 30
        resendTask = Task {
            var s = 30
            while s > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                s -= 1
                await MainActor.run { remainingSeconds = s }
            }
            await MainActor.run { canResend = true }
        }
    }
    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }
}
