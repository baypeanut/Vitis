//
//  CodeEntryView.swift
//  Vitis
//
//  6-digit OTP entry with resend cooldown.
//

import SwiftUI

struct CodeEntryView: View {
    let phoneDisplay: String

    @State private var code: String = ""
    @State private var isVerifying = false
    @State private var remainingSeconds: Int = 30
    @State private var canResend = false
    @State private var resendTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button {
                    AuthStore.shared.resetToPhoneEntry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(VitisTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(VitisTheme.secondaryText)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            VStack(spacing: 8) {
                Text("Enter code")
                    .font(VitisTheme.titleFont())
                    .foregroundStyle(.primary)
                Text("We sent a 6-digit code to \(phoneDisplay)")
                    .font(VitisTheme.uiFont(size: 15))
                    .foregroundStyle(VitisTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            VStack(spacing: 20) {
                codeField

                if let err = AuthStore.shared.lastError {
                    Text(err)
                        .font(VitisTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await verify() }
                } label: {
                    Text("Verify")
                        .font(VitisTheme.uiFont(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? VitisTheme.accent : Color(white: 0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmit || isVerifying || AuthStore.shared.isProcessing)
                .buttonStyle(.plain)

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
                .foregroundStyle(canResend ? VitisTheme.accent : VitisTheme.secondaryText)
                .disabled(!canResend || AuthStore.shared.isProcessing)
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
        .background(VitisTheme.background.ignoresSafeArea())
        .onAppear {
            AuthStore.shared.lastError = nil
            startCountdown()
        }
        .onDisappear {
            resendTask?.cancel()
        }
    }

    private var canSubmit: Bool {
        digitsOnly(code).count == 6
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("6-digit code")
                .font(VitisTheme.uiFont(size: 13, weight: .medium))
                .foregroundStyle(VitisTheme.secondaryText)
            TextField("••••••", text: $code)
                .font(VitisTheme.uiFont(size: 20, weight: .semibold))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func digitsOnly(_ text: String) -> String {
        text.filter { $0.isNumber }
    }

    private func verify() async {
        guard canSubmit else { return }
        AuthStore.shared.lastError = nil
        isVerifying = true
        let code = digitsOnly(self.code)
        await AuthStore.shared.verifyOTP(code: code)
        isVerifying = false
    }

    private func resend() async {
        guard canResend else { return }
        AuthStore.shared.lastError = nil
        await AuthStore.shared.resendOTP()
        if AuthStore.shared.lastError == nil {
            startCountdown()
        }
    }

    private func startCountdown() {
        resendTask?.cancel()
        canResend = false
        remainingSeconds = 30
        resendTask = Task<Void, Never> {
            var seconds = 30
            while seconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                seconds -= 1
                await MainActor.run {
                    remainingSeconds = seconds
                }
            }
            await MainActor.run {
                canResend = true
            }
        }
    }
}
