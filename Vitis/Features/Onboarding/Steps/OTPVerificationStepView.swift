//
//  OTPVerificationStepView.swift
//  Vitis
//
//  OTP verification step: 6-digit code input with resend functionality.
//

import SwiftUI

struct OTPVerificationStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SerifTitleText(title: "Enter verification code")
            Text("We sent a 6-digit code to \(PhoneFormatter.displayString(e164: vm.phoneE164 ?? ""))")
                .font(VitisTheme.uiFont(size: 15))
                .foregroundStyle(VitisTheme.secondaryText)
            
            otpInputField
            
            if let err = vm.otpError {
                Text(err)
                    .font(VitisTheme.uiFont(size: 13))
                    .foregroundStyle(.red)
            }
            
            resendSection
        }
    }
    
    private var otpInputField: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                OTPDigitBox(
                    digit: digitAt(index),
                    isFocused: isFocused && index == vm.otpCode.count
                )
            }
        }
        .background(
            TextField("", text: $vm.otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: vm.otpCode) { _, newValue in
                    // Limit to 6 digits
                    let digits = newValue.filter { $0.isNumber }
                    if digits.count > 6 {
                        vm.otpCode = String(digits.prefix(6))
                    } else {
                        vm.otpCode = digits
                    }
                    vm.otpError = nil
                    
                    // Auto-verify when 6 digits entered
                    if vm.otpCode.count == 6 {
                        Task {
                            await vm.verifyOTP()
                        }
                    }
                }
        )
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func digitAt(_ index: Int) -> String? {
        guard index < vm.otpCode.count else { return nil }
        let idx = vm.otpCode.index(vm.otpCode.startIndex, offsetBy: index)
        return String(vm.otpCode[idx])
    }
    
    private var resendSection: some View {
        VStack(spacing: 12) {
            if vm.resendCooldown > 0 {
                Text("Resend code in \(vm.resendCooldown)s")
                    .font(VitisTheme.uiFont(size: 14))
                    .foregroundStyle(VitisTheme.secondaryText)
            } else {
                Button {
                    Task { await vm.resendOTP() }
                } label: {
                    Text("Resend code")
                        .font(VitisTheme.uiFont(size: 15, weight: .medium))
                        .foregroundStyle(VitisTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(vm.isVerifyingOTP)
            }
        }
        .padding(.top, 8)
    }
}

struct OTPDigitBox: View {
    let digit: String?
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? VitisTheme.accent : VitisTheme.border, lineWidth: isFocused ? 2 : 1)
                .frame(width: 48, height: 56)
            
            if let digit {
                Text(digit)
                    .font(VitisTheme.uiFont(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}
